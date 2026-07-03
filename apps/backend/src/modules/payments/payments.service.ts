import { BadRequestException, Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentProvider, Prisma, SubscriptionPlan, SubscriptionStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../database/prisma.service';

type RevenueCatEvent = {
  id?: string;
  type?: string;
  app_user_id?: string;
  product_id?: string;
  entitlement_ids?: string[];
  purchased_at_ms?: number;
  expiration_at_ms?: number;
  transaction_id?: string;
  original_transaction_id?: string;
};

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService
  ) {}

  revenueCatConfig() {
    return {
      iosApiKey: this.config.get<string>('REVENUECAT_IOS_API_KEY') ?? '',
      androidApiKey: this.config.get<string>('REVENUECAT_ANDROID_API_KEY') ?? '',
      defaultOfferingId: this.config.get<string>('REVENUECAT_DEFAULT_OFFERING_ID') ?? ''
    };
  }

  async handleRevenueCatWebhook(payload: unknown, authorization?: string) {
    this.verifyRevenueCatAuthorization(authorization);

    const event = this.extractRevenueCatEvent(payload);
    const eventType = event.type ?? 'UNKNOWN';
    const eventId =
      event.id ||
      event.transaction_id ||
      `${event.original_transaction_id ?? event.app_user_id ?? 'unknown'}:${eventType}:${event.expiration_at_ms ?? Date.now()}`;
    const shouldProcess = await this.recordPaymentEvent(eventId, eventType, payload);

    if (!shouldProcess) {
      return { received: true, duplicate: true };
    }

    const userId = event.app_user_id;

    if (!userId) {
      this.logger.warn(`RevenueCat event ${eventId} has no app_user_id`);
      return { received: true, ignored: true };
    }

    await this.linkPaymentEvent(eventId, userId, event.original_transaction_id || event.transaction_id);

    const plan = await this.findRevenueCatPlan(event);

    if (!plan) {
      this.logger.warn(`RevenueCat event ${eventId} did not match a subscription plan`);
      return { received: true, ignored: true };
    }

    if (this.isRevenueCatActiveEvent(eventType)) {
      await this.activateSubscription({
        userId,
        plan,
        externalSubscriptionId: event.original_transaction_id || event.transaction_id,
        externalProductId: event.product_id,
        startsAt: this.dateFromMs(event.purchased_at_ms) ?? new Date(),
        expiresAt: this.dateFromMs(event.expiration_at_ms) ?? this.planExpiry(plan)
      });
    } else if (this.isRevenueCatInactiveEvent(eventType)) {
      await this.deactivateSubscription({
        userId,
        externalSubscriptionId: event.original_transaction_id || event.transaction_id,
        externalProductId: event.product_id,
        status: eventType === 'CANCELLATION' ? SubscriptionStatus.CANCELLED : SubscriptionStatus.EXPIRED
      });
    }

    return { received: true };
  }

  private async activateSubscription(input: {
    userId: string;
    plan: SubscriptionPlan;
    externalSubscriptionId?: string | null;
    externalProductId?: string | null;
    startsAt: Date;
    expiresAt: Date;
  }) {
    const existing = input.externalSubscriptionId
      ? await this.prisma.userSubscription.findFirst({
          where: {
            provider: PaymentProvider.REVENUECAT,
            externalSubscriptionId: input.externalSubscriptionId
          }
        })
      : null;
    const data = {
      userId: input.userId,
      planId: input.plan.id,
      provider: PaymentProvider.REVENUECAT,
      externalSubscriptionId: input.externalSubscriptionId,
      externalProductId: input.externalProductId,
      status: SubscriptionStatus.ACTIVE,
      startsAt: input.startsAt,
      expiresAt: input.expiresAt,
      canceledAt: null,
      latestEventAt: new Date()
    };

    if (existing) {
      await this.prisma.userSubscription.update({
        where: { id: existing.id },
        data
      });
    } else {
      await this.prisma.userSubscription.create({ data });
    }

    await this.syncUserRole(input.userId);
  }

  private async deactivateSubscription(input: {
    userId: string;
    externalSubscriptionId?: string | null;
    externalProductId?: string | null;
    status: SubscriptionStatus;
  }) {
    const where: Prisma.UserSubscriptionWhereInput = {
      provider: PaymentProvider.REVENUECAT,
      userId: input.userId,
      status: SubscriptionStatus.ACTIVE
    };

    if (input.externalSubscriptionId) {
      where.externalSubscriptionId = input.externalSubscriptionId;
    } else if (input.externalProductId) {
      where.externalProductId = input.externalProductId;
    }

    await this.prisma.userSubscription.updateMany({
      where,
      data: {
        status: input.status,
        canceledAt: input.status === SubscriptionStatus.CANCELLED ? new Date() : undefined,
        latestEventAt: new Date()
      }
    });

    await this.syncUserRole(input.userId);
  }

  private async syncUserRole(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        role: true,
        subscriptions: {
          where: {
            provider: PaymentProvider.REVENUECAT,
            status: SubscriptionStatus.ACTIVE,
            expiresAt: { gt: new Date() }
          },
          take: 1
        }
      }
    });

    if (!user || user.role === UserRole.ADMIN) {
      return;
    }

    const nextRole = user.subscriptions.length > 0 ? UserRole.CREATOR : UserRole.USER;

    if (user.role !== nextRole) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { role: nextRole }
      });
    }
  }

  private async recordPaymentEvent(eventId: string, eventType: string, payload: unknown) {
    const existing = await this.prisma.paymentEvent.findUnique({
      where: {
        provider_eventId: {
          provider: PaymentProvider.REVENUECAT,
          eventId
        }
      }
    });

    if (existing) {
      return false;
    }

    await this.prisma.paymentEvent.create({
      data: {
        provider: PaymentProvider.REVENUECAT,
        eventId,
        eventType,
        payload: payload as Prisma.InputJsonValue
      }
    });

    return true;
  }

  private async linkPaymentEvent(eventId: string, userId?: string | null, subscriptionId?: string | null) {
    await this.prisma.paymentEvent.update({
      where: {
        provider_eventId: {
          provider: PaymentProvider.REVENUECAT,
          eventId
        }
      },
      data: {
        userId,
        subscriptionId
      }
    });
  }

  private verifyRevenueCatAuthorization(authorization?: string) {
    const secret = this.config.get<string>('REVENUECAT_WEBHOOK_SECRET');

    if (!secret) {
      return;
    }

    if (authorization !== secret && authorization !== `Bearer ${secret}`) {
      throw new UnauthorizedException('Invalid RevenueCat webhook authorization');
    }
  }

  private extractRevenueCatEvent(payload: unknown): RevenueCatEvent {
    if (!payload || typeof payload !== 'object') {
      throw new BadRequestException('Invalid RevenueCat webhook payload');
    }

    const maybeEvent = (payload as { event?: unknown }).event;

    if (!maybeEvent || typeof maybeEvent !== 'object') {
      throw new BadRequestException('Invalid RevenueCat webhook event');
    }

    return maybeEvent as RevenueCatEvent;
  }

  private async findRevenueCatPlan(event: RevenueCatEvent) {
    const entitlementIds = event.entitlement_ids ?? [];
    const revenueCatWhere: Prisma.SubscriptionPlanWhereInput[] = [];

    if (event.product_id) {
      revenueCatWhere.push({ revenueCatPackageId: event.product_id });
    }

    for (const entitlementId of entitlementIds) {
      revenueCatWhere.push({ revenueCatEntitlementId: entitlementId });
    }

    if (revenueCatWhere.length === 0) {
      return null;
    }

    return this.prisma.subscriptionPlan.findFirst({
      where: {
        isActive: true,
        OR: revenueCatWhere
      }
    });
  }

  private isRevenueCatActiveEvent(eventType: string) {
    return ['INITIAL_PURCHASE', 'RENEWAL', 'UNCANCELLATION', 'PRODUCT_CHANGE'].includes(eventType);
  }

  private isRevenueCatInactiveEvent(eventType: string) {
    return ['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE'].includes(eventType);
  }

  private dateFromMs(value?: number | null) {
    return typeof value === 'number' && Number.isFinite(value) ? new Date(value) : null;
  }

  private planExpiry(plan: SubscriptionPlan) {
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + plan.durationDays);
    return expiresAt;
  }
}
