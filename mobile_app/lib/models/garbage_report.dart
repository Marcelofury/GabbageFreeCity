/// Garbage Report Model
library;

class GarbageReport {
  final String id;
  final String residentId;
  final double latitude;
  final double longitude;
  final String addressDescription;
  final String garbageType;
  final String estimatedVolume;
  final String? photoUrl;
  final String status;
  final bool paymentRequired;
  final double paymentAmount;
  final String? assignedCollectorId;
  final DateTime reportedAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;

  GarbageReport({
    required this.id,
    required this.residentId,
    required this.latitude,
    required this.longitude,
    required this.addressDescription,
    required this.garbageType,
    required this.estimatedVolume,
    this.photoUrl,
    required this.status,
    required this.paymentRequired,
    required this.paymentAmount,
    this.assignedCollectorId,
    required this.reportedAt,
    this.assignedAt,
    this.completedAt,
  });

  factory GarbageReport.fromJson(Map<String, dynamic> json) {
    // Extract latitude and longitude - handle both direct fields and PostGIS location
    double? latitude;
    double? longitude;
    
    // Check if lat/lng are provided as separate fields
    if (json['latitude'] != null && json['longitude'] != null) {
      latitude = (json['latitude'] is num) ? json['latitude'].toDouble() : null;
      longitude = (json['longitude'] is num) ? json['longitude'].toDouble() : null;
    } else if (json['location'] != null) {
      // Try to extract from PostGIS format
      try {
        latitude = _extractLatitude(json['location']);
        longitude = _extractLongitude(json['location']);
      } catch (e) {
        // If extraction fails, use default coordinates (Kampala center)
        latitude = 0.3476;
        longitude = 32.5825;
      }
    }
    
    return GarbageReport(
      id: json['id'],
      residentId: json['resident_id'],
      latitude: latitude ?? 0.3476,
      longitude: longitude ?? 32.5825,
      addressDescription: json['address_description'] ?? 'Unknown location',
      garbageType: json['garbage_type'] ?? 'mixed',
      estimatedVolume: json['estimated_volume'] ?? 'medium',
      photoUrl: json['photo_url'],
      status: json['status'] ?? 'pending',
      paymentRequired: json['payment_required'] ?? true,
      paymentAmount: (json['payment_amount'] ?? 5000).toDouble(),
      assignedCollectorId: json['assigned_collector_id'],
      reportedAt: DateTime.parse(json['reported_at']),
      assignedAt: json['assigned_at'] != null 
          ? DateTime.parse(json['assigned_at']) 
          : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
    );
  }

  static double? _extractLatitude(dynamic location) {
    // Handle PostGIS point format or direct values
    if (location is String) {
      try {
        // Parse "POINT(lng lat)" format
        final coords = location.replaceAll(RegExp(r'[POINT()]'), '').split(' ');
        if (coords.length >= 2) {
          return double.tryParse(coords[1]);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  static double? _extractLongitude(dynamic location) {
    if (location is String) {
      try {
        final coords = location.replaceAll(RegExp(r'[POINT()]'), '').split(' ');
        if (coords.length >= 2) {
          return double.tryParse(coords[0]);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Payment';
      case 'assigned':
        return 'Collector Assigned';
      case 'in_progress':
        return 'Collection in Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
