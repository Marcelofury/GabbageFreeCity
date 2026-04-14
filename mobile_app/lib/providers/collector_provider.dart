library;

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class CollectorProvider with ChangeNotifier {
  final _apiService = ApiService();

  List<Map<String, dynamic>> _nearbyReports = [];
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _collectionHistory = [];
  String _historyPeriod = 'week';
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get nearbyReports => _nearbyReports;
  List<Map<String, dynamic>> get assignments => _assignments;
  List<Map<String, dynamic>> get collectionHistory => _collectionHistory;
  String get historyPeriod => _historyPeriod;
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

  Future<void> updateCollectorLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _apiService.updateCollectorLocation(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      // Ignore location sync failures to keep nearby UX responsive.
    }
  }

  Future<bool> acceptAssignment(String reportId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.assignReport(reportId);
      _isLoading = false;

      if (response['success'] == true) {
        final assignedReport = response['data']?['report'];
        if (assignedReport is Map<String, dynamic>) {
          final normalized = Map<String, dynamic>.from(assignedReport);
          _assignments = [
            normalized,
            ..._assignments.where((item) => item['id']?.toString() != normalized['id']?.toString()),
          ];
          _nearbyReports = _nearbyReports
              .where((item) => item['id']?.toString() != normalized['id']?.toString())
              .toList();
        }

        // Pull latest server truth so My Assignments always reflects accepted jobs.
        await fetchMyAssignments();
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

  Future<void> fetchCollectionHistory({String? period}) async {
    _isLoading = true;
    _error = null;
    if (period != null) {
      _historyPeriod = period;
    }
    notifyListeners();

    try {
      final response = await _apiService.getCollectionHistory(
        period: _historyPeriod,
      );

      if (response['success'] == true) {
        final reports = (response['data']?['reports'] as List?) ?? [];
        _collectionHistory = reports
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
      } else {
        _error = response['message']?.toString() ?? 'Failed to load collection history';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setHistoryPeriod(String period) async {
    if (period == _historyPeriod) {
      return;
    }

    await fetchCollectionHistory(period: period);
  }
}
