# RevenueCat Subscription Testing

RevenueCat is the only source of truth for paid creator subscriptions.

## Backend Setup

Set these values in `apps/backend/.env`:

```env
REVENUECAT_IOS_API_KEY=
REVENUECAT_ANDROID_API_KEY=
REVENUECAT_DEFAULT_OFFERING_ID=
REVENUECAT_WEBHOOK_SECRET=
```

Configure the RevenueCat webhook URL:

```text
POST https://your-api-domain.com/api/payments/revenuecat/webhook
```

If `REVENUECAT_WEBHOOK_SECRET` is set, send it as either:

```text
Authorization: Bearer <secret>
```

or:

```text
Authorization: <secret>
```

## Admin Plan Mapping

Each active subscription plan should map to RevenueCat:

- `RevenueCat offering ID`
- `RevenueCat package ID`
- `RevenueCat entitlement ID`

The webhook matches plans by `product_id` against package ID, or by entitlement ID.

## Expected Lifecycle

- `INITIAL_PURCHASE`, `RENEWAL`, `UNCANCELLATION`, `PRODUCT_CHANGE`
  - subscription becomes `ACTIVE`
  - user role becomes `CREATOR`

- `CANCELLATION`
  - subscription becomes `CANCELLED`
  - user role becomes `USER` if no other active subscription exists

- `EXPIRATION`, `BILLING_ISSUE`
  - subscription becomes `EXPIRED`
  - user role becomes `USER` if no other active subscription exists

## Mobile Test Actions

Use the Profile screen:

- `Subscribe and become creator`
- `Restore purchases`
- `Sync subscription`

After purchase/restore/sync, the app refreshes profile state. Final role/status depends on RevenueCat webhook delivery.
