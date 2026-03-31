# Garbage Free City (GFC)
Smart Waste Management System for Kampala (KCCA)

Garbage Free City is a mobile-first waste management platform that connects residents and collectors through geolocation, assignment tracking, and mobile money payment workflows.

## Current Implementation Snapshot

1. Authentication uses username and password.
2. Payments use MarzPay for Uganda mobile money collections.
3. Payment callbacks are handled at POST /api/payments/marzpay/callback.
4. In-app notifications are supported with read and unread tracking.
5. SMS integration uses EGO Comms SDK and direct API fallback.
6. Mapping uses OpenStreetMap with flutter_map.

## Tech Stack

### Mobile
1. Flutter
2. flutter_map and OpenStreetMap
3. geolocator
4. provider

### Backend
1. Node.js
2. Express
3. Supabase PostgreSQL + PostGIS

### Integrations
1. MarzPay (mobile money)
2. EGO SMS (notifications)

## Project Structure

```text
GFC/
|- backend/
|  |- controllers/
|  |- routes/
|  |- services/
|  |- config/
|  |- middleware/
|  |- tests/
|  |- server.js
|- mobile_app/
|  |- lib/
|  |  |- models/
|  |  |- providers/
|  |  |- services/
|  |  |- screens/
|  |  |- main.dart
|- database/
|  |- schema.sql
|  |- migrations/
|- docs/
|- readme.md
```

## Quick Start

### 1. Database

1. Create Supabase project.
2. Enable PostGIS extension.
3. Run schema and migrations.

```bash
psql -h your-project.supabase.co -U postgres -d postgres -f database/schema.sql
```

### 2. Backend

```bash
cd backend
npm install
npm run dev
```

Create backend .env:

```env
# Core
NODE_ENV=development
PORT=3000
JWT_SECRET=replace-with-strong-secret
JWT_EXPIRES_IN=7d

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# MarzPay
MARZPAY_API_URL=https://wallet.wearemarz.com/api/v1
MARZPAY_API_KEY=your-marzpay-api-key
MARZPAY_API_SECRET=your-marzpay-api-secret
APP_BASE_URL=https://your-backend-domain
MARZPAY_CALLBACK_URL=https://your-backend-domain/api/payments/marzpay/callback

# EGO SMS
EGO_SMS_API_USERNAME=your-ego-api-username
EGO_SMS_API_KEY=your-ego-api-key
EGO_SMS_SENDER_ID=KCCA-GFC
EGO_SMS_USE_SANDBOX=true
EGO_SMS_FORCE_TEST_MODE=false
EGO_SMS_TEST_NUMBERS=

# Admin controls
ADMIN_USER_IDS=
```

### 3. Mobile App

```bash
cd mobile_app
flutter pub get
flutter run
```

## Payment Flow (MarzPay)

1. Resident initiates payment via POST /api/payments/initiate.
2. Backend validates phone and order ownership.
3. Backend requests MarzPay collection.
4. Backend stores transaction_ref and provider_reference.
5. MarzPay callback updates payment and report status.

Sample initiation payload:

```json
{
  "orderId": "2762eaf0-b179-4cc0-b2b6-1d595de2cdb5",
  "method": "marzpay",
  "phone": "0783858472"
}
```

## Notifications

Supported endpoints:

1. GET /api/notifications
2. PATCH /api/notifications/:id/read
3. PATCH /api/notifications/read-all

## Admin Status

Admin APIs exist for operational payment monitoring:

1. GET /api/payments/wallet-balance
2. GET /api/payments/marzpay-transactions

KCCA dashboard frontend is not implemented yet.

## Testing Notes

Use ngrok for callback tests:

```bash
node backend/server.js
ngrok http 3000
```

Then set MarzPay callback to:

POST https://your-ngrok-url/api/payments/marzpay/callback

## Documentation

See docs folder for:

1. API documentation
2. Deployment guide
3. Planning and SRS
4. Architecture and deep walkthrough

## Support

1. KCCA Support: +256-XXX-XXXXXX
2. Repository: https://github.com/Marcelofury/GabbageFreeCity
