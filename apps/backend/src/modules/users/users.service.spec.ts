import { SubscriptionStatus, UserRole } from '@prisma/client';
import { UsersService } from './users.service';

describe('UsersService subscription role sync', () => {
  const prisma = {
    userSubscription: {
      findMany: jest.fn(),
      updateMany: jest.fn()
    },
    user: {
      findUnique: jest.fn(),
      update: jest.fn()
    }
  };
  const service = new UsersService(prisma as never, {} as never);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('expires active subscriptions and downgrades creators with no active subscription', async () => {
    prisma.userSubscription.findMany.mockResolvedValue([{ userId: 'creator-1' }, { userId: 'creator-1' }]);
    prisma.userSubscription.updateMany.mockResolvedValue({ count: 2 });
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CREATOR,
      subscriptions: []
    });
    prisma.user.update.mockResolvedValue({ id: 'creator-1', role: UserRole.USER });

    await expect(service.downgradeExpiredSubscriptions()).resolves.toEqual({
      reverted: 1,
      expiredUserIds: 1
    });

    expect(prisma.userSubscription.updateMany).toHaveBeenCalledWith({
      where: {
        userId: { in: ['creator-1'] },
        status: SubscriptionStatus.ACTIVE,
        expiresAt: { lte: expect.any(Date) }
      },
      data: { status: SubscriptionStatus.EXPIRED }
    });
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'creator-1' },
      data: { role: UserRole.USER }
    });
  });

  it('keeps creators with another active subscription as creators', async () => {
    prisma.userSubscription.findMany.mockResolvedValue([{ userId: 'creator-1' }]);
    prisma.userSubscription.updateMany.mockResolvedValue({ count: 1 });
    prisma.user.findUnique.mockResolvedValue({
      role: UserRole.CREATOR,
      subscriptions: [{ id: 'active-subscription' }]
    });

    await expect(service.downgradeExpiredSubscriptions()).resolves.toEqual({
      reverted: 0,
      expiredUserIds: 1
    });
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('does nothing when there are no expired active subscriptions', async () => {
    prisma.userSubscription.findMany.mockResolvedValue([]);
    prisma.userSubscription.updateMany.mockResolvedValue({ count: 0 });

    await expect(service.downgradeExpiredSubscriptions()).resolves.toEqual({
      reverted: 0,
      expiredUserIds: 0
    });
    expect(prisma.user.findUnique).not.toHaveBeenCalled();
  });
});
