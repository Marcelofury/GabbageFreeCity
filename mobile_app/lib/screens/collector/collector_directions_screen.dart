import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../providers/location_provider.dart';

class CollectorDirectionsScreen extends StatefulWidget {
  const CollectorDirectionsScreen({super.key});

  @override
  State<CollectorDirectionsScreen> createState() => _CollectorDirectionsScreenState();
}

class _CollectorDirectionsScreenState extends State<CollectorDirectionsScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLocation());
  }

  Future<void> _ensureLocation() async {
    if (!mounted) return;

    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    if (locationProvider.currentPosition != null) {
      return;
    }

    setState(() => _loadingLocation = true);
    await locationProvider.getCurrentLocation();
    if (!mounted) return;
    setState(() => _loadingLocation = false);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportLat = _asDouble(args?['latitude']);
    final reportLng = _asDouble(args?['longitude']);
    final address = (args?['address'] ?? 'Resident location').toString();

    final locationProvider = Provider.of<LocationProvider>(context);
    final current = locationProvider.currentPosition;

    if (reportLat == null || reportLng == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Directions')),
        body: const Center(
          child: Text('This assignment does not have valid coordinates.'),
        ),
      );
    }

    final points = <LatLng>[LatLng(reportLat, reportLng)];
    if (current != null) {
      points.add(LatLng(current.latitude, current.longitude));
    }

    final estimatedMeters = current == null
        ? null
        : _distance(
            LatLng(current.latitude, current.longitude),
            LatLng(reportLat, reportLng),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Directions')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: points.first,
                initialZoom: 14,
                onMapReady: () {
                  if (points.length > 1) {
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: LatLngBounds.fromPoints(points),
                        padding: const EdgeInsets.all(60),
                      ),
                    );
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.kcca.garbage_free_city',
                ),
                if (current != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [
                          LatLng(current.latitude, current.longitude),
                          LatLng(reportLat, reportLng),
                        ],
                        color: Colors.blue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(reportLat, reportLng),
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                    ),
                    if (current != null)
                      Marker(
                        point: LatLng(current.latitude, current.longitude),
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
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  address,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (estimatedMeters != null)
                  Text(
                    estimatedMeters < 1000
                        ? 'Approx distance: ${estimatedMeters.toStringAsFixed(0)} m'
                        : 'Approx distance: ${(estimatedMeters / 1000).toStringAsFixed(2)} km',
                  )
                else
                  const Text('Enable location to show distance from collector to resident.'),
                if (_loadingLocation)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
