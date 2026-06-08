import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import '../../models/garbage_report.dart';
import '../../providers/report_provider.dart';

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({super.key});

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final reportId = args?['reportId']?.toString();
    final provider = Provider.of<ReportProvider>(context, listen: false);

    if (reportId != null && provider.findReportById(reportId) == null) {
      provider.fetchMyReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final provider = Provider.of<ReportProvider>(context);
    final reportId = args?['reportId']?.toString();
    final found = reportId != null ? provider.findReportById(reportId) : null;
    final report = _composeReportMap(found, args) ??
        {
          'id': 'RPT-0001',
          'status': 'pending',
          'lastUpdated': DateTime.now(),
          'address': 'Location unavailable',
          'latitude': null,
          'longitude': null,
          'garbageType': 'mixed',
          'volume': 'medium',
          'amount': 5000,
          'paymentStatus': 'unpaid',
          'txRef': 'N/A',
          'collectorName': null,
          'eta': null,
        };

    if (provider.isLoading && found == null && reportId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = report['status']?.toString() ?? 'pending';
    final paymentStatus = report['paymentStatus']?.toString() ?? 'unpaid';
    final lat = _asDouble(report['latitude']);
    final lng = _asDouble(report['longitude']);
    final hasLiveLocation = lat != null && lng != null;
    final canShowCollectionQr = paymentStatus == 'paid' &&
      (status == 'assigned' || status == 'in_progress');

    return Scaffold(
      appBar: AppBar(title: const Text('Report Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: _statusColor(status).withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report #${report['id']}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip(_statusLabel(status), _statusColor(status)),
                      const SizedBox(width: 8),
                      _chip(
                        paymentStatus == 'paid' ? 'Paid' : 'Unpaid',
                        paymentStatus == 'paid' ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Updated: ${_formatDateTime(report['lastUpdated'])}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section('Location', Icons.location_on_outlined, [
            _row('Address', report['address']?.toString() ?? '-'),
            _row('Coordinates', hasLiveLocation ? '$lat, $lng' : 'Not available yet'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: hasLiveLocation ? () => _openInMap(lat, lng) : null,
                icon: const Icon(Icons.map),
                label: const Text('Open in Map'),
              ),
            ),
            if (!hasLiveLocation)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Map opens once report coordinates are loaded from server.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          _section('Garbage Details', Icons.delete_outline, [
            _row('Type', report['garbageType']?.toString() ?? '-'),
            _row('Packages', report['packageCount']?.toString() ?? '-'),
            _row('Volume Label', report['volume']?.toString() ?? '-'),
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              alignment: Alignment.center,
              child: const Text('Photo preview not available'),
            ),
          ]),
          const SizedBox(height: 12),
          _section('Payment', Icons.payment_outlined, [
            _row('Amount', 'UGX ${report['amount']}'),
            _row('Status', paymentStatus == 'paid' ? 'Paid' : 'Pending payment'),
            _row('Transaction Ref', report['txRef']?.toString() ?? 'N/A'),
          ]),
          if (report['collectorName'] != null) ...[
            const SizedBox(height: 12),
            _section('Collector', Icons.local_shipping_outlined, [
              _row('Name', report['collectorName'].toString()),
              _row('ETA', report['eta']?.toString() ?? '-'),
            ]),
          ],
          const SizedBox(height: 12),
          _section('Progress', Icons.timeline, [
            _timeline('Report submitted', true),
            _timeline('Payment confirmed', paymentStatus == 'paid'),
            _timeline('Collector assigned', status == 'assigned' || status == 'in_progress' || status == 'completed'),
            _timeline('Collection in progress', status == 'in_progress' || status == 'completed'),
            _timeline('Collection completed', status == 'completed'),
          ]),
          if (canShowCollectionQr) ...[
            const SizedBox(height: 12),
            _section('Collection QR', Icons.qr_code, [
              const Text('Show this QR to the assigned collector for final scan and completion.'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: () => _showCollectionQr(report),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show QR for Collector'),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _showReceiptDialog(report);
                },
                child: const Text('Receipt'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: paymentStatus == 'paid'
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/payments',
                          arguments: {
                            'reportId': report['id']?.toString(),
                            'autoPay': true,
                          },
                        );
                      },
                child: Text(paymentStatus == 'paid' ? 'Paid' : 'Pay Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _timeline(String label, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return 'Pending';
    }
  }

  String _formatDateTime(dynamic value) {
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return value?.toString() ?? '-';
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _openInMap(double? lat, double? lng) async {
    if (lat == null || lng == null || !mounted) {
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReportLocationMapScreen(latitude: lat, longitude: lng),
      ),
    );
  }

  void _showReceiptDialog(Map<String, dynamic> report) {
    final status = (report['paymentStatus'] ?? 'unpaid').toString();
    if (status != 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt is available after successful payment')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Receipt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Receipt #', 'GFC-${report['id'] ?? '-'}'),
            _row('Amount', 'UGX ${report['amount'] ?? '-'}'),
            _row('Packages', '${report['packageCount'] ?? '-'}'),
            _row('Transaction Ref', report['txRef']?.toString() ?? 'N/A'),
            _row('Address', report['address']?.toString() ?? '-'),
            _row('Date', _formatDateTime(report['lastUpdated'])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final text =
                  'Receipt: GFC-${report['id'] ?? '-'}\n'
                  'Amount: UGX ${report['amount'] ?? '-'}\n'
                  'Packages: ${report['packageCount'] ?? '-'}\n'
                  'Tx Ref: ${report['txRef']?.toString() ?? 'N/A'}\n'
                  'Address: ${report['address']?.toString() ?? '-'}';
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Receipt copied to clipboard')),
                );
              }
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCollectionQr(Map<String, dynamic> report) {
    final payload = {
      'app': 'GFC',
      'report_id': report['id']?.toString(),
      'payment_status': report['paymentStatus']?.toString() ?? 'unknown',
      'generated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final rawPayload = jsonEncode(payload);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Collector Scan QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: rawPayload,
              version: QrVersions.auto,
              size: 220,
            ),
            const SizedBox(height: 10),
            Text(
              'Report ID: ${report['id']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Collector should scan this after starting collection.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: rawPayload));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('QR payload copied to clipboard')),
                );
              }
            },
            child: const Text('Copy Payload'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _composeReportMap(GarbageReport? report, Map<String, dynamic>? args) {
    if (report == null) {
      return args;
    }

    return {
      'id': report.id,
      'status': report.status,
      'lastUpdated': report.completedAt ?? report.assignedAt ?? report.reportedAt,
      'address': report.addressDescription,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'garbageType': report.garbageType,
      'volume': report.estimatedVolume,
      'packageCount': report.packageCount,
      'amount': report.paymentAmount.toStringAsFixed(0),
      'paymentStatus': ['successful', 'completed', 'paid'].contains(report.paymentStatus) ? 'paid' : 'unpaid',
      'txRef': report.transactionRef ?? 'N/A',
      'collectorName': report.assignedCollectorId != null ? 'Assigned Collector' : null,
      'eta': report.status == 'assigned' ? '~20 min' : null,
    };
  }
}

class _ReportLocationMapScreen extends StatelessWidget {
  const _ReportLocationMapScreen({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Location')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(latitude, longitude),
          initialZoom: 16,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.kcca.garbage_free_city',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(latitude, longitude),
                width: 44,
                height: 44,
                child: const Icon(Icons.location_on, size: 40, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
