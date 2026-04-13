/// User Model
library;

class User {
  final String id;
  final String username;
  final String phoneNumber;
  final String fullName;
  final String userType; // 'resident', 'collector', or 'admin'
  final String? email;
  final String? area;
  final bool isActive;

  User({
    required this.id,
    required this.username,
    required this.phoneNumber,
    required this.fullName,
    required this.userType,
    this.email,
    this.area,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? '',
      phoneNumber: json['phone_number'],
      fullName: json['full_name'],
      userType: json['user_type'],
      email: json['email'],
      area: json['area'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'phone_number': phoneNumber,
      'full_name': fullName,
      'user_type': userType,
      'email': email,
      'area': area,
      'is_active': isActive,
    };
  }

  bool get isResident => userType == 'resident';
  bool get isCollector => userType == 'collector';
  bool get isAdmin => userType == 'admin';
}
