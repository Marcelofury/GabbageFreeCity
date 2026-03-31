# GFC Code Architecture and Hierarchy

This document describes what each architecture heading does and how each part communicates with other files and external systems.

## 1. Top-Level Modules

1. `backend/`: Node.js Express API runtime.
2. `mobile_app/`: Flutter client application.
3. `database/`: SQL schema and migrations (Supabase/PostgreSQL).
4. `docs/`: Technical and product documentation.

System communication summary:
1. Mobile app communicates with backend over HTTPS REST.
2. Backend communicates with Supabase (database), MarzPay (payments), and EGO SMS (messaging).
3. Database function logic finalizes callback-driven payment transitions.

## 2. Backend Architecture Hierarchy

## 2.1 Entry Layer

Primary file:
1. `backend/server.js`

What it does:
1. Builds Express app runtime.
2. Registers middleware and route modules.
3. Exposes `/health` and starts HTTP listener.

How it communicates:
1. Calls all route files by mounting them under `/api/*`.
2. Delegates failures to `middleware/errorHandler.js`.

## 2.2 Configuration Layer

Files:
1. `backend/config/supabase.js`
2. `backend/config/smsService.js`
3. `backend/config/africasTalking.js` (legacy support file)

What it does:
1. Creates reusable integration clients and wrappers.
2. Reads environment variables for secrets and mode toggles.

How it communicates:
1. `supabase.js` is imported by routes/controllers/services for DB operations.
2. `smsService.js` is imported by auth and notification service for SMS sends.

## 2.3 Middleware Layer

Files:
1. `backend/middleware/auth.js`
2. `backend/middleware/errorHandler.js`

What it does:
1. Verifies JWT tokens, user status, and route role constraints.
2. Normalizes thrown errors into consistent API responses.

How it communicates:
1. Route files invoke `authenticateToken` and `requireUserType` before business handlers.
2. Any `next(error)` call reaches `errorHandler` and returns standardized JSON.

## 2.4 Route Layer

Files:
1. `backend/routes/authRoutes.js`
2. `backend/routes/garbageReportRoutes.js`
3. `backend/routes/paymentRoutes.js`
4. `backend/routes/collectorRoutes.js`
5. `backend/routes/notificationRoutes.js`

What it does:
1. Defines endpoint paths and request validation boundaries.
2. Applies auth/role middleware chain.
3. Delegates payment orchestration to controller layer.

How it communicates:
1. Reads/writes database via Supabase client.
2. Calls `notificationService` to create in-app notifications.
3. Uses `smsService` directly (auth) or indirectly (notification service).

## 2.5 Controller and Service Layer

Files:
1. `backend/controllers/paymentController.js`
2. `backend/services/marzpayService.js`
3. `backend/services/notificationService.js`

What it does:
1. Handles payment initiation, callback mapping, and admin payment reads.
2. Encapsulates MarzPay HTTP calls and phone/provider validation.
3. Persists notification events and optional SMS dispatch.

How it communicates:
1. `paymentController` calls `marzpayService` and Supabase RPC `apply_marzpay_callback`.
2. `paymentController` and routes call `notificationService` to notify users.
3. `notificationService` calls `smsService` when `sendSms=true`.

## 3. Mobile App Architecture Hierarchy

## 3.1 App Entry and Route Map

Primary file:
1. `mobile_app/lib/main.dart`

What it does:
1. Registers providers.
2. Declares route table and startup screen.
3. Defines app-level theme.

How it communicates:
1. Screens resolve providers from dependency graph.
2. Providers call API and push state changes back to widgets.

## 3.2 Provider Layer

Files:
1. `mobile_app/lib/providers/auth_provider.dart`
2. `mobile_app/lib/providers/report_provider.dart`
3. `mobile_app/lib/providers/location_provider.dart`
4. `mobile_app/lib/providers/collector_provider.dart`
5. `mobile_app/lib/providers/notification_provider.dart`

What it does:
1. Owns UI state (`loading`, `error`, data lists).
2. Calls API methods and transforms result for screens.

How it communicates:
1. Provider -> `ApiService` for network I/O.
2. Provider -> Flutter widgets via `notifyListeners()` updates.

## 3.3 Service Layer

Files:
1. `mobile_app/lib/services/api_service.dart`
2. `mobile_app/lib/services/location_service.dart`

What it does:
1. Centralizes HTTP calls and auth header injection.
2. Handles location utility operations for device context.

How it communicates:
1. Uses HTTPS to backend API (`https://gabbagefreecity.onrender.com/api`).
2. Reads secure token storage for Authorization headers.

## 3.4 Screen Layer

Directories:
1. `mobile_app/lib/screens/auth/`
2. `mobile_app/lib/screens/resident/`
3. `mobile_app/lib/screens/collector/`
4. `mobile_app/lib/screens/common/`

What it does:
1. Captures user actions and displays stateful UI.
2. Triggers provider methods for API operations.

How it communicates:
1. UI events -> provider method calls.
2. Provider state -> rebuilt UI.

## 4. Database Architecture Hierarchy

Files:
1. `database/schema.sql`
2. `database/migrations/2026-03-16_add_username_password_auth.sql`
3. `database/migrations/2026-03-16_add_notifications_table.sql`
4. `database/migrations/2026-03-16_add_marzpay_payment_support.sql`

What it does:
1. Stores core domain entities (`users`, `garbage_reports`, `payments`, `notifications`, `collection_logs`).
2. Enforces schema and index constraints for consistency/performance.
3. Implements callback transition logic in SQL function `apply_marzpay_callback`.

How it communicates:
1. Backend routes/services execute CRUD and RPC calls via Supabase.
2. Callback function updates both `payments` and `garbage_reports` in one transition path.

## 5. End-to-End Communication Flow

1. User action occurs on Flutter screen.
2. Screen calls Provider.
3. Provider calls `ApiService` endpoint.
4. Backend route authenticates/authorizes request.
5. Route/controller invokes Supabase and external provider services.
6. Backend returns JSON response.
7. Provider updates app state; UI rerenders.

## 6. Current Architecture Characteristics

1. Payment rail is MarzPay only.
2. Authentication is username/password + JWT.
3. Notifications are first-class (API + DB + provider).
4. SMS sending is integrated through notification and auth workflows.
5. Admin payment monitoring APIs exist without a dedicated dashboard frontend.
