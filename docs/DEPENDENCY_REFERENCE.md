# Dependency Reference

Last updated: April 1, 2026

This document explains all dependencies declared in:
- `backend/package.json`
- `mobile_app/pubspec.yaml`

It covers what each package does and why it is used in this project.

## 1. Backend Dependencies (Node.js)

### Runtime dependencies (`dependencies`)

| Package | Version | What it does | Why it is used in GFC |
| --- | --- | --- | --- |
| @supabase/supabase-js | ^2.39.0 | Official Supabase client for database/auth/storage APIs. | Used as the backend data-access client for tables like users, garbage_reports, payments, and notifications. |
| axios | ^1.6.2 | Promise-based HTTP client for Node.js. | Used to call external APIs such as MarzPay and SMS services from backend services. |
| bcryptjs | ^2.4.3 | Password hashing library compatible with bcrypt format. | Used to hash and verify user passwords for username/password authentication. |
| comms-sdk | ^1.0.2 | Communication SDK (SMS integration client). | Used by the SMS service layer to send notification SMS messages. |
| cors | ^2.8.5 | Express middleware for Cross-Origin Resource Sharing. | Allows mobile/web clients to call backend APIs across origins safely. |
| dotenv | ^16.3.1 | Loads environment variables from `.env` files. | Used to load API keys, secrets, database URLs, and service configuration at startup. |
| express | ^4.18.2 | Web framework for Node.js APIs. | Core HTTP server and routing framework for all backend endpoints. |
| express-rate-limit | ^7.1.5 | Request throttling middleware for Express. | Helps protect public/auth endpoints from brute-force and abuse traffic. |
| helmet | ^7.1.0 | Security headers middleware for Express. | Adds secure HTTP headers to reduce common web attack surface. |
| joi | ^17.11.0 | Schema validation library. | Used to validate incoming request payloads in auth, reporting, and payment flows. |
| jsonwebtoken | ^9.0.2 | JWT creation and verification library. | Used for stateless auth tokens and protected route access control. |
| morgan | ^1.10.0 | HTTP request logging middleware. | Used for API request logging during development and operations. |
| qrcode | ^1.5.3 | QR generation library. | Used to generate QR payloads for collector verification flows. |
| uuid | ^9.0.1 | UUID generator package. | Declared for stable UUID generation support in transaction/reference flows (current code often uses `crypto.randomUUID`). |

### Development dependencies (`devDependencies`)

| Package | Version | What it does | Why it is used in GFC |
| --- | --- | --- | --- |
| jest | ^30.0.5 | JavaScript testing framework. | Main backend unit/integration test runner with coverage output. |
| nodemon | ^3.0.2 | Development auto-restart tool. | Restarts backend server automatically when files change. |
| supertest | ^7.1.1 | HTTP testing library for Node.js servers. | Used to test API endpoints and middleware behavior in backend tests. |

## 2. Mobile App Dependencies (Flutter)

### Runtime dependencies (`dependencies`)

| Package | Version | What it does | Why it is used in GFC |
| --- | --- | --- | --- |
| flutter (sdk) | sdk | Core Flutter SDK. | Base framework for building the mobile app UI and runtime. |
| cupertino_icons | ^1.0.2 | iOS-style icon pack. | Provides Cupertino icon assets for cross-platform UI consistency. |
| google_fonts | ^6.1.0 | Easy access to Google Fonts. | Used to apply branded typography in app theme and screens. |
| flutter_svg | ^2.0.9 | SVG rendering support in Flutter. | Enables vector icon/illustration rendering where SVG assets are used. |
| geolocator | ^10.1.0 | Location/GPS services plugin. | Used to fetch user/collector location for report and assignment workflows. |
| flutter_map | ^6.1.0 | OpenStreetMap-based map widget. | Used to display map UIs for report location and nearby assignments. |
| latlong2 | ^0.9.0 | Latitude/longitude utility models and helpers. | Used with map/location features to model and compute coordinates. |
| permission_handler | ^11.0.1 | Runtime permission handling plugin. | Used to request/check location and device permissions needed by app features. |
| flutter_map_cancellable_tile_provider | ^2.0.0 | Cancellable tile loading for flutter_map. | Improves map tile request behavior and user experience during map movement. |
| http | ^1.1.0 | Lightweight HTTP client. | Used by API service calls to communicate with backend endpoints. |
| dio | ^5.4.0 | Advanced HTTP client with interceptors and richer networking features. | Declared to support more advanced API workflows (timeouts/interceptors/retries) as app networking grows. |
| provider | ^6.1.1 | State management package. | Primary app state management for auth, notifications, and feature screens. |
| shared_preferences | ^2.2.2 | Simple local key-value storage. | Declared for non-sensitive persisted app preferences and lightweight caching. |
| flutter_secure_storage | ^9.0.0 | Encrypted secure key-value storage. | Used to store sensitive values such as auth tokens on-device. |
| image_picker | ^1.0.4 | Camera/gallery picker plugin. | Declared for attaching garbage photos from camera/gallery in reporting flows. |
| cached_network_image | ^3.3.0 | Network image loader with caching. | Declared for efficient image rendering/caching of remote report media. |
| mobile_scanner | ^5.2.3 | Camera-based barcode/QR scanner. | Used for collector QR scanning and collection verification flow. |
| intl | ^0.18.1 | Internationalization/date-number formatting package. | Used for date/time formatting in report and history screens. |
| url_launcher | ^6.2.1 | Launch URLs, phone, and external intents. | Used to open external links/actions from app screens (for example About/help links). |

### Development dependencies (`dev_dependencies`)

| Package | Version | What it does | Why it is used in GFC |
| --- | --- | --- | --- |
| flutter_test (sdk) | sdk | Flutter testing SDK. | Base testing tools for widget and unit tests in the Flutter app. |
| flutter_lints | ^3.0.0 | Recommended Dart/Flutter lint rules. | Enforces code quality and consistency through static analysis. |
| flutter_launcher_icons | ^0.13.1 | Generates platform launcher icons from source asset. | Used to build branded Android launcher icons from app assets. |

## 3. Notes

- Some packages are actively imported in code today, while others are declared to support planned or partially integrated features.
- Keep this file synchronized whenever dependency versions are upgraded, removed, or replaced.