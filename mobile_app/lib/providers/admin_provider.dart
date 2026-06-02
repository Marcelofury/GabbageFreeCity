library;

import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class AdminProvider with ChangeNotifier {
  final _apiService = ApiService();

  bool _isLoading = false;
  String? _error;
  String _statusFilter = 'all';
  String _collectionPeriod = 'month';

  List<Map<String, dynamic>> _collectors = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _collections = [];
  Map<String, dynamic> _wallet = {};
  Map<String, dynamic> _dashboard = {
    'active_collectors': 0,
    'inactive_collectors': 0,
    'open_assignments': 0,
    'collections_today': 0,
    'reports_made': 0,
    'reports_pending': 0,
    'reports_accepted': 0,
    'reports_completed': 0,
    'analytics': <String, dynamic>{
      'paid_transactions': 0,
      'successful_transactions': 0,
      'pending_payments': 0,
      'failed_payments': 0,
      'total_revenue_ugx': 0,
      'completion_rate_percent': 0,
      'average_completion_minutes': 0,
    },
  };

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get statusFilter => _statusFilter;
  String get collectionPeriod => _collectionPeriod;
  List<Map<String, dynamic>> get collectors => _collectors;
  List<Map<String, dynamic>> get transactions => _transactions;
  List<Map<String, dynamic>> get collections => _collections;
  Map<String, dynamic> get wallet => _wallet;
  Map<String, dynamic> get dashboard => _dashboard;

  Future<void> fetchDashboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final responses = await Future.wait([
        _apiService.getAdminDashboard(),
        _apiService.getAdminWalletBalance(),
        _apiService.getAdminMarzpayTransactions(),
      ]);

      final dashboardResponse = responses[0];
      final walletResponse = responses[1];
      final transactionsResponse = responses[2];

      if (dashboardResponse['success'] == true) {
        _dashboard = Map<String, dynamic>.from(dashboardResponse['data'] ?? {});
      } else {
        _error = dashboardResponse['message']?.toString() ?? 'Failed to fetch dashboard';
      }

      if (walletResponse['success'] == true) {
        _wallet = Map<String, dynamic>.from(walletResponse['data'] ?? {});
      }

      if (transactionsResponse['success'] == true) {
        final rawData = transactionsResponse['data'];
        final rows = rawData is List
          ? rawData
          : (rawData is Map<String, dynamic>
            ? (rawData['transactions'] as List?) ?? []
            : []);
        _transactions = rows
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
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

  Future<void> fetchCollections({
    String? period,
    String? collectorId,
    String? area,
    bool? outOfSchedule,
  }) async {
    _isLoading = true;
    _error = null;
    if (period != null) {
      _collectionPeriod = period;
    }
    notifyListeners();

    try {
      final response = await _apiService.getAdminCollections(
        period: _collectionPeriod,
        collectorId: collectorId,
        area: area,
        outOfSchedule: outOfSchedule,
      );

      if (response['success'] == true) {
        final rows = (response['data']?['reports'] as List?) ?? [];
        _collections = rows
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
      } else {
        _error = response['message']?.toString() ?? 'Failed to load collections';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
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
