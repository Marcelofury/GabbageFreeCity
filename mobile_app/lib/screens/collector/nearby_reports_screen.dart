import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';

class NearbyReportsScreen extends StatefulWidget {
  const NearbyReportsScreen({super.key});

  @override
  State<NearbyReportsScreen> createState() => _NearbyReportsScreenState();
}

class _NearbyReportsScreenState extends State<NearbyReportsScreen> {
  final MapController _mapController = MapController();
  bool _isLoading = false;
  
  // Mock nearby reports (in real app, fetch from API)
  final List<Map<String, dynamic>> _nearbyReports = [
    {
      'id': '1',
      'address': 'Nakawa Market',
      'latitude': 0.3476,
      'longitude': 32.6169,
      'volume': 'medium',
      'amount': 5000,
    },
    {
      'id': '2',
      'address': 'Ntinda Shopping Complex',
      'latitude': 0.3583,
      'longitude': 32.6294,
      'volume': 'large',
      'amount': 10000,
    },
    {
      'id': '3',
      'address': 'Bukoto Street',
      'latitude': 0.3550,
      'longitude': 32.6050,
      'volume': 'small',
      'amount': 3000,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadNearbyReports();
  }

  Future<void> _loadNearbyReports() async {
    setState(() => _isLoading = true);
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    
    // Get current location first
    if (locationProvider.currentPosition == null) {
      await locationProvider.getCurrentLocation();
    }
    
    // In real app: call API here
    // await apiService.getNearbyReports(lat, lng, radius: 5000);
    
    await Future.delayed(const Duration(seconds: 1)); // Simulate API call
    
    if (mounted) {
      setState(() => _isLoading = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${_nearbyReports.length} nearby reports'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
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
                    _isLoading 
                        ? 'Loading reports...' 
                        : 'Showing ${_nearbyReports.length} nearby reports',
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
                  markers: _nearbyReports.map((report) {
                    return Marker(
                      point: LatLng(report['latitude'], report['longitude']),
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
                                report['volume'],
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
      builder: (context) => Container(
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
                        report['address'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Volume: ${report['volume']}',
                        style: TextStyle(color: Colors.grey[600]),
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
                      Text('Payment', style: TextStyle(color: Colors.grey[600])),
                      Text(
                        'UGX ${report['amount']}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Distance', style: TextStyle(color: Colors.grey[600])),
                      const Text(
                        '~2.5 km',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openMaps(report['latitude'], report['longitude']);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _acceptAssignment(report);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openMaps(double lat, double lng) async {
    // Open in external maps app
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening directions to location...'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: () {
            // In real app, use url_launcher
            // launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }

  void _acceptAssignment(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Assignment'),
        content: Text('Accept garbage collection at ${report['address']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In real app: call API to accept assignment
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Assignment accepted! Check My Assignments.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}
