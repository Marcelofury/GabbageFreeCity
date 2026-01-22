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
    return GarbageReport(
      id: json['id'],
      residentId: json['resident_id'],
      latitude: _extractLatitude(json['location']),
      longitude: _extractLongitude(json['location']),
      addressDescription: json['address_description'],
      garbageType: json['garbage_type'],
      estimatedVolume: json['estimated_volume'],
      photoUrl: json['photo_url'],
      status: json['status'],
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

  static double _extractLatitude(dynamic location) {
    // Handle PostGIS point format or direct values
    if (location is String) {
      // Parse "POINT(lng lat)" format
      final coords = location.replaceAll(RegExp(r'[POINT()]'), '').split(' ');
      return double.parse(coords[1]);
    }
    return 0.0;
  }

  static double _extractLongitude(dynamic location) {
    if (location is String) {
      final coords = location.replaceAll(RegExp(r'[POINT()]'), '').split(' ');
      return double.parse(coords[0]);
    }
    return 0.0;
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
