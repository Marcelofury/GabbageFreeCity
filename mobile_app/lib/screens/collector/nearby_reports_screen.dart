import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/collector_provider.dart';
import '../../providers/location_provider.dart';

class NearbyReportsScreen extends StatefulWidget {
  const NearbyReportsScreen({super.key});

  @override
  State<NearbyReportsScreen> createState() => _NearbyReportsScreenState();
}

class _NearbyReportsScreenState extends State<NearbyReportsScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadNearbyReports();
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
      await collectorProvider.fetchNearbyReports(
        latitude: locationProvider.currentPosition!.latitude,
        longitude: locationProvider.currentPosition!.longitude,
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);

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
            child: FlutterMap(
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
                  markers: nearbyReports.map((report) {
                    final lat = (report['latitude'] ?? 0.3476).toDouble();
                    final lng = (report['longitude'] ?? 32.6169).toDouble();
                    return Marker(
                      point: LatLng(lat, lng),
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () => _showReportDetails(report),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange,
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
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (report['estimated_volume'] ?? report['volume'] ?? 'unknown').toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
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
          ),
        ],
      ),
    );
  }

  void _clearSelection() {
    // Clear any selected markers
  }

  void _showReportDetails(Map<String, dynamic> report) {
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
                      const Text(
                        '~2.5 km',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                      'latitude': report['latitude'] ?? 0.3476,
                      'longitude': report['longitude'] ?? 32.6169,
                      'garbageType': 'mixed',
                      'volume': report['estimated_volume'] ?? report['volume'] ?? 'medium',
                      'amount': report['payment_amount'] ?? report['amount'] ?? 0,
                      'paymentStatus': 'paid',
                      'txRef': 'AUTO',
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
                      _openMaps(
                        (report['latitude'] ?? 0.3476).toDouble(),
                        (report['longitude'] ?? 32.6169).toDouble(),
                      );
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

  void _openMaps(double lat, double lng) async {
    // Open in OpenStreetMap with directions
    final url = Uri.parse('https://www.openstreetmap.org/directions?to=$lat,$lng');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening map to: $lat, $lng'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coordinates: $lat, $lng'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
