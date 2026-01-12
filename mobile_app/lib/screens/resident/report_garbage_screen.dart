import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/location_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/auth_provider.dart';

class ReportGarbageScreen extends StatefulWidget {
  const ReportGarbageScreen({Key? key}) : super(key: key);

  @override
  State<ReportGarbageScreen> createState() => _ReportGarbageScreenState();
}

class _ReportGarbageScreenState extends State<ReportGarbageScreen> {
  GoogleMapController? _mapController;
  final _descriptionController = TextEditingController();
  String _selectedVolume = 'medium';

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.getCurrentLocation();
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
      estimatedVolume: _selectedVolume,
    );

    if (!mounted) return;

    if (reportId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report created! Proceed to payment.'),
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
      appBar: AppBar(title: const Text('Report Garbage')),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: locationProvider.isLoadingLocation
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: locationProvider.currentPosition != null
                          ? LatLng(
                              locationProvider.currentPosition!.latitude,
                              locationProvider.currentPosition!.longitude,
                            )
                          : const LatLng(0.3476, 32.6169), // Nakawa
                      zoom: 15.0,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: locationProvider.currentPosition != null
                        ? {
                            Marker(
                              markerId: const MarkerId('garbage_location'),
                              position: LatLng(
                                locationProvider.currentPosition!.latitude,
                                locationProvider.currentPosition!.longitude,
                              ),
                            ),
                          }
                        : {},
                  ),
          ),
          Expanded(
            flex: 1,
            child: Padding(
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
                  DropdownButtonFormField<String>(
                    value: _selectedVolume,
                    decoration: const InputDecoration(labelText: 'Volume'),
                    items: const [
                      DropdownMenuItem(value: 'small', child: Text('Small')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'large', child: Text('Large')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedVolume = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
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
                        : const Text('Submit Report (UGX 5,000)'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
