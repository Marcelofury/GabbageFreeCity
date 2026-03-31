# Mambo SMS Setup (EGO Comms)

This file keeps the historical Mambo naming, but the active implementation is EGO Comms SMS.

## What Is Implemented

Current integration is implemented in:
1. `backend/config/smsService.js`
2. `backend/services/notificationService.js`
3. `backend/routes/authRoutes.js` (welcome SMS)
4. `backend/routes/garbageReportRoutes.js` (assignment/completion SMS via notifications)
5. `backend/controllers/paymentController.js` (payment success/failure SMS via notifications)

## Provider Flow

When `sendSMS` runs:
1. Credentials are read from environment.
2. SDK path is attempted first using `comms-sdk/v1`.
3. If SDK import fails, direct HTTP API fallback is used.
4. Recipients are normalized and optional test recipients are applied.
5. Provider response is mapped to `{ success, error }` style return.

Direct API URLs used by code:
1. Sandbox: `https://comms-test.pahappa.net/api/v1/json`
2. Production: `https://comms.egosms.co/api/v1/json`

## Environment Variables

Set these on backend runtime (local `.env` and Render environment variables).

Required (recommended names):

```env
EGO_SMS_API_USERNAME=your-username
EGO_SMS_API_KEY=your-api-key
```

Supported fallback aliases (for backward compatibility):

```env
EGO_SMS_USERNAME=legacy-username
EGO_SMS_PASSWORD=legacy-password-or-key
EGO_SMS_API_PASSWORD=legacy-api-password
```

Mode and sender settings:

```env
EGO_SMS_SENDER_ID=KCCA-GFC
EGO_SMS_USE_SANDBOX=true
```

Test routing controls:

```env
EGO_SMS_FORCE_TEST_MODE=false
EGO_SMS_TEST_NUMBERS=+256783858472,+256785510666
```

Behavior notes:
1. Username priority: `EGO_SMS_API_USERNAME` then `EGO_SMS_USERNAME`.
2. Key/password priority: `EGO_SMS_API_KEY`, then `EGO_SMS_PASSWORD`, then `EGO_SMS_API_PASSWORD`.
3. `EGO_SMS_FORCE_TEST_MODE=true` sends only to `EGO_SMS_TEST_NUMBERS`.
4. If force-test is false, primary recipient is included and test numbers are appended.

## Verification Steps

1. Start backend and check startup integration line for EGO SMS configured mode.
2. Trigger registration (`POST /api/auth/register`) and confirm welcome SMS.
3. Trigger payment success/failure callback and confirm payment status SMS.
4. Trigger assignment/completion and confirm notification-based SMS dispatch.

## Troubleshooting

### Error: SMS service not configured
Cause:
1. Credentials are missing in runtime environment.

Fix:
1. Set `EGO_SMS_API_USERNAME` and `EGO_SMS_API_KEY`.
2. Restart backend service.

### Error: Wrong Username or Password
Cause:
1. Credential pair does not match selected mode.

Fix:
1. Check `EGO_SMS_USE_SANDBOX` value.
2. Use sandbox credentials for sandbox mode and production credentials for production mode.

### Messages go to test numbers unexpectedly
Cause:
1. `EGO_SMS_FORCE_TEST_MODE=true` or stale `EGO_SMS_TEST_NUMBERS` values.

Fix:
1. Set `EGO_SMS_FORCE_TEST_MODE=false` for normal production routing.
2. Clear or intentionally manage `EGO_SMS_TEST_NUMBERS`.

### SDK import warning appears
Cause:
1. SDK load failed, system switched to direct API fallback.

Fix:
1. Verify `comms-sdk` dependency.
2. If fallback is acceptable, keep running and monitor provider responses.

## Production Guidance

1. Use `EGO_SMS_USE_SANDBOX=false` in production.
2. Keep `EGO_SMS_FORCE_TEST_MODE=false` in production.
3. Rotate SMS credentials periodically.
4. Monitor backend logs for provider failures and auth errors.
