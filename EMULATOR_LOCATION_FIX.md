# Fix Emulator Location Issue

## Problem
The Android emulator defaults to **Google HQ** (Mountain View, CA):
- Latitude: 37.4219983
- Longitude: -122.084

## Solution: Set Custom Location in Emulator

### Method 1: Using Extended Controls (Easiest)

1. **While emulator is running**, click the **3 dots** (...) on the emulator toolbar
2. Click **Location** in the left menu
3. Enter Kampala coordinates:
   - **Latitude:** `0.3476`
   - **Longitude:** `32.6169`
4. Click **"Send"**
5. Restart your Flutter app (`R` for hot restart)

### Method 2: Using Command Line

```powershell
# Set location to Nakawa, Kampala
adb emu geo fix 32.6169 0.3476
```

### Method 3: Using GPX File (for route simulation)

1. Create a GPX file with Kampala locations
2. Load it in emulator's Location settings
3. Play the route

## Common Kampala Locations

```
Nakawa:     Lat: 0.3476,  Lng: 32.6169
Central:    Lat: 0.3163,  Lng: 32.5822
Kawempe:    Lat: 0.3683,  Lng: 32.5594
Makindye:   Lat: 0.2889,  Lng: 32.6014
Rubaga:     Lat: 0.3050,  Lng: 32.5500
```

## Verify Location Changed

After setting location, check Flutter console:
```
🌍 Fetching current location...
✅ Location obtained: 0.3476, 32.6169    ← Should show Kampala coords
   Accuracy: 5.0m
```

## For Testing on Real Device

1. Enable **Developer Options** on your Android phone
2. Enable **USB Debugging**
3. Connect via USB
4. Run: `flutter run`
5. Your real GPS will be used automatically
