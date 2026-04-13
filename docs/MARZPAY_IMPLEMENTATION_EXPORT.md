# MarzPay Implementation Export (GFC)

This document captures the exact MarzPay implementation used in this project so you can replicate it in another system.

## 1. Environment Variables

Use these variables:

- `MARZPAY_API_KEY`
- `MARZPAY_API_SECRET`
- `MARZPAY_API_URL` (optional, default: `https://wallet.wearemarz.com/api/v1`)
- `MARZPAY_CALLBACK_URL` (optional override)
- `APP_BASE_URL` or `API_BASE_URL` (used to derive callback URL when callback override is absent)

## 2. Backend API Endpoints

Defined in [backend/routes/paymentRoutes.js](../backend/routes/paymentRoutes.js):

- `POST /api/payments/initiate`
- `POST /api/payments/marzpay/callback`
- `POST /api/payments/validate-phone`
- `GET /api/payments/wallet-balance` (admin)
- `GET /api/payments/marzpay-transactions` (admin)

## 3. MarzPay Service Layer

Implemented in [backend/services/marzpayService.js](../backend/services/marzpayService.js):

- Auth: Basic auth from API key/secret.
- Client: Axios with timeout and base URL.
- Helpers:
  - `formatPhoneNumber(phone)`
  - `getProvider(phone)`
  - `validateMobileNumber(phone)`
- Core methods:
  - `collectMoney(...)`
  - `sendMoney(...)`
  - `getCollectionDetails(uuid)`
  - `getSendMoneyDetails(uuid)`
  - `checkTransactionStatus(uuid)`
  - `getWalletBalance()`
  - `getTransactionHistory(params)`

## 4. Payment Controller Flow

Implemented in [backend/controllers/paymentController.js](../backend/controllers/paymentController.js).

### Initiation (`initiatePayment`)

1. Validate request body (`orderId`, `method`, `phone`).
2. Ensure `method` includes `marzpay`.
3. Normalize and validate Uganda number (MTN/Airtel only).
4. Load report/order and validate ownership + amount range.
5. Prevent duplicate successful payments.
6. Generate `transactionRef` (`randomUUID`).
7. Call `marzpayService.collectMoney` with callback URL.
8. Store payment row with provider refs + webhook payload snapshot.
9. Update order/payment status to processing.
10. Create in-app notification.

### Callback (`handleMarzpayCallback`)

1. Extract `transactionRef`, `providerRef`, `providerStatus` from multiple payload key variants.
2. Map provider status to internal order/payment status.
3. Apply state transition using SQL RPC `apply_marzpay_callback`.
4. Send resident notification and SMS on success/failure.

### Phone Validation (`validatePhone`)

- Exposes normalized validation result to frontend before payment initiation.

## 5. Database Requirements

Migration in [database/migrations/2026-03-16_add_marzpay_payment_support.sql](../database/migrations/2026-03-16_add_marzpay_payment_support.sql):

- Adds to `payments`:
  - `transaction_ref`
  - `provider_reference`
- Adds/ensures index/unique constraints.
- Adds `payment_status` on `garbage_reports`.
- Adds SQL function `apply_marzpay_callback(...)` to safely update payment + order state.

## 6. Frontend Integration Points

Implemented in [mobile_app/lib/services/api_service.dart](../mobile_app/lib/services/api_service.dart):

- `initiatePayment(orderId, phone, method: 'marzpay')`
- `validatePaymentPhone(phone)`

Used primarily by:

- [mobile_app/lib/screens/resident/payments_screen.dart](../mobile_app/lib/screens/resident/payments_screen.dart)

## 7. Minimal Copy Checklist

For another system, copy these blocks in order:

1. Service layer from `marzpayService.js`
2. Controller logic from `paymentController.js`
3. Payment routes from `paymentRoutes.js`
4. DB migration and callback RPC from `2026-03-16_add_marzpay_payment_support.sql`
5. Frontend payment initiate + validate calls
6. Environment variable setup

## 8. Operational Notes

- MarzPay wallet endpoints may require backend server IP whitelisting.
- Phone normalization must enforce `+256XXXXXXXXX` before API calls.
- Keep callback idempotent; current solution uses SQL transition function to avoid inconsistent state updates.
- Current report pricing logic uses sack-based amount calculation (default `SACK_PRICE_UGX=20`).
- For low-value testing with this pricing model, ensure `MARZPAY_MIN_AMOUNT` is set to `20` (or lower) in backend env.
