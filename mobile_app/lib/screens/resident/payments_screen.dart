import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
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
      appBar: AppBar(
        title: const Text('Payments'),
      ),
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          const Text(
                            'No payments yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your payment history will appear here',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Summary Card
                          Card(
                            color: Colors.orange.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  const Text(
                                    'Total Pending Payments',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'UGX ${_calculateTotalPending()}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_getPendingCount()} pending report(s)',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Payment History',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Report payments list
                          ...reportProvider.reports.map((report) {
                            final isPending = report.status == 'pending';
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isPending
                                      ? Colors.orange.withOpacity(0.2)
                                      : Colors.green.withOpacity(0.2),
                                  child: Icon(
                                    isPending ? Icons.pending : Icons.check_circle,
                                    color: isPending ? Colors.orange : Colors.green,
                                  ),
                                ),
                                title: Text(report.addressDescription),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Volume: ${report.estimatedVolume}'),
                                    Text(
                                      isPending ? 'Payment Pending' : 'Payment Complete',
                                      style: TextStyle(
                                        color: isPending ? Colors.orange : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'UGX ${report.paymentAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (isPending)
                                      TextButton(
                                        onPressed: () => _initiatePayment(report.id),
                                        child: const Text('Pay Now'),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
    );
  }

  int _getPendingCount() {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    return reportProvider.reports.where((r) => r.status == 'pending').length;
  }

  String _calculateTotalPending() {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final total = reportProvider.reports
        .where((r) => r.status == 'pending')
        .fold<double>(0, (sum, r) => sum + r.paymentAmount);
    return total.toStringAsFixed(0);
  }

  void _initiatePayment(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment, size: 64, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              'Mobile Money Payment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'You will receive an MTN or Airtel Money prompt on your phone to complete the payment.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment integration coming soon!'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
