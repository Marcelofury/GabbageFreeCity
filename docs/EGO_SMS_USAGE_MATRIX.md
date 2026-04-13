# EGO SMS Usage Matrix

This file documents where EGO SMS is used in the current GFC system and what each SMS event is for.

## SMS Engine

- Core implementation: [backend/config/smsService.js](../backend/config/smsService.js)
- Notification wrapper: [backend/services/notificationService.js](../backend/services/notificationService.js)
- Main sender API: `sendSMS(phoneNumber, message)`

## Event Matrix

1. User registration success
- File: [backend/routes/authRoutes.js](../backend/routes/authRoutes.js)
- Behavior: Sends welcome SMS directly after account creation.
- Purpose: onboarding confirmation.

2. Password set/reset success
- File: [backend/routes/authRoutes.js](../backend/routes/authRoutes.js)
- Behavior: Sends security confirmation SMS after password change.
- Purpose: security alert.

3. Payment success or failure
- File: [backend/controllers/paymentController.js](../backend/controllers/paymentController.js)
- Behavior: `createNotification(..., sendSms: true)` for success/failure callback outcomes.
- Purpose: payment outcome confirmation.

4. Collector assigned to resident report
- File: [backend/routes/garbageReportRoutes.js](../backend/routes/garbageReportRoutes.js)
- Behavior: `createNotification(..., sendSms: true)` to resident.
- Purpose: service dispatch alert.

5. Garbage collection completed
- Files:
  - [backend/routes/collectorRoutes.js](../backend/routes/collectorRoutes.js)
  - [backend/routes/garbageReportRoutes.js](../backend/routes/garbageReportRoutes.js)
- Behavior: completion notifications with `sendSms: true` in completion paths.
- Purpose: closure confirmation.

## Configuration Requirements

Set these env vars for EGO SMS to work:

- `EGO_SMS_API_USERNAME`
- `EGO_SMS_API_KEY`
- `EGO_SMS_USE_SANDBOX` (`true` or `false`)
- `EGO_SMS_SENDER_ID` (optional)
- `EGO_SMS_TEST_NUMBERS` (optional)
- `EGO_SMS_FORCE_TEST_MODE` (optional)

Legacy fallbacks supported:

- `EGO_SMS_USERNAME` -> username fallback
- `EGO_SMS_PASSWORD` or `EGO_SMS_API_PASSWORD` -> api key fallback

## Recommended Operational Policy

- Keep SMS on for payment success/failure, assignment, and completion events.
- Keep SMS on for password reset confirmations (security).
- Keep login SMS off to avoid noisy alerts.
