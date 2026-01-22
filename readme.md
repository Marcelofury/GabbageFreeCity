# Garbage Free City (GFC)
**Smart Waste Management System for Kampala (KCCA)**

A mobile-first waste management solution connecting Kampala residents with garbage collectors through real-time GPS tracking, mobile money payments, and optimized route planning.

---

## Overview

**Garbage Free City (GFC)** empowers residents to report garbage pile-ups and enables efficient collection through:
- **GPS-based reporting** with real-time location tracking using OpenStreetMap
- **Mobile Money payments** via Pesapal (MTN & Airtel Money)
- **Optimized routing** using PostGIS for nearest collector assignment
- **SMS notifications** via Africa's Talking
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
- **Pesapal** - Mobile Money payments (MTN & Airtel Money)
- **Africa's Talking** - SMS notifications
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
│   │   └── africasTalking.js                # SMS service config
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

   # Pesapal
   PESAPAL_CONSUMER_KEY=your-consumer-key
   PESAPAL_CONSUMER_SECRET=your-consumer-secret
   PESAPAL_ENVIRONMENT=sandbox

   # Africa's Talking
   AFRICAS_TALKING_API_KEY=your-api-key
   AFRICAS_TALKING_USERNAME=KCCA
   ```

3. Configure Pesapal IPN:
   - Go to [Pesapal Dashboard](https://www.pesapal.com)
   - Register IPN URL: `https://your-domain.com/webhooks/pesapal`
   - IPN will send payment notifications

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
- Mobile Money transactions via Pesapal
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
Pesapal sends IPN (Instant Payment Notification) via GET request:
```javascript
const { OrderTrackingId, OrderMerchantReference } = req.query;
// Verify transaction status with Pesapal API
const transaction = await getTransactionStatus(OrderTrackingId);
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

### SMS (Africa's Talking)
- Critical for users without data
- Use approved sender ID: "KCCA-GFC"
- Keep messages concise (160 chars)

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

# Register IPN URL in Pesapal dashboard
# URL: https://abc123.ngrok.io/webhooks/pesapal
```

### Test Payment Flow
1. Create garbage report via app
2. Initiate Pesapal payment
3. Watch webhook logs: `GET /webhooks/pesapal`
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
