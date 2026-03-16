library;

import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class NotificationProvider with ChangeNotifier {
  final _apiService = ApiService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications({int limit = 50, int offset = 0}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getNotifications(limit: limit, offset: offset);
      if (response['success'] == true) {
        final list = (response['data']?['notifications'] as List?) ?? [];
        _notifications = list
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
        final unread = response['data']?['unread_count'];
        _unreadCount = unread is int ? unread : int.tryParse(unread?.toString() ?? '0') ?? 0;
      } else {
        _error = response['message']?.toString() ?? 'Failed to load notifications';
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> markAsRead(String id) async {
    try {
      final response = await _apiService.markNotificationAsRead(id);
      if (response['success'] == true) {
        final index = _notifications.indexWhere((n) => n['id']?.toString() == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          _unreadCount = _notifications.where((n) => n['is_read'] != true).length;
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.markAllNotificationsAsRead();
      if (response['success'] == true) {
        for (final notification in _notifications) {
          notification['is_read'] = true;
        }
        _unreadCount = 0;
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
