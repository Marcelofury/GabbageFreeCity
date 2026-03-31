# GFC Deep File Walkthrough

This walkthrough reflects the current implementation in this repository and follows real runtime flow.

## 1. Backend Runtime Entry

## 1.1 `backend/server.js`
Backend bootstrap and route mounting.

What it does:
1. Loads environment variables.
2. Configures Helmet, CORS, Morgan, JSON parsing, and rate limiting.
3. Mounts route groups under `/api/*`.
4. Exposes `/health` endpoint.
5. Applies catch-all 404 and global error middleware.
6. Logs integration status for Supabase, MarzPay, and EGO SMS on startup.

## 1.2 `backend/middleware/auth.js`
JWT and role middleware.

What it does:
1. Extracts Bearer token.
2. Verifies JWT using `JWT_SECRET`.
3. Fetches user from Supabase and checks `is_active`.
4. Attaches `req.user`.
5. Restricts route access via `requireUserType`.

## 1.3 `backend/middleware/errorHandler.js`
Central error response middleware.

What it does:
1. Maps Joi/Supabase/JWT errors to standard HTTP responses.
2. Returns `{ success: false, message }` JSON format.

## 2. Backend Configuration Layer

## 2.1 `backend/config/supabase.js`
Supabase client initialization for backend data access.

## 2.2 `backend/config/smsService.js`
EGO SMS integration:
1. SDK-first send path (`comms-sdk/v1`).
2. Direct HTTP fallback when SDK import is unavailable.
3. Sandbox/production switch and test-recipient routing.

## 2.3 `backend/config/africasTalking.js`
Legacy integration helper retained in codebase (non-primary flow).

## 3. Auth and User Lifecycle

## 3.1 `backend/routes/authRoutes.js`
Auth endpoints and profile bootstrap.

What it does:
1. Validates register/login/set-password payloads via Joi.
2. Enforces unique phone number and username.
3. Hashes password with bcrypt.
4. Creates JWT after register/login.
5. Sends registration welcome SMS.
6. Creates notification records for account and login events.

## 4. Garbage Reporting Lifecycle

## 4.1 `backend/routes/garbageReportRoutes.js`
Resident and collector report operations.

What it does:
1. Creates resident report with PostGIS point location and default payment requirement.
2. Returns resident report history with payments and assigned collector details.
3. Finds nearby reports via RPC (`get_nearby_reports`) with fallback query path.
4. Assigns collector only when report is `pending` and payment is `successful`.
5. Updates report status and emits user notifications.

## 5. Payment Lifecycle (MarzPay)

## 5.1 `backend/routes/paymentRoutes.js`
Payment endpoint layer.

What it does:
1. Exposes resident payment initiation.
2. Exposes provider callback endpoint.
3. Exposes phone validation endpoint.
4. Exposes admin wallet/transaction endpoints guarded by admin check.

## 5.2 `backend/controllers/paymentController.js`
Payment orchestration and callback transitions.

What it does:
1. Validates `orderId`, method, and phone.
2. Normalizes and validates Uganda MTN/Airtel numbers.
3. Confirms report ownership and payment amount bounds.
4. Calls MarzPay collect-money API.
5. Stores payment record with `transaction_ref` and provider reference fields.
6. Sets report payment status to `processing` after initiation.
7. Handles callback payload variants (`reference`, `transactionRef`, `transaction_ref`).
8. Calls DB function `apply_marzpay_callback` for atomic payment/report transition.
9. Creates payment notifications and optional SMS on success/failure.

## 5.3 `backend/services/marzpayService.js`
MarzPay HTTP client wrapper.

What it does:
1. Builds Basic auth header from API key and secret.
2. Sends collect-money requests.
3. Provides wallet and transaction lookup calls.
4. Normalizes and validates mobile number/provider.

## 6. Notifications and SMS Triggering

## 6.1 `backend/routes/notificationRoutes.js`
Authenticated notification read APIs.

What it does:
1. Lists notifications with pagination and unread count.
2. Marks one notification as read.
3. Marks all unread notifications as read.

## 6.2 `backend/services/notificationService.js`
Notification persistence helper.

What it does:
1. Inserts `notifications` rows.
2. Optionally fetches user phone number and triggers `sendSMS`.

## 7. Collector Flow

## 7.1 `backend/routes/collectorRoutes.js`
Collector operations.

What it does:
1. Updates collector location (`users.current_location`).
2. Returns assigned/in-progress reports.
3. Verifies collection, inserts `collection_logs`, marks report completed.
4. Generates QR code payload/data URL for reports.

## 8. Mobile App Runtime

## 8.1 `mobile_app/lib/main.dart`
Flutter app entry, Provider wiring, route map.

## 8.2 `mobile_app/lib/services/api_service.dart`
Network gateway used by providers.

What it does:
1. Uses production base URL `https://gabbagefreecity.onrender.com/api`.
2. Reads secure token and injects Authorization header.
3. Wraps auth/report/payment/collector/notification HTTP calls.

## 8.3 Provider Layer

Current providers:
1. `mobile_app/lib/providers/auth_provider.dart`
2. `mobile_app/lib/providers/report_provider.dart`
3. `mobile_app/lib/providers/location_provider.dart`
4. `mobile_app/lib/providers/collector_provider.dart`
5. `mobile_app/lib/providers/notification_provider.dart`

What providers do:
1. Hold screen state.
2. Invoke `ApiService` methods.
3. Expose loading/error/data for UI updates.

## 8.4 Screen Layer

Main screen groups:
1. `mobile_app/lib/screens/auth/*`
2. `mobile_app/lib/screens/resident/*`
3. `mobile_app/lib/screens/collector/*`
4. `mobile_app/lib/screens/common/*`
5. `mobile_app/lib/screens/splash_screen.dart`

## 9. Database Files and Runtime Effects

## 9.1 `database/schema.sql`
Core relational and geospatial model.

## 9.2 `database/migrations/2026-03-16_add_username_password_auth.sql`
Adds `users.username`, `users.password_hash`, and unique username index.

## 9.3 `database/migrations/2026-03-16_add_notifications_table.sql`
Adds notifications table and indexes.

## 9.4 `database/migrations/2026-03-16_add_marzpay_payment_support.sql`
Adds MarzPay payment columns and `apply_marzpay_callback` function.

## 10. End-to-End Runtime Path (Common Resident Journey)

1. Resident authenticates via `/api/auth/*`.
2. Resident submits report via `/api/garbage-reports`.
3. Resident initiates payment via `/api/payments/initiate`.
4. MarzPay callback updates payment/report statuses.
5. Collector discovers and accepts paid pending report.
6. Collector verifies collection and report moves to completed.
7. Notifications and selected SMS messages are generated throughout flow.
