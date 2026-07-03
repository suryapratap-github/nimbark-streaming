import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging, Messaging } from 'firebase-admin/messaging';
import { readFileSync } from 'fs';

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private readonly messaging?: Messaging;

  constructor(private readonly config: ConfigService) {
    const credentials = this.credentials();

    if (!credentials) {
      this.logger.warn('Firebase Admin is not configured; FCM pushes are disabled.');
      return;
    }

    const app = getApps()[0] ?? initializeApp({ credential: cert(credentials) });
    this.messaging = getMessaging(app);
  }

  get enabled() {
    return Boolean(this.messaging);
  }

  async sendToTokens(input: {
    tokens: string[];
    title: string;
    body: string;
    data?: Record<string, string>;
  }) {
    if (!this.messaging || input.tokens.length === 0) {
      return { sent: 0, failedTokens: [] as string[] };
    }

    const response = await this.messaging.sendEachForMulticast({
      tokens: input.tokens,
      notification: {
        title: input.title,
        body: input.body
      },
      data: input.data,
      android: {
        priority: 'high'
      },
      apns: {
        payload: {
          aps: {
            sound: 'default'
          }
        }
      }
    });

    const failedTokens = response.responses
      .map((result, index) => (result.success ? null : input.tokens[index]))
      .filter((token): token is string => Boolean(token));

    return {
      sent: response.successCount,
      failedTokens
    };
  }

  private credentials() {
    const serviceAccountJson = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    const serviceAccountPath = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH');

    if (serviceAccountJson) {
      return JSON.parse(serviceAccountJson);
    }

    if (serviceAccountPath) {
      return JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
    }

    return null;
  }
}
