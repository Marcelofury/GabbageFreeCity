import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  bool _initialized = false;
  String? _expectedReportId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _expectedReportId = args?['reportId']?.toString();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    if (_isProcessing) return;
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final raw = barcodes.first.rawValue;
                    if (raw == null || raw.isEmpty) return;
                    _handleScannedCode(raw);
                  },
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black45,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            'Verifying collection...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[100],
            child: Column(
              children: [
                const Text(
                  'What can you scan?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  Icons.qr_code,
                  'Resident Report QR',
                  'Must include report_id for final completion',
                ),
                _buildInfoTile(
                  Icons.assignment,
                  'Assignment Match Required',
                  'QR report_id must match current assignment',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            radius: 20,
            child: Icon(icon, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScannedCode(String rawCode) async {
    setState(() => _isProcessing = true);
    await _scannerController.stop();

    String? reportId;
    Map<String, dynamic>? parsedPayload;
    try {
      final decoded = jsonDecode(rawCode);
      if (decoded is Map<String, dynamic>) {
        parsedPayload = decoded;
        reportId = decoded['report_id']?.toString();
      }
    } catch (_) {
      reportId = null;
    }

    if (reportId == null || reportId.isEmpty) {
      _showFailure('Invalid QR content. Scan a resident report QR with report_id.');
      return;
    }

    if (parsedPayload?['app'] != null && parsedPayload?['app'] != 'GFC') {
      _showFailure('Unsupported QR source. Please scan a GFC resident report QR.');
      return;
    }

    if (_expectedReportId != null && _expectedReportId != reportId) {
      _showFailure('Scanned QR does not match the selected assignment report.');
      return;
    }

    // ignore: use_build_context_synchronously
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final position = await locationProvider.getCurrentLocation();
    if (!mounted) return;

    if (position == null) {
      _showFailure(locationProvider.error ?? 'Location is required to verify collection.');
      return;
    }

    final api = ApiService();
    final response = await api.verifyCollection(
      reportId: reportId,
      latitude: position.latitude,
      longitude: position.longitude,
      qrCodeData: rawCode,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      final schedule = response['data']?['schedule'] as Map<String, dynamic>?;
      final log = response['data']?['collection_log'] as Map<String, dynamic>?;
      final outOfSchedule = schedule?['out_of_schedule'] == true || log?['out_of_schedule'] == true;
      _showSuccess(reportId, outOfSchedule: outOfSchedule);
    } else {
      _showFailure(response['message']?.toString() ?? 'Verification failed');
    }
  }

  void _showSuccess(String reportId, {required bool outOfSchedule}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Collection Verified'),
          ],
        ),
        content: Text(
          outOfSchedule
              ? 'Report ID: $reportId\nCollection verified (outside scheduled day).'
              : 'Report ID: $reportId\nCollection was verified successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanner();
            },
            child: const Text('Scan Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showFailure(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Verification Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanner();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _resumeScanner() async {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    await _scannerController.start();
  }
}
