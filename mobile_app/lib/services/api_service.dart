/// API Service
/// Handles all HTTP requests to the backend
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

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
    required String username,
    required String password,
    required String phoneNumber,
    required String fullName,
    required String userType,
    String? email,
    String? area,
    double? latitude,
    double? longitude,
  }) async {
    try {
      debugPrint('Connecting to: $BASE_URL/auth/register');
      
      final response = await http.post(
        Uri.parse('$BASE_URL/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'phone_number': phoneNumber,
          'full_name': fullName,
          'user_type': userType,
          'email': email,
          'area': area,
          'latitude': latitude,
          'longitude': longitude,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Connection timeout - check internet connection');
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      debugPrint('Registration network error: $e');
      return {
        'success': false,
        'message': 'Cannot connect to server. Check your internet connection and try again.',
      };
    }
  }

  /// Login user
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Set or reset password for existing account
  Future<Map<String, dynamic>> setPassword({
    required String username,
    required String phoneNumber,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$BASE_URL/auth/set-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'phone_number': phoneNumber,
        'new_password': newPassword,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Create garbage report
  Future<Map<String, dynamic>> createGarbageReport({
    required double latitude,
    required double longitude,
    required String addressDescription,
    required int packageCount,
    String garbageType = 'mixed',
    String? photoUrl,
  }) async {
    final headers = await _getHeaders();
    
    // Build request body, only include photo_url if not null
    final Map<String, dynamic> requestBody = {
      'latitude': latitude,
      'longitude': longitude,
      'address_description': addressDescription,
      'package_count': packageCount,
      'garbage_type': garbageType,
    };
    
    // Only add photo_url if it's not null (backend expects string or omitted)
    if (photoUrl != null && photoUrl.isNotEmpty) {
      requestBody['photo_url'] = photoUrl;
    }
    
    final response = await http.post(
      Uri.parse('$BASE_URL/garbage-reports'),
      headers: headers,
      body: jsonEncode(requestBody),
    );

    return jsonDecode(response.body);
  }

  /// Get user's reports
  Future<Map<String, dynamic>> getMyReports() async {
    try {
      final headers = await _getHeaders();
      debugPrint('🔍 Fetching reports from: $BASE_URL/garbage-reports/my-reports');
      
      final response = await http.get(
        Uri.parse('$BASE_URL/garbage-reports/my-reports'),
        headers: headers,
      );

      debugPrint('📡 Reports API status: ${response.statusCode}');
      debugPrint('📡 Reports API response: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch reports: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ getMyReports error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Initiate payment
  Future<Map<String, dynamic>> initiatePayment({
    required String orderId,
    required String phone,
    String method = 'marzpay',
  }) async {
    final headers = await _getHeaders();
    
    final response = await http.post(
      Uri.parse('$BASE_URL/payments/initiate'),
      headers: headers,
      body: jsonEncode({
        'orderId': orderId,
        'method': method,
        'phone': phone,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Synchronize payment status with provider and update backend records
  Future<Map<String, dynamic>> syncPaymentStatus({
    required String transactionRef,
    String? reportId,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$BASE_URL/payments/sync-status'),
        headers: headers,
        body: jsonEncode({
          'transaction_ref': transactionRef,
          if (reportId != null) 'report_id': reportId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Validate Uganda mobile money phone for MarzPay
  Future<Map<String, dynamic>> validatePaymentPhone({
    required String phone,
  }) async {
    final headers = await _getHeaders();

    final response = await http.post(
      Uri.parse('$BASE_URL/payments/validate-phone'),
      headers: headers,
      body: jsonEncode({
        'phone': phone,
      }),
    );

    return jsonDecode(response.body);
  }

  /// Get subscription plans
  Future<Map<String, dynamic>> getSubscriptionPlans() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/subscriptions/plans'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get active subscription for resident
  Future<Map<String, dynamic>> getMySubscription() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/subscriptions/my'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Purchase subscription (3 months prepaid)
  Future<Map<String, dynamic>> purchaseSubscription({
    required String planId,
    required String phone,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$BASE_URL/subscriptions/purchase'),
        headers: headers,
        body: jsonEncode({
          'plan_id': planId,
          'phone': phone,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get nearby reports (for collectors)
  Future<Map<String, dynamic>> getNearbyReports({
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$BASE_URL/garbage-reports/nearby?latitude=$latitude&longitude=$longitude&radius=$radius'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {
        'success': false,
        'message': 'Failed to fetch nearby reports: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Assign collector to a report
  Future<Map<String, dynamic>> assignReport(String reportId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.patch(
        Uri.parse('$BASE_URL/garbage-reports/$reportId/assign'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Update report status
  Future<Map<String, dynamic>> updateReportStatus({
    required String reportId,
    required String status,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.patch(
        Uri.parse('$BASE_URL/garbage-reports/$reportId/status'),
        headers: headers,
        body: jsonEncode({'status': status}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get collector assignments
  Future<Map<String, dynamic>> getMyAssignments() async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$BASE_URL/collectors/my-assignments'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {
        'success': false,
        'message': 'Failed to fetch assignments: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get collector completed collection history
  Future<Map<String, dynamic>> getCollectionHistory({
    String period = 'week',
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$BASE_URL/collectors/collection-history?period=$period'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {
        'success': false,
        'message': 'Failed to fetch collection history: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get resident completed collection history
  Future<Map<String, dynamic>> getResidentCollectionHistory({
    String period = 'month',
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$BASE_URL/garbage-reports/my-collections?period=$period'),
        headers: headers,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {
        'success': false,
        'message': 'Failed to fetch resident collections: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
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

  /// Verify collection from collector QR scan
  Future<Map<String, dynamic>> verifyCollection({
    required String reportId,
    required double latitude,
    required double longitude,
    required String qrCodeData,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.post(
        Uri.parse('$BASE_URL/collectors/verify-collection'),
        headers: headers,
        body: jsonEncode({
          'report_id': reportId,
          'latitude': latitude,
          'longitude': longitude,
          'qr_code_data': qrCodeData,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get collector profile and live stats
  Future<Map<String, dynamic>> getCollectorProfile() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/collectors/profile'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Update collector profile/settings
  Future<Map<String, dynamic>> updateCollectorProfile({
    String? fullName,
    String? area,
    bool? isActive,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        if (fullName != null) 'full_name': fullName,
        if (area != null) 'area': area,
        if (isActive != null) 'is_active': isActive,
      };

      final response = await http.patch(
        Uri.parse('$BASE_URL/collectors/profile'),
        headers: headers,
        body: jsonEncode(body),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get notifications for authenticated user
  Future<Map<String, dynamic>> getNotifications({int limit = 50, int offset = 0}) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$BASE_URL/notifications?limit=$limit&offset=$offset'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Mark one notification as read
  Future<Map<String, dynamic>> markNotificationAsRead(String id) async {
    try {
      final headers = await _getHeaders();

      final response = await http.patch(
        Uri.parse('$BASE_URL/notifications/$id/read'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Mark all notifications as read
  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      final headers = await _getHeaders();

      final response = await http.patch(
        Uri.parse('$BASE_URL/notifications/read-all'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get admin dashboard metrics
  Future<Map<String, dynamic>> getAdminDashboard() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/admin/dashboard'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get admin collection history with proof details
  Future<Map<String, dynamic>> getAdminCollections({
    String period = 'month',
    String? collectorId,
    String? area,
    bool? outOfSchedule,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'period': period,
        if (collectorId != null && collectorId.isNotEmpty) 'collector_id': collectorId,
        if (area != null && area.isNotEmpty) 'area': area,
        if (outOfSchedule != null) 'out_of_schedule': outOfSchedule.toString(),
      };

      final uri = Uri.parse('$BASE_URL/admin/collections').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get central MarzPay wallet balance for admin
  Future<Map<String, dynamic>> getAdminWalletBalance() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/payments/wallet-balance'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get recent MarzPay transactions for admin
  Future<Map<String, dynamic>> getAdminMarzpayTransactions() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$BASE_URL/payments/marzpay-transactions'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Get collectors for admin management
  Future<Map<String, dynamic>> getAdminCollectors({
    String search = '',
    String status = 'all',
  }) async {
    try {
      final headers = await _getHeaders();
      final query = Uri(queryParameters: {
        if (search.isNotEmpty) 'search': search,
        'status': status,
      }).query;

      final response = await http.get(
        Uri.parse('$BASE_URL/admin/collectors?$query'),
        headers: headers,
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  /// Activate/deactivate collector
  Future<Map<String, dynamic>> updateCollectorActiveStatus({
    required String collectorId,
    required bool isActive,
  }) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('$BASE_URL/admin/collectors/$collectorId/status'),
        headers: headers,
        body: jsonEncode({'is_active': isActive}),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }
}
