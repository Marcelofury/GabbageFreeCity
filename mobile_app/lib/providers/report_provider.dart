/// Report Provider
/// Manages garbage reports state
library;

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

  GarbageReport? findReportById(String id) {
    try {
      return _reports.firstWhere((report) => report.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Create a new garbage report
  Future<String?> createReport({
    required double latitude,
    required double longitude,
    required String addressDescription,
    required int packageCount,
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
        packageCount: packageCount,
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
      debugPrint('📋 Fetching user reports...');
      final response = await _apiService.getMyReports();
      debugPrint('📋 Reports response: ${response['success']}');

      if (response['success']) {
        final reportsList = response['data']['reports'] as List;
        debugPrint('📋 Found ${reportsList.length} reports');
        _reports = reportsList
            .map((json) => GarbageReport.fromJson(json))
            .toList();
        _error = null;
      } else {
        _error = response['message'] ?? 'Failed to load reports';
        debugPrint('❌ Reports error: $_error');
      }
    } catch (e) {
      _error = 'Failed to load reports: ${e.toString()}';
      debugPrint('❌ Reports exception: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
