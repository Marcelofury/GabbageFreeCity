/// Garbage Report Model
library;

class GarbageReport {
  final String id;
  final String residentId;
  final double latitude;
  final double longitude;
  final String addressDescription;
  final String garbageType;
  final int packageCount;
  final String estimatedVolume;
  final String? photoUrl;
  final String status;
  final bool paymentRequired;
  final double paymentAmount;
  final String paymentStatus;
  final String? transactionRef;
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
    required this.packageCount,
    required this.estimatedVolume,
    this.photoUrl,
    required this.status,
    required this.paymentRequired,
    required this.paymentAmount,
    required this.paymentStatus,
    this.transactionRef,
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
      packageCount: _parsePackageCount(json['package_count'], json['estimated_volume']),
      estimatedVolume: _estimatedVolumeLabel(_parsePackageCount(json['package_count'], json['estimated_volume'])),
      photoUrl: json['photo_url'],
      status: json['status'] ?? 'pending',
      paymentRequired: json['payment_required'] ?? true,
      paymentAmount: _parseAmount(json['payment_amount']),
      paymentStatus: _parsePaymentStatus(json),
      transactionRef: _parseTransactionRef(json),
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

  static String _parsePaymentStatus(Map<String, dynamic> json) {
    final payments = json['payments'];
    if (payments is List && payments.isNotEmpty) {
      final statuses = payments
          .whereType<Map<String, dynamic>>()
          .map((p) => (p['payment_status'] ?? '').toString().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      if (statuses.any((s) => s == 'successful' || s == 'completed' || s == 'paid')) {
        return 'successful';
      }

      if (statuses.any((s) => s == 'processing')) {
        return 'processing';
      }

      if (statuses.any((s) => s == 'pending')) {
        return 'pending';
      }

      if (statuses.any((s) => s == 'failed' || s == 'cancelled')) {
        return 'failed';
      }
    }

    final directStatus = (json['payment_status'] ?? '').toString();
    if (directStatus.isNotEmpty) {
      return directStatus;
    }

    return 'pending';
  }

  static String? _parseTransactionRef(Map<String, dynamic> json) {
    final payments = json['payments'];
    if (payments is List && payments.isNotEmpty) {
      final rows = payments.whereType<Map<String, dynamic>>().toList();

      final successful = rows.firstWhere(
        (p) {
          final status = (p['payment_status'] ?? '').toString().toLowerCase();
          return status == 'successful' || status == 'completed' || status == 'paid';
        },
        orElse: () => <String, dynamic>{},
      );

      if (successful.isNotEmpty) {
        return successful['transaction_id']?.toString();
      }

      final withTx = rows.firstWhere(
        (p) => (p['transaction_id'] ?? '').toString().isNotEmpty,
        orElse: () => <String, dynamic>{},
      );

      if (withTx.isNotEmpty) {
        return withTx['transaction_id']?.toString();
      }
    }

    return null;
  }

  static int _parsePackageCount(dynamic packageCountRaw, dynamic estimatedVolumeRaw) {
    if (packageCountRaw is num && packageCountRaw >= 1) {
      return packageCountRaw.toInt();
    }

    final parsedDirect = int.tryParse(packageCountRaw?.toString() ?? '');
    if (parsedDirect != null && parsedDirect >= 1) {
      return parsedDirect;
    }

    final estimatedText = (estimatedVolumeRaw ?? '').toString().toLowerCase();
    final extracted = RegExp(r'(\d+)').firstMatch(estimatedText)?.group(1);
    final parsedExtracted = int.tryParse(extracted ?? '');
    if (parsedExtracted != null && parsedExtracted >= 1) {
      return parsedExtracted;
    }

    return 1;
  }

  static String _estimatedVolumeLabel(int packages) {
    return '$packages package${packages == 1 ? '' : 's'}';
  }

  static double _parseAmount(dynamic amountRaw) {
    if (amountRaw is num) {
      return amountRaw.toDouble();
    }
    return double.tryParse(amountRaw?.toString() ?? '') ?? 5000;
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
        final normalizedPayment = paymentStatus.toLowerCase();
        if (normalizedPayment == 'successful' || normalizedPayment == 'completed' || normalizedPayment == 'paid' || normalizedPayment == 'success') {
          return 'Waiting Collector Assignment';
        }
        if (normalizedPayment == 'processing' || normalizedPayment == 'initiated') {
          return 'Payment Processing';
        }
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
