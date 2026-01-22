/// API Service
/// Handles all HTTP requests to the backend
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Backend deployed on Render
  static const String BASE_URL = 'https://gabbagefreecity.onrender.com/api';
  
  final _storage = const FlutterSecureStorage();

  /// Get authorization headers
  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'auth_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String fullName,
    required String userType,
    String? email,
    String? area,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phoneNumber,
        'full_name': fullName,
        'user_type': userType,
        'email': email,
        'area': area,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Login user
  Future<Map<String, dynamic>> login(String phoneNumber) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phoneNumber}),
    );

    return jsonDecode(response.body);
  }

  /// Create garbage report
  Future<Map<String, dynamic>> createGarbageReport({
    required double latitude,
    required double longitude,
    required String addressDescription,
    required String estimatedVolume,
    String garbageType = 'mixed',
    String? photoUrl,
  }) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$BASE_URL/garbage-reports'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'address_description': addressDescription,
        'estimated_volume': estimatedVolume,
        'garbage_type': garbageType,
        'photo_url': photoUrl,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Get user's reports
  Future<Map<String, dynamic>> getMyReports() async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$BASE_URL/garbage-reports/my-reports'),
      headers: headers,
    );

    return jsonDecode(response.body);
  }

  /// Initiate payment
  Future<Map<String, dynamic>> initiatePayment({
    required String reportId,
    required String phoneNumber,
    required double amount,
  }) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$BASE_URL/payments/initiate'),
      headers: headers,
      body: jsonEncode({
        'report_id': reportId,
        'phone_number': phoneNumber,
        'amount': amount,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Get nearby reports (for collectors)
  Future<Map<String, dynamic>> getNearbyReports({
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    final headers = await _getHeaders();
    
    final response = await http.get(
      Uri.parse('$BASE_URL/garbage-reports/nearby?latitude=$latitude&longitude=$longitude&radius=$radius'),
      headers: headers,
    );

    return jsonDecode(response.body);
  }

  /// Update collector location
  Future<Map<String, dynamic>> updateCollectorLocation({
    required double latitude,
    required double longitude,
  }) async {
    final headers = await _getHeaders();
    
    final response = await http.patch(
      Uri.parse('$BASE_URL/collectors/location'),
      headers: headers,
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
      }),
    );

    return jsonDecode(response.body);
  }
}
