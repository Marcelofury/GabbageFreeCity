/**
 * Report Provider
 * Manages garbage reports state
 */

import 'package:flutter/foundation.dart';
import '../models/garbage_report.dart';
import '../services/api_service.dart';

class ReportProvider with ChangeNotifier {
  final _apiService = ApiService();
  
  List<GarbageReport> _reports = [];
  bool _isLoading = false;
  String? _error;

  List<GarbageReport> get reports => _reports;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Create a new garbage report
  Future<String?> createReport({
    required double latitude,
    required double longitude,
    required String addressDescription,
    required String estimatedVolume,
    String garbageType = 'mixed',
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.createGarbageReport(
        latitude: latitude,
        longitude: longitude,
        addressDescription: addressDescription,
        estimatedVolume: estimatedVolume,
        garbageType: garbageType,
        photoUrl: photoUrl,
      );

      _isLoading = false;
      
      if (response['success']) {
        notifyListeners();
        return response['data']['report_id'];
      } else {
        _error = response['message'];
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Fetch user's reports
  Future<void> fetchMyReports() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getMyReports();

      if (response['success']) {
        _reports = (response['data']['reports'] as List)
            .map((json) => GarbageReport.fromJson(json))
            .toList();
      } else {
        _error = response['message'];
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
