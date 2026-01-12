# Garbage Free City (GFC) - Deployment Guide

## Prerequisites

- Node.js 18+ installed
- Flutter SDK installed
- Supabase account
- Flutterwave account
- Africa's Talking account
- Google Maps API key

---

## Backend Deployment

### 1. Setup Supabase Database

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Copy your project URL and keys
3. Run the SQL schema:
   ```bash
   psql -h db.your-project.supabase.co -U postgres -d postgres -f database/schema.sql
   ```

### 2. Configure Environment

Create `.env` file in `backend/`:
```bash
cp .env.example .env
```

Edit `.env` with your actual credentials:
- Supabase URL and keys
- Flutterwave keys
- Africa's Talking credentials
- JWT secret

### 3. Install Dependencies

```bash
cd backend
npm install
```

### 4. Test Locally

```bash
npm run dev
```

Visit: http://localhost:3000/health

### 5. Deploy to Production

#### Option A: Deploy to Railway/Render

1. Push code to GitHub
2. Connect repository to Railway/Render
3. Set environment variables
4. Deploy

#### Option B: Deploy to VPS

```bash
# Install PM2
npm install -g pm2

# Start server
pm2 start server.js --name gfc-backend

# Save PM2 process
pm2 save
pm2 startup
```

### 6. Configure Flutterwave Webhook

1. Go to Flutterwave Dashboard → Settings → Webhooks
2. Add URL: `https://your-domain.com/webhooks/flutterwave`
3. Copy secret hash to `.env`

---

## Mobile App Deployment

### 1. Configure API Endpoint

Edit `mobile_app/lib/services/api_service.dart`:
```dart
static const String BASE_URL = 'https://your-backend-url.com/api';
```

### 2. Add Google Maps API Key

#### Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE"/>
```

#### iOS
Edit `ios/Runner/AppDelegate.swift`:
```swift
GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

### 3. Build Android APK

```bash
cd mobile_app
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### 4. Build iOS App

```bash
flutter build ios --release
```

Then use Xcode to archive and submit to App Store.

### 5. Testing on Physical Devices

#### Android
```bash
flutter run --release
```

#### iOS
```bash
flutter run --release -d "iPhone Name"
```

---

## Production Checklist

### Backend
- [ ] Environment variables set
- [ ] Database migrations run
- [ ] SSL certificate configured
- [ ] CORS properly configured
- [ ] Rate limiting enabled
- [ ] Error logging setup (Sentry, etc.)
- [ ] Webhook endpoints tested
- [ ] API documentation published

### Mobile App
- [ ] API endpoints updated to production URLs
- [ ] Google Maps API key added
- [ ] App icons and splash screens configured
- [ ] Permissions properly requested
- [ ] Error handling implemented
- [ ] Analytics configured (optional)
- [ ] Test on multiple devices
- [ ] App signed for release

### Third-Party Services
- [ ] Flutterwave webhooks configured
- [ ] Africa's Talking sender ID approved
- [ ] Google Maps billing enabled
- [ ] Supabase backups configured

---

## Monitoring

### Backend Health Check
```bash
curl https://your-backend.com/health
```

### Database Backups
Configure automatic backups in Supabase dashboard

### Logs
```bash
# PM2 logs
pm2 logs gfc-backend

# Or check your hosting provider's logs
```

---

## Troubleshooting

### Payment webhooks not working
1. Check webhook URL in Flutterwave dashboard
2. Verify secret hash matches `.env`
3. Check server logs for errors
4. Test with ngrok for local testing

### Location not working
1. Ensure GPS permissions granted
2. Check API keys are valid
3. Test on physical device (emulator GPS can be unreliable)

### SMS not sending
1. Verify Africa's Talking credentials
2. Check sender ID is approved
3. Ensure phone numbers are in correct format (+256...)

---

## Support

For issues or questions:
- GitHub: https://github.com/Marcelofury/GabbageFreeCity
- Email: support@kcca.go.ug
