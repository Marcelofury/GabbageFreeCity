import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/report_provider.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _isPaid(String paymentStatus) {
    final normalized = paymentStatus.toLowerCase();
    return normalized == 'successful' || normalized == 'completed' || normalized == 'paid' || normalized == 'success';
  }

  String _compactStatusLabel(dynamic report) {
    final status = report.status.toString().toLowerCase();
    final paymentStatus = report.paymentStatus.toString().toLowerCase();

    if (status == 'pending') {
      if (_isPaid(paymentStatus)) {
        return 'Awaiting Assignment';
      }
      if (paymentStatus == 'processing' || paymentStatus == 'initiated') {
        return 'Payment Processing';
      }
      return 'Pending Payment';
    }

    if (status == 'assigned') return 'Collector Assigned';
    if (status == 'in_progress') return 'In Progress';
    if (status == 'completed') return 'Completed';
    if (status == 'cancelled') return 'Cancelled';

    return report.statusDisplay.toString();
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    await reportProvider.fetchMyReports();
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: reportProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : reportProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        reportProvider.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : reportProvider.reports.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No reports yet.\nTap Report Garbage to get started.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: reportProvider.reports.length,
                    itemBuilder: (context, index) {
                      final report = reportProvider.reports[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: _buildStatusIcon(report.status),
                          title: Text(report.addressDescription),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Packages: ${report.packageCount}'),
                              Text(
                                'Reported: ${DateFormat.yMMMd().format(report.reportedAt)}',
                              ),
                            ],
                          ),
                          trailing: SizedBox(
                            width: 130,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _compactStatusLabel(report),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: _getStatusColor(report.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'UGX ${report.paymentAmount.toStringAsFixed(0)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/report-details',
                              arguments: {
                                'reportId': report.id,
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
                                'paymentStatus': _isPaid(report.paymentStatus) ? 'paid' : 'unpaid',
                                'txRef': report.transactionRef ?? 'N/A',
                                'collectorName': report.assignedCollectorId != null ? 'Assigned Collector' : null,
                                'eta': report.status == 'assigned' ? '~20 min' : null,
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'pending':
        icon = Icons.pending;
        color = Colors.orange;
        break;
      case 'assigned':
        icon = Icons.person;
        color = Colors.blue;
        break;
      case 'in_progress':
        icon = Icons.local_shipping;
        color = Colors.purple;
        break;
      case 'completed':
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
