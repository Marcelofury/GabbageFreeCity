library;

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class CollectorProvider with ChangeNotifier {
  final _apiService = ApiService();

  List<Map<String, dynamic>> _nearbyReports = [];
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get nearbyReports => _nearbyReports;
  List<Map<String, dynamic>> get assignments => _assignments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchNearbyReports({
    required double latitude,
    required double longitude,
    int radius = 5000,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getNearbyReports(
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      if (response['success'] == true) {
        final reports = (response['data']?['reports'] as List?) ?? [];
        _nearbyReports = reports
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
      } else {
        _error = response['message']?.toString() ?? 'Failed to load nearby reports';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> acceptAssignment(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.assignReport(reportId);
      _isLoading = false;

      if (response['success'] == true) {
        notifyListeners();
        return true;
      }

      _error = response['message']?.toString() ?? 'Failed to accept assignment';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchMyAssignments() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getMyAssignments();

      if (response['success'] == true) {
        final reports = (response['data']?['reports'] as List?) ?? [];
        _assignments = reports
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
      } else {
        _error = response['message']?.toString() ?? 'Failed to load assignments';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateAssignmentStatus({
    required String reportId,
    required String status,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateReportStatus(
        reportId: reportId,
        status: status,
      );
      _isLoading = false;

      if (response['success'] == true) {
        notifyListeners();
        return true;
      }

      _error = response['message']?.toString() ?? 'Failed to update status';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic>? findAssignmentById(String id) {
    try {
      return _assignments.firstWhere((a) => a['id']?.toString() == id);
    } catch (_) {
      return null;
    }
  }
}
