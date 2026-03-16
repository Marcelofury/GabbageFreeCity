# Garbage Free City (GFC)
**Smart Waste Management System for Kampala (KCCA)**

A mobile-first waste management solution connecting Kampala residents with garbage collectors through real-time GPS tracking, mobile money payments, and optimized route planning.

## MarzPay Payments (Current)

The backend now uses MarzPay for Mobile Money collections in Uganda.

- Supported providers: MTN and Airtel Uganda
- Initiation endpoint: POST /api/payments/initiate
- Callback endpoint: POST /api/payments/marzpay/callback

Required environment variables:

```env
MARZPAY_API_KEY=your-marzpay-api-key
MARZPAY_API_SECRET=your-marzpay-api-secret
MARZPAY_API_URL=https://wallet.wearemarz.com/api/v1
APP_BASE_URL=https://your-backend-domain
```

Sample initiate request:

```json
{
   "orderId": "2762eaf0-b179-4cc0-b2b6-1d595de2cdb5",
   "method": "marzpay",
   "phone": "0783858472"
}
```

Sample initiate response:

```json
{
   "success": true,
   "message": "Collection initiated successfully.",
   "data": {
      "transactionRef": "MARZ-1710583000000-ab12cd34",
      "status": "pending",
      "providerRef": "provider-or-reference",
      "message": "Collection initiated successfully."
   }
}
```

Troubleshooting:

- Wallet balance endpoint fails: whitelist your backend server IP in MarzPay dashboard.
- Callback not updating records: verify APP_BASE_URL and public endpoint /api/payments/marzpay/callback.
- Validation errors for phone: use Uganda numbers that normalize to +256XXXXXXXXX and MTN/Airtel prefixes only.

---

## Overview

**Garbage Free City (GFC)** empowers residents to report garbage pile-ups and enables efficient collection through:
- **GPS-based reporting** with real-time location tracking using OpenStreetMap
- **Mobile Money payments** via MarzPay (MTN & Airtel Money)
- **Optimized routing** using PostGIS for nearest collector assignment
- **SMS notifications** via EGO Comms SDK (Uganda)
- **Interactive mapping** with OpenStreetMap (no billing required)

---

## Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile app (iOS/Android)
- **OpenStreetMap** - Free interactive maps via flutter_map
- **geolocator** - GPS coordinate capture

### Backend
- **Node.js + Express** - REST API and business logic
- **Supabase (PostgreSQL + PostGIS)** - Database with geospatial support

### Integrations
- **MarzPay** - Mobile Money payments (MTN & Airtel Money)
- **EGO SMS (Comms SDK)** - SMS notifications (Uganda)
- **OpenStreetMap** - Free, no billing required, better Uganda coverage

---

## Project Structure

```
GFC/
├── database/
│   └── schema.sql                           # Supabase schema with PostGIS
│
├── backend/
│   ├── config/
│   │   ├── supabase.js                      # Supabase client config
│   │   └── smsService.js                    # Mambo SMS service config
│   ├── middleware/
│   │   ├── auth.js                          # JWT authentication
│   │   └── errorHandler.js                  # Global error handler
│   ├── routes/
│   │   ├── authRoutes.js                    # Login/Register endpoints
│   │   ├── garbageReportRoutes.js           # Report management
│   │   ├── paymentRoutes.js                 # Payment initiation
│   │   └── collectorRoutes.js               # Collector operations
│   ├── webhooks/
│   │   └── pesapalWebhook.js                # Payment webhook handler
│   ├── .env.example                         # Environment variables template
│   ├── package.json                         # Node dependencies
│   └── server.js                            # Main Express server
│
├── mobile_app/
│   ├── lib/
│   │   ├── models/
│   │   │   ├── user.dart                    # User model
│   │   │   └── garbage_report.dart          # Report model
│   │   ├── providers/
│   │   │   ├── auth_provider.dart           # Auth state management
│   │   │   ├── location_provider.dart       # Location state
│   │   │   └── report_provider.dart         # Reports state
│   │   ├── screens/
│   │   │   ├── splash_screen.dart           # App splash screen
│   │   │   ├── auth/
│   │   │   │   ├── login_screen.dart        # Login UI
│   │   │   │   └── register_screen.dart     # Registration UI
│   │   │   ├── resident/
│   │   │   │   ├── resident_home_screen.dart
│   │   │   │   ├── report_garbage_screen.dart
│   │   │   │   └── my_reports_screen.dart
│   │   │   └── collector/
│   │   │       └── collector_home_screen.dart
│   │   ├── services/
│   │   │   ├── api_service.dart             # HTTP API client
│   │   │   └── location_service.dart        # GPS services
│   │   └── main.dart                        # App entry point
│   ├── android/
│   │   └── app/src/main/AndroidManifest.xml # Android config
│   ├── ios/
│   │   └── Runner/Info.plist                # iOS config
│   └── pubspec.yaml                         # Flutter dependencies
│
├── docs/
│   ├── API_DOCUMENTATION.md                 # API endpoints reference
│   └── DEPLOYMENT_GUIDE.md                  # Deployment instructions
│
├── .gitignore
└── README.md
```

