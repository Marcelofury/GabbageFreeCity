/// GARBAGE FREE CITY (GFC) - LOCATION SERVICE
/// 
/// Flutter service for capturing user's current GPS location
/// and sending it to the Node.js backend.
/// 
/// This service handles:
/// - Getting current GPS coordinates using geolocator
/// - Requesting location permissions
/// - Displaying location on Google Maps
/// - Sending location data to backend API
/// 
/// Packages required:
/// - geolocator: ^10.1.0
/// - google_maps_flutter: ^2.5.0
/// - http: ^1.1.0
/// - permission_handler: ^11.0.1
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// LocationService handles all location-related operations
class LocationService {
  // Backend API endpoint (replace with your actual backend URL)
  static const String API_BASE_URL = 'https://your-backend.com/api';
  
  /// Check if location services are enabled and permissions granted
  /// 
  /// Returns true if ready to use location, false otherwise
  static Future<bool> checkLocationPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;
    
    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      debugPrint('❌ Location services are disabled');
      return false;
    }
    
    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permissions denied');
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied
      debugPrint('❌ Location permissions permanently denied');
      return false;
    }
    
    debugPrint('✅ Location permissions granted');
    return true;
  }
  
  /// Get the user's current location
  /// 
  /// Returns Position object with latitude, longitude, accuracy, etc.
  /// Throws exception if location cannot be retrieved
  static Future<Position> getCurrentLocation() async {
    try {
      // Check permissions first
      bool hasPermission = await checkLocationPermissions();
      if (!hasPermission) {
        throw Exception('Location permission not granted');
      }
      
      // Get current position with high accuracy
      // This is important for Uganda/Kampala to get precise garbage pile-up locations
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high, // High accuracy for precise location
        timeLimit: const Duration(seconds: 10), // Timeout after 10 seconds
      );
      
      debugPrint('📍 Location captured: ${position.latitude}, ${position.longitude}');
      debugPrint('   Accuracy: ${position.accuracy} meters');
      
      return position;
      
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      rethrow;
    }
  }
  
  /// Report a garbage pile-up by sending location to backend
  /// 
  /// @param position: GPS coordinates of garbage location
  /// @param description: User's description of the garbage pile
  /// @param estimatedVolume: Size estimate (small, medium, large)
  /// @param photoUrl: Optional photo of the garbage (upload separately)
  /// @param authToken: User's authentication token
  /// 
  /// Returns the created report ID if successful
  static Future<String> reportGarbagePileUp({
    required Position position,
    required String description,
    required String estimatedVolume,
    String? photoUrl,
    required String authToken,
  }) async {
    try {
      // Prepare the request payload
      final Map<String, dynamic> reportData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'address_description': description,
        'estimated_volume': estimatedVolume,
        'garbage_type': 'mixed', // Default, can be made selectable
        'photo_url': photoUrl,
      };
      
      debugPrint('📤 Sending garbage report to backend...');
      
      // Send POST request to backend
      final response = await http.post(
        Uri.parse('$API_BASE_URL/garbage-reports'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(reportData),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final reportId = responseData['report_id'];
        
        debugPrint('✅ Garbage report created: $reportId');
        return reportId;
        
      } else {
        debugPrint('❌ Backend error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to create report: ${response.body}');
      }
      
    } catch (e) {
      debugPrint('❌ Error reporting garbage: $e');
      rethrow;
    }
  }
  
  /// Update collector's current location (for collectors only)
  /// 
  /// Collectors should call this periodically to update their position
  /// so the backend can assign nearby garbage reports
  /// 
  /// @param position: Collector's current GPS position
  /// @param authToken: Collector's authentication token
  static Future<void> updateCollectorLocation({
    required Position position,
    required String authToken,
  }) async {
    try {
      final Map<String, dynamic> locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await http.patch(
        Uri.parse('$API_BASE_URL/collectors/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(locationData),
      );
      
      if (response.statusCode == 200) {
        debugPrint('✅ Collector location updated');
      } else {
        debugPrint('⚠️ Failed to update location: ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('❌ Error updating collector location: $e');
      // Don't throw - this is a background update
    }
  }
  
  /// Convert Position to LatLng for Google Maps
  static LatLng positionToLatLng(Position position) {
    return LatLng(position.latitude, position.longitude);
  }
}

// ============================================
// EXAMPLE USAGE IN A FLUTTER WIDGET
// ============================================

/// Example widget showing how to use LocationService
/// to report garbage pile-ups
class ReportGarbageScreen extends StatefulWidget {
  const ReportGarbageScreen({super.key});
  
  @override
  State<ReportGarbageScreen> createState() => _ReportGarbageScreenState();
}

class _ReportGarbageScreenState extends State<ReportGarbageScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedVolume = 'medium';
  
  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }
  
  /// Load user's current location and display on map
  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      final position = await LocationService.getCurrentLocation();
      
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
      
      // Move camera to user's location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LocationService.positionToLatLng(position),
            15.0, // Zoom level (15 is good for neighborhood view)
          ),
        );
      }
      
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Submit the garbage report
  Future<void> _submitReport() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for location to load')),
      );
      return;
    }
    
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the garbage location')),
      );
      return;
    }
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      // Get auth token (from your auth service)
      const authToken = 'your-auth-token'; // TODO: Get from AuthService
      
      // Submit report
      final reportId = await LocationService.reportGarbagePileUp(
        position: _currentPosition!,
        description: _descriptionController.text,
        estimatedVolume: _selectedVolume,
        authToken: authToken,
      );
      
      // Hide loading
      if (mounted) Navigator.pop(context);
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Garbage report submitted! Proceed to payment.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Navigate to payment screen
        // Navigator.push(context, MaterialPageRoute(
        //   builder: (context) => PaymentScreen(reportId: reportId),
        // ));
      }
      
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.pop(context);
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Garbage Pile-Up'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          // Google Map showing user's location
          Expanded(
            flex: 2,
            child: _isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition != null
                          ? LocationService.positionToLatLng(_currentPosition!)
                          : const LatLng(0.3476, 32.6169), // Default: Nakawa, Kampala
                      zoom: 15.0,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: _currentPosition != null
                        ? {
                            Marker(
                              markerId: const MarkerId('garbage_location'),
                              position: LocationService.positionToLatLng(_currentPosition!),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                BitmapDescriptor.hueRed,
                              ),
                              infoWindow: const InfoWindow(
                                title: 'Garbage Location',
                                snippet: 'Tap submit to report',
                              ),
                            ),
                          }
                        : {},
                  ),
          ),
          
          // Report details form
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Description field
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Location Description',
                      hintText: 'e.g., Near Nakawa Market, behind MTN shop',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  
                  // Volume selection
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVolume,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Volume',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'small', child: Text('Small (1 bag)')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium (2-5 bags)')),
                      DropdownMenuItem(value: 'large', child: Text('Large (6+ bags)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedVolume = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Submit button
                  ElevatedButton(
                    onPressed: _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Submit Report (UGX 5,000)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}

// ============================================
// PUBSPEC.YAML DEPENDENCIES
// ============================================
/*
Add these to your pubspec.yaml:

dependencies:
  flutter:
    sdk: flutter
  
  # Location services
  geolocator: ^10.1.0
  permission_handler: ^11.0.1
  
  # Maps
  google_maps_flutter: ^2.5.0
  
  # HTTP requests
  http: ^1.1.0
  
  # Optional: For image upload
  image_picker: ^1.0.4

# Android configuration (android/app/src/main/AndroidManifest.xml):
# Add these permissions:

<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />

# Add Google Maps API key:
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>

# iOS configuration (ios/Runner/Info.plist):
# Add these keys:

<key>NSLocationWhenInUseUsageDescription</key>
<string>GFC needs your location to report garbage pile-ups in your area</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>GFC needs your location to optimize collector routes</string>

# Add Google Maps API key in ios/Runner/AppDelegate.swift:
import GoogleMaps

GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
*/

// ============================================
// KAMPALA-SPECIFIC LOCATION NOTES
// ============================================
/*
KAMPALA DIVISIONS & TYPICAL COORDINATES:
- Central Division: 0.3163° N, 32.5822° E
- Kawempe: 0.3683° N, 32.5594° E
- Makindye: 0.2889° N, 32.6014° E
- Nakawa: 0.3476° N, 32.6169° E
- Rubaga: 0.3050° N, 32.5500° E

NETWORK CONSIDERATIONS:
- Uganda has good 3G/4G coverage in Kampala
- MTN and Airtel are main providers
- GPS typically works well in urban areas
- Consider offline maps for areas with poor connectivity

CULTURAL CONTEXT:
- Use simple, clear language (many users speak Luganda)
- Show prices in UGX (Ugandan Shillings)
- Mobile Money is the primary payment method
- SMS notifications are important (not everyone has data)
*/
