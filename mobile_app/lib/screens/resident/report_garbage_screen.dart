import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';

class ReportGarbageScreen extends StatefulWidget {
  const ReportGarbageScreen({super.key});

  @override
  State<ReportGarbageScreen> createState() => _ReportGarbageScreenState();
}

class _ReportGarbageScreenState extends State<ReportGarbageScreen> {
  final MapController _mapController = MapController();
  final _descriptionController = TextEditingController();
  int _packageCount = 1;

  @override
  void initState() {
    super.initState();
    // Run after first frame to avoid build-time state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLocation();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    if (!mounted) return;
    
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final position = await locationProvider.getCurrentLocation();
    
    // Move map to user's actual location once loaded
    if (position != null && mounted) {
      // Wait for next frame to ensure map is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              16.0,
            );
          } catch (e) {
            debugPrint('⚠️ Could not move map: $e');
          }
        }
      });
    } else if (locationProvider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(locationProvider.error!),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _loadLocation,
            textColor: Colors.white,
          ),
        ),
      );
    }
  }

  Future<void> _submitReport() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);

    if (locationProvider.currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for location to load')),
      );
      return;
    }

    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the garbage location')),
      );
      return;
    }

    final reportId = await reportProvider.createReport(
      latitude: locationProvider.currentPosition!.latitude,
      longitude: locationProvider.currentPosition!.longitude,
      addressDescription: _descriptionController.text,
      packageCount: _packageCount,
    );

    if (!mounted) return;

    if (reportId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reportProvider.error ?? 'Failed to create report'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);
    final reportProvider = Provider.of<ReportProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Garbage'),
        actions: [
          // Show location status
          if (locationProvider.currentPosition != null)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(
                Icons.gps_fixed,
                color: Colors.green,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 2,
                child: locationProvider.isLoadingLocation
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Getting your location...'),
                            SizedBox(height: 8),
                            Text(
                              'Please ensure GPS is enabled',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: locationProvider.currentPosition != null
                              ? LatLng(
                                  locationProvider.currentPosition!.latitude,
                                  locationProvider.currentPosition!.longitude,
                                )
                              : const LatLng(0.3476, 32.6169), // Nakawa
                          initialZoom: 16.0,
                          minZoom: 5.0,
                          maxZoom: 19.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.kcca.garbage_free_city',
                            maxNativeZoom: 19,
                          ),
                          if (locationProvider.currentPosition != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    locationProvider.currentPosition!.latitude,
                                    locationProvider.currentPosition!.longitude,
                                  ),
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_pin,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          // OSM Attribution (Required)
                          RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                                onTap: () => {},
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              Expanded(
                flex: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Location Description',
                          hintText: 'e.g., Near Nakawa Market',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Garbage Quantity',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _packageCount > 1
                                  ? () {
                                      setState(() {
                                        _packageCount -= 1;
                                      });
                                    }
                                  : null,
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              '$_packageCount',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _packageCount += 1;
                                });
                              },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: reportProvider.isLoading ? null : _submitReport,
                          child: reportProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit Report'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Map Controls - Now properly positioned outside Column
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'my_location',
                  onPressed: _loadLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
