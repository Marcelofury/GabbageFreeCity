# Garbage Free City (GFC) Deployment Guide

This guide documents only what is currently used in this project for deployment.

## Deployed Stack (Current)

1. Backend API: Render web service (`gfc-backend`)
2. Backend URL in use: `https://gabbagefreecity.onrender.com`
3. Database: Supabase PostgreSQL (with PostGIS)
4. Mobile app production API target: `https://gabbagefreecity.onrender.com/api` (configured in `mobile_app/lib/services/api_service.dart`)

## Where Deployment Is Defined

1. Render service configuration: `backend/render.yaml`
2. Runtime server setup: `backend/server.js`
3. Mobile API base URL: `mobile_app/lib/services/api_service.dart`

## Backend Deployment on Render

### 1. Service Configuration Used

The active Render blueprint points to backend root directory and starts Node server:
1. `type: web`
2. `name: gfc-backend`
3. `env: node`
4. `rootDir: backend`
5. `buildCommand: npm install`
6. `startCommand: npm start`

### 2. Environment Variables Used

Set these in Render dashboard (or via blueprint sync where allowed):

```env
NODE_ENV=production
PORT=3000
JWT_SECRET=<required>
JWT_EXPIRES_IN=7d

SUPABASE_URL=<required>
SUPABASE_ANON_KEY=<required>
SUPABASE_SERVICE_KEY=<required>

APP_BASE_URL=<render service url>
MARZPAY_API_URL=https://wallet.wearemarz.com/api/v1
MARZPAY_API_KEY=<required>
MARZPAY_API_SECRET=<required>
MARZPAY_CALLBACK_URL=https://gabbagefreecity.onrender.com/api/payments/marzpay/callback

EGO_SMS_API_USERNAME=<required for sms>
EGO_SMS_API_KEY=<required for sms>
EGO_SMS_SENDER_ID=KCCA-GFC
EGO_SMS_USE_SANDBOX=true
EGO_SMS_TEST_NUMBERS=+256783858472,+256785510666
EGO_SMS_FORCE_TEST_MODE=false

DEFAULT_COLLECTION_FEE=5000
ADMIN_USER_IDS=
```

### 3. Deployment Implementation Flow

1. Push backend changes to repository.
2. Render builds with `npm install` inside `backend`.
3. Render starts app with `npm start`.
4. `backend/server.js` mounts API routes under `/api` and health endpoint `/health`.
5. Render exposes public URL used by mobile app and MarzPay callbacks.

### 4. Post-Deploy Validation

1. Health check: `GET https://gabbagefreecity.onrender.com/health`
2. API check: `GET https://gabbagefreecity.onrender.com/api/...`
3. Confirm login/register flow from mobile app.
4. Confirm MarzPay callback receives and updates statuses.
5. Confirm notification and SMS events are generated as expected.

## Database Deployment (Supabase)

### 1. Applied Schema/Migrations

1. Base schema: `database/schema.sql`
2. Username/password auth migration: `database/migrations/2026-03-16_add_username_password_auth.sql`
3. Notifications migration: `database/migrations/2026-03-16_add_notifications_table.sql`
4. MarzPay support migration: `database/migrations/2026-03-16_add_marzpay_payment_support.sql`

### 2. How It Is Used in Runtime

1. Backend uses Supabase service role for reads/writes.
2. Payment callback processing relies on Postgres function `apply_marzpay_callback`.
3. Nearby report fetch uses PostGIS/RPC patterns (`get_nearby_reports` and coordinate extraction).

## MarzPay Callback Deployment Detail

1. Public callback endpoint: `POST /api/payments/marzpay/callback`
2. Absolute callback URL configured for provider:
	`https://gabbagefreecity.onrender.com/api/payments/marzpay/callback`
3. Backend callback handler:
	1. Extracts `transactionRef/reference` and provider status.
	2. Calls DB function `apply_marzpay_callback`.
	3. Updates payment/report statuses and sends payment notification.

## Notes

1. This guide intentionally excludes unused alternatives (for example VPS/PM2) to match the current deployment reality.
2. If deployment target changes, update this file and `mobile_app/lib/services/api_service.dart` together.
