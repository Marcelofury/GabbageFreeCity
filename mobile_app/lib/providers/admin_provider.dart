library;

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class AdminProvider with ChangeNotifier {
  final _apiService = ApiService();

  bool _isLoading = false;
  String? _error;
  String _statusFilter = 'all';

  List<Map<String, dynamic>> _collectors = [];
  Map<String, dynamic> _dashboard = {
    'active_collectors': 0,
    'inactive_collectors': 0,
    'open_assignments': 0,
    'collections_today': 0,
  };

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  List<Map<String, dynamic>> get collectors => _collectors;
  Map<String, dynamic> get dashboard => _dashboard;

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getAdminDashboard();
      if (response['success'] == true) {
        _dashboard = Map<String, dynamic>.from(response['data'] ?? {});
      } else {
        _error = response['message']?.toString() ?? 'Failed to fetch dashboard';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCollectors({String search = ''}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getAdminCollectors(
        search: search,
        status: _statusFilter,
      );

      if (response['success'] == true) {
        final rows = (response['data']?['collectors'] as List?) ?? [];
        _collectors = rows
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
      } else {
        _error = response['message']?.toString() ?? 'Failed to fetch collectors';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setStatusFilter(String filter) async {
    _statusFilter = filter;
    await fetchCollectors();
  }

  Future<bool> updateCollectorStatus({
    required String collectorId,
    required bool isActive,
  }) async {
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.updateCollectorActiveStatus(
        collectorId: collectorId,
        isActive: isActive,
      );

      if (response['success'] == true) {
        _collectors = _collectors.map((collector) {
          if (collector['id']?.toString() == collectorId) {
            return {
              ...collector,
              'is_active': isActive,
            };
          }
          return collector;
        }).toList();

        notifyListeners();
        await fetchDashboard();
        return true;
      }

      _error = response['message']?.toString() ?? 'Failed to update collector';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
