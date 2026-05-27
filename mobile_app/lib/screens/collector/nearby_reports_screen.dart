import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/collector_provider.dart';
import '../../providers/location_provider.dart';

class NearbyReportsScreen extends StatefulWidget {
  const NearbyReportsScreen({super.key});

  @override
  State<NearbyReportsScreen> createState() => _NearbyReportsScreenState();
}

class _NearbyReportsScreenState extends State<NearbyReportsScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  bool _isLoading = false;
  StreamSubscription<Position>? _locationSubscription;
  DateTime? _lastLiveRefreshAt;
  Position? _lastLivePosition;

  @override
  void initState() {
    super.initState();
    _loadNearbyReports();
    _startLiveLocationTracking();
  }

  String _reportStatus(Map<String, dynamic> report) {
    return (report['status'] ?? '').toString().toLowerCase().trim();
  }

  String _paymentStatus(Map<String, dynamic> report) {
    return (report['payment_status'] ?? '').toString().toLowerCase().trim();
  }

  Color _reportMarkerColor(Map<String, dynamic> report) {
    final status = _reportStatus(report);
    final paymentStatus = _paymentStatus(report);

    if (status == 'completed') {
      return Colors.green.shade700;
    }

    if (status == 'in_progress') {
      return Colors.blue.shade700;
    }

    if (status == 'assigned') {
      return Colors.deepPurple.shade400;
    }

    if (paymentStatus == 'successful' || paymentStatus == 'completed' || paymentStatus == 'paid') {
      return Colors.teal.shade600;
    }

    if (paymentStatus == 'pending' || paymentStatus == 'initiated' || paymentStatus == 'processing') {
      return Colors.orange;
    }

    if (paymentStatus == 'failed' || paymentStatus == 'declined' || paymentStatus == 'rejected') {
      return Colors.red.shade600;
    }

    return Colors.orange;
  }

  String _markerTag(Map<String, dynamic> report) {
    final status = _reportStatus(report);
    final paymentStatus = _paymentStatus(report);

    if (status.isNotEmpty && status != 'pending') {
      return status.replaceAll('_', ' ').toUpperCase();
    }

    if (paymentStatus.isNotEmpty) {
      return paymentStatus.replaceAll('_', ' ').toUpperCase();
    }

    return 'PENDING';
  }

  String _shortId(Map<String, dynamic> report) {
    final id = (report['id'] ?? '').toString();
    if (id.length < 6) return id;
    return id.substring(0, 6).toUpperCase();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadNearbyReports() async {
    setState(() => _isLoading = true);

    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final collectorProvider = Provider.of<CollectorProvider>(context, listen: false);

    // Get current location first
    if (locationProvider.currentPosition == null) {
      await locationProvider.getCurrentLocation();
    }

    if (locationProvider.currentPosition != null) {
      await _refreshNearbyFromPosition(
        locationProvider.currentPosition!,
        showSnackBar: false,
        force: true,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusMapOnReports(locationProvider, collectorProvider.nearbyReports);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${collectorProvider.nearbyReports.length} nearby reports'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _startLiveLocationTracking() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    _locationSubscription = locationProvider.getLocationStream().listen((position) async {
      if (!mounted) return;

      locationProvider.setCurrentPosition(position);
      await _refreshNearbyFromPosition(position, showSnackBar: false, autoFocus: false);
    }, onError: (_) {
      // Keep the screen functional even if stream updates fail intermittently.
    });
  }

  Future<void> _refreshNearbyFromPosition(
    Position position, {
    required bool showSnackBar,
    bool autoFocus = true,
    bool force = false,
  }) async {
    final collectorProvider = Provider.of<CollectorProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    final now = DateTime.now();
    if (!force && _lastLiveRefreshAt != null && now.difference(_lastLiveRefreshAt!).inSeconds < 8) {
      return;
    }

    if (!force && _lastLivePosition != null) {
      final movedMeters = _distance(
        LatLng(_lastLivePosition!.latitude, _lastLivePosition!.longitude),
        LatLng(position.latitude, position.longitude),
      );
      if (movedMeters < 15) {
        return;
      }
    }

    _lastLiveRefreshAt = now;
    _lastLivePosition = position;

    await collectorProvider.updateCollectorLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    await collectorProvider.fetchNearbyReports(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (!mounted) return;

    if (autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _focusMapOnReports(locationProvider, collectorProvider.nearbyReports);
      });
    }

    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${collectorProvider.nearbyReports.length} nearby reports'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final collectorProvider = Provider.of<CollectorProvider>(context);
    final nearbyReports = collectorProvider.nearbyReports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Reports'),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isLoading ? 'Loading reports...' : 'Showing ${nearbyReports.length} nearby reports',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _loadNearbyReports,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          // Map view
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: locationProvider.currentPosition != null
                        ? LatLng(
                            locationProvider.currentPosition!.latitude,
                            locationProvider.currentPosition!.longitude,
                          )
                        : const LatLng(0.3476, 32.6169), // Nakawa
                    initialZoom: 13.0,
                    onTap: (_, __) => _clearSelection(),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.kcca.garbage_free_city',
                    ),
                    // Show user location
                    if (locationProvider.currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              locationProvider.currentPosition!.latitude,
                              locationProvider.currentPosition!.longitude,
                            ),
                            width: 30,
                            height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Show nearby reports
                    MarkerLayer(
                      markers: nearbyReports.where((report) {
                        final lat = _reportLatitude(report);
                        final lng = _reportLongitude(report);
                        return lat != null && lng != null;
                      }).toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final report = entry.value;
                        final lat = _reportLatitude(report)!;
                        final lng = _reportLongitude(report)!;
                        final markerColor = _reportMarkerColor(report);
                        return Marker(
                          point: LatLng(lat, lng),
                          width: 95,
                          height: 92,
                          child: GestureDetector(
                            onTap: () => _showReportDetails(report),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: markerColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: markerColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '#${index + 1} ${_markerTag(report)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _legendCard(),
                ),
                if (nearbyReports.isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Card(
                      color: Colors.white.withOpacity(0.95),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(
                          '${nearbyReports.length} reports on map',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (nearbyReports.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  itemCount: nearbyReports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final report = nearbyReports[index];
                    final markerColor = _reportMarkerColor(report);
                    final address = (report['address_description'] ?? report['address'] ?? 'Unknown address').toString();
                    final amount = report['payment_amount'] ?? report['amount'] ?? 0;
                    final lat = _reportLatitude(report);
                    final lng = _reportLongitude(report);
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: markerColor.withOpacity(0.2),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: markerColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('UGX $amount • Ref ${_shortId(report)}'),
                        trailing: ElevatedButton(
                          onPressed: () => _acceptAssignment(report),
                          child: const Text('Accept'),
                        ),
                        onTap: () {
                          if (lat != null && lng != null) {
                            _mapController.move(LatLng(lat, lng), 16);
                          }
                          _showReportDetails(report);
                        },
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Text(
                'No reports available right now. Pull to refresh or move location to load more nearby reports.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Legend',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _legendItem(Colors.teal.shade600, 'Paid'),
            _legendItem(Colors.orange, 'Pending payment'),
            _legendItem(Colors.blue.shade700, 'In progress'),
            _legendItem(Colors.green.shade700, 'Completed'),
            _legendItem(Colors.red.shade600, 'Failed payment'),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    // Clear any selected markers
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? _reportLatitude(Map<String, dynamic> report) {
    return _asDouble(report['latitude'] ?? report['lat']);
  }

  double? _reportLongitude(Map<String, dynamic> report) {
    return _asDouble(report['longitude'] ?? report['lng']);
  }

  void _focusMapOnReports(
    LocationProvider locationProvider,
    List<Map<String, dynamic>> reports,
  ) {
    final points = <LatLng>[];

    if (locationProvider.currentPosition != null) {
      points.add(
        LatLng(
          locationProvider.currentPosition!.latitude,
          locationProvider.currentPosition!.longitude,
        ),
      );
    }

    for (final report in reports) {
      final lat = _reportLatitude(report);
      final lng = _reportLongitude(report);
      if (lat != null && lng != null) {
        points.add(LatLng(lat, lng));
      }
    }

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  String _distanceLabel(Map<String, dynamic> report, LocationProvider locationProvider) {
    final userPos = locationProvider.currentPosition;
    final lat = _reportLatitude(report);
    final lng = _reportLongitude(report);

    if (userPos == null || lat == null || lng == null) {
      return 'Distance unavailable';
    }

    final meters = _distance(
      LatLng(userPos.latitude, userPos.longitude),
      LatLng(lat, lng),
    );

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }

    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  void _showReportDetails(Map<String, dynamic> report) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final lat = _reportLatitude(report);
    final lng = _reportLongitude(report);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                const Icon(Icons.delete, color: Colors.orange, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (report['address_description'] ?? report['address'] ?? 'Unknown address').toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Volume: ${report['estimated_volume'] ?? report['volume'] ?? '-'}',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'UGX ${report['payment_amount'] ?? report['amount'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distance',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _distanceLabel(report, locationProvider),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/report-details',
                    arguments: {
                      'reportId': report['id']?.toString(),
                      'id': report['id'],
                      'status': 'assigned',
                      'lastUpdated': DateTime.now(),
                      'address': report['address_description'] ?? report['address'],
                      'latitude': lat,
                      'longitude': lng,
                      'garbageType': report['garbage_type'] ?? 'mixed',
                      'volume': report['estimated_volume'] ?? report['volume'] ?? 'medium',
                      'amount': report['payment_amount'] ?? report['amount'] ?? 0,
                      'paymentStatus': report['payment_status'] ?? 'pending',
                      'txRef': report['transaction_ref'] ?? '-',
                      'collectorName': 'Unassigned',
                      'eta': '~15 min',
                    },
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('View Details'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (lat != null && lng != null) {
                        _openInAppMap(lat, lng);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location unavailable for this report')),
                        );
                      }
                    },
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text(
                      'Directions',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _acceptAssignment(report);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Accept',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _openInAppMap(double lat, double lng) {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final userPosition = locationProvider.currentPosition;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Report Location')),
          body: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.kcca.garbage_free_city',
              ),
              MarkerLayer(
                markers: [
                  if (userPosition != null)
                    Marker(
                      point: LatLng(userPosition.latitude, userPosition.longitude),
                      width: 34,
                      height: 34,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  Marker(
                    point: LatLng(lat, lng),
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptAssignment(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Assignment'),
        content: Text(
          'Accept garbage collection at ${report['address_description'] ?? report['address'] ?? 'this location'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final collectorProvider = Provider.of<CollectorProvider>(context, listen: false);
              final success = await collectorProvider.acceptAssignment(report['id'].toString());

              if (success) {
                await collectorProvider.fetchMyAssignments();
              }

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Assignment accepted! Check My Assignments.'
                        : (collectorProvider.error ?? 'Failed to accept assignment'),
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );

              if (success) {
                _loadNearbyReports();
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