---

## Getting Started

### 1. Database Setup (Supabase)

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Enable PostGIS extension:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
3. Run the schema:
   ```bash
   psql -h your-project.supabase.co -U postgres -d postgres -f database/schema.sql
   ```

### 2. Backend Setup (Node.js)

1. Install dependencies:
   ```bash
   cd backend
   npm install express @supabase/supabase-js africastalking crypto
   ```

2. Create `.env` file:
   ```env
   # Supabase
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_SERVICE_KEY=your-service-role-key

   # MarzPay
   MARZPAY_API_URL=https://wallet.wearemarz.com/api/v1
   MARZPAY_API_KEY=your-marzpay-api-key
   MARZPAY_API_SECRET=your-marzpay-api-secret
   MARZPAY_CALLBACK_URL=https://your-backend-domain.com/api/payments/marzpay/callback

   # EGO SMS (Uganda)
   EGO_SMS_API_USERNAME=your-ego-api-username
   EGO_SMS_API_KEY=your-ego-api-key
   EGO_SMS_SENDER_ID=KCCA-GFC
   ```

3. Configure MarzPay callback:
   - Set `APP_BASE_URL` to your backend public URL
   - Ensure callback endpoint is public: `/api/payments/marzpay/callback`
   - Whitelist your backend server IP in MarzPay dashboard for restricted actions (for example wallet balance)

### 3. Mobile App Setup (Flutter)

1. Install dependencies:
   ```yaml
   # pubspec.yaml
   dependencies:
     geolocator: ^10.1.0
     flutter_map: ^6.1.0
     latlong2: ^0.9.0
     http: ^1.1.0
     permission_handler: ^11.0.1
   ```

2. Configure Android (`android/app/src/main/AndroidManifest.xml`):
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.INTERNET" />
   ```
   
   **Note:** No API key required! OpenStreetMap is free and open-source.

3. Configure iOS (`ios/Runner/Info.plist`):
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>GFC needs location to report garbage pile-ups</string>
   ```

---

## Database Schema

### Tables

#### **users**
- Stores residents and collectors
- Uses PostGIS `geography` type for location tracking
- Fields: `id`, `phone_number`, `full_name`, `user_type`, `home_location`, `current_location`

#### **garbage_reports**
- Tracks reported garbage pile-ups
- Links to residents and assigned collectors
- Fields: `id`, `resident_id`, `location`, `status`, `payment_amount`

#### **payments**
- Mobile Money transactions via MarzPay
- Stores webhook responses
- Fields: `id`, `report_id`, `transaction_id`, `payment_status`, `amount`

#### **collection_logs**
- QR code scan verification
- Tracks actual collection events
- Fields: `id`, `report_id`, `collector_id`, `qr_code_scanned`, `collection_location`

### PostGIS Functions

```sql
-- Find nearest collector to a report
SELECT * FROM find_nearest_collector('report_uuid');

-- Calculate distance between points
SELECT calculate_distance(location1, location2);
```

---

## Security Notes

### Webhook Verification
MarzPay sends payment callback updates to:
```javascript
POST /api/payments/marzpay/callback
```

### Environment Variables
**Never commit `.env` files!** Add to `.gitignore`:
```
.env
.env.local
```

---

## Uganda-Specific Context

### Mobile Money
- **MTN Mobile Money** (*165#) - 60%+ market share
- **Airtel Money** (*185#) - 30%+ market share
- Typical transaction: UGX 5,000 - 50,000

### SMS (EGO SMS)
- Critical for users without data
- Ugandan-compatible SDK integration
- Use approved sender ID: "KCCA-GFC"
- Keep messages concise (160 chars)
- Configure API credentials in backend `.env`

### Kampala Divisions
- **Central** (0.3163°N, 32.5822°E)
- **Kawempe** (0.3683°N, 32.5594°E)
- **Makindye** (0.2889°N, 32.6014°E)
- **Nakawa** (0.3476°N, 32.6169°E)
- **Rubaga** (0.3050°N, 32.5500°E)

---

## Testing

### Test Webhook Locally (ngrok)
```bash
# Terminal 1: Start server
node server.js

# Terminal 2: Expose to internet
ngrok http 3000

# Use callback URL in MarzPay dashboard
# URL: https://abc123.ngrok.io/api/payments/marzpay/callback
```

### Test Payment Flow
1. Create garbage report via app
2. Initiate MarzPay payment
3. Watch callback logs: `POST /api/payments/marzpay/callback`
4. Verify payment status updated in Supabase
5. Check SMS sent to resident

---

## Support

- **KCCA Support**: +256-XXX-XXXXXX
- **Developer**: [GitHub](https://github.com/Marcelofury/GabbageFreeCity)

---

## License

Built for KCCA (Kampala Capital City Authority) - 2026

---

**Webale nyo! (Thank you!)**
