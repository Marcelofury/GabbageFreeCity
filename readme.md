# 🗑️ Garbage Free City (GFC)
**Smart Waste Management System for Kampala (KCCA)**

A mobile-first waste management solution connecting Kampala residents with garbage collectors through real-time GPS tracking, mobile money payments, and optimized route planning.

---

## 📱 Overview

**Garbage Free City (GFC)** empowers residents to report garbage pile-ups and enables efficient collection through:
- 📍 **GPS-based reporting** with real-time location tracking
- 💰 **Mobile Money payments** via Flutterwave (MTN & Airtel Money)
- 🚛 **Optimized routing** using PostGIS for nearest collector assignment
- 📲 **SMS notifications** via Africa's Talking
- ✅ **QR code verification** at collection points

---

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform mobile app (iOS/Android)
- **google_maps_flutter** - Location visualization
- **geolocator** - GPS coordinate capture

### Backend
- **Node.js + Express** - REST API and business logic
- **Supabase (PostgreSQL + PostGIS)** - Database with geospatial support

### Integrations
- **Flutterwave** - Mobile Money payments (webhooks)
- **Africa's Talking** - SMS notifications
- **Google Maps API** - Route optimization

---

## 📂 Project Structure

```
GFC/
├── database/
│   └── schema.sql                    # Supabase schema with PostGIS
│
├── backend/
│   └── webhooks/
│       └── flutterwaveWebhook.js     # Payment webhook handler
│
├── mobile_app/
│   └── lib/
│       └── services/
│           └── location_service.dart  # GPS & location services
│
└── README.md
```

---

## 🚀 Getting Started

### 1️⃣ Database Setup (Supabase)

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Enable PostGIS extension:
   ```sql
   CREATE EXTENSION IF NOT EXISTS postgis;
   ```
3. Run the schema:
   ```bash
   psql -h your-project.supabase.co -U postgres -d postgres -f database/schema.sql
   ```

### 2️⃣ Backend Setup (Node.js)

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

   # Flutterwave
   FLUTTERWAVE_SECRET_HASH=your-webhook-secret
   FLUTTERWAVE_PUBLIC_KEY=FLWPUBK-xxxxx
   FLUTTERWAVE_SECRET_KEY=FLWSECK-xxxxx

   # Africa's Talking
   AFRICAS_TALKING_API_KEY=your-api-key
   AFRICAS_TALKING_USERNAME=KCCA
   ```

3. Configure Flutterwave webhook:
   - Go to [Flutterwave Dashboard](https://dashboard.flutterwave.com/dashboard/settings/webhooks)
   - Add URL: `https://your-domain.com/webhooks/flutterwave`
   - Copy secret hash to `.env`

### 3️⃣ Mobile App Setup (Flutter)

1. Install dependencies:
   ```yaml
   # pubspec.yaml
   dependencies:
     geolocator: ^10.1.0
     google_maps_flutter: ^2.5.0
     http: ^1.1.0
     permission_handler: ^11.0.1
   ```

2. Configure Android (`android/app/src/main/AndroidManifest.xml`):
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.INTERNET" />
   
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
   ```

3. Configure iOS (`ios/Runner/Info.plist`):
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>GFC needs location to report garbage pile-ups</string>
   ```

---

## 📊 Database Schema

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
- Mobile Money transactions via Flutterwave
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

## 🔐 Security Notes

### Webhook Verification
The Flutterwave webhook verifies authenticity using:
```javascript
const signature = req.headers['verif-hash'];
if (signature !== process.env.FLUTTERWAVE_SECRET_HASH) {
    return res.status(401).json({ error: 'Invalid signature' });
}
```

### Environment Variables
**Never commit `.env` files!** Add to `.gitignore`:
```
.env
.env.local
```

---

## 🇺🇬 Uganda-Specific Context

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

## 🧪 Testing

### Test Webhook Locally (ngrok)
```bash
# Terminal 1: Start server
node server.js

# Terminal 2: Expose to internet
ngrok http 3000

# Copy ngrok URL to Flutterwave dashboard
# URL: https://abc123.ngrok.io/webhooks/flutterwave
```

### Test Payment Flow
1. Create garbage report via app
2. Initiate Flutterwave payment
3. Watch webhook logs: `POST /webhooks/flutterwave`
4. Verify payment status updated in Supabase
5. Check SMS sent to resident

---

## 📞 Support

- **KCCA Support**: +256-XXX-XXXXXX
- **Developer**: [GitHub](https://github.com/Marcelofury/GabbageFreeCity)

---

## 📄 License

Built for KCCA (Kampala Capital City Authority) - 2026

---

**Webale nyo! (Thank you!)** 🇺🇬
