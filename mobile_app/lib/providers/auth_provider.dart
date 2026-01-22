/// Authentication Provider
/// Manages user authentication state
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _apiService = ApiService();
  
  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && _token != null;
  bool get isResident => _user?.isResident ?? false;
  bool get isCollector => _user?.isCollector ?? false;

  /// Initialize and check if user is already logged in
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _token = await _storage.read(key: 'auth_token');
      final userJson = await _storage.read(key: 'user_data');
      
      if (_token != null && userJson != null) {
        // Will implement proper user restoration later
        // For now, just clear if corrupted
        _token = null;
        await _storage.delete(key: 'auth_token');
        await _storage.delete(key: 'user_data');
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      _token = null;
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Register a new user
  Future<bool> register({
    required String phoneNumber,
    required String fullName,
    required String userType,
    String? email,
    String? area,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('Attempting to register with: $phoneNumber');
      final response = await _apiService.register(
        phoneNumber: phoneNumber,
        fullName: fullName,
        userType: userType,
        email: email,
        area: area,
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint('Registration response: $response');

      if (response['success']) {
        _user = User.fromJson(response['data']['user']);
        _token = response['data']['token'];
        
        // Save to secure storage
        await _storage.write(key: 'auth_token', value: _token);
        await _storage.write(key: 'user_data', value: _user.toString());
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login user
  Future<bool> login(String phoneNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(phoneNumber);

      if (response['success']) {
        _user = User.fromJson(response['data']['user']);
        _token = response['data']['token'];
        
        // Save to secure storage
        await _storage.write(key: 'auth_token', value: _token);
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'];
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    _user = null;
    _token = null;
    
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    
    notifyListeners();
  }
}
