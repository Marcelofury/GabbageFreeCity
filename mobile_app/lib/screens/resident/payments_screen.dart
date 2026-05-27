import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _apiService = ApiService();
  String? _processingReportId;
  String? _targetReportId;
  bool _autoPayFromRoute = false;
  bool _routeInitialized = false;
  bool _autoPayTriggered = false;
  bool _isSyncingPayment = false;

  String? _getUssdCodeForProvider(String? provider) {
    final normalized = provider?.toUpperCase();
    if (normalized == 'MTN') return '*165#';
    if (normalized == 'AIRTEL') return '*185#';
    return null;
  }

  Future<void> _launchUssdCode(String code) async {
    final encoded = code.replaceAll('#', '%23');
    final uri = Uri.parse('tel:$encoded');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open dialer on this device'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _showPaymentInstructionDialog({
    required String transactionRef,
    required String provider,
  }) async {
    final ussdCode = _getUssdCodeForProvider(provider);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Mobile Money Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reference: $transactionRef'),
            const SizedBox(height: 8),
            Text('Provider: $provider'),
            const SizedBox(height: 12),
            const Text(
              'If popup does not appear, use manual USSD to approve payment and then return to refresh.',
            ),
            if (ussdCode != null) ...[
              const SizedBox(height: 10),
              Text('Manual USSD: $ussdCode'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _loadReports();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('I Have Approved, Refresh'),
          ),
          if (ussdCode != null)
            ElevatedButton(
              onPressed: () async {
                await _launchUssdCode(ussdCode);
              },
              child: Text('Dial $ussdCode'),
            ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    await reportProvider.fetchMyReports();
    await _maybeAutoPayForTargetReport();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_routeInitialized) {
      return;
    }

    _routeInitialized = true;
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _targetReportId = args?['reportId']?.toString();
    _autoPayFromRoute = args?['autoPay'] == true;

    if (_autoPayFromRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeAutoPayForTargetReport();
      });
    }
  }

  Future<void> _maybeAutoPayForTargetReport() async {
    if (!_autoPayFromRoute || _autoPayTriggered || _targetReportId == null || !mounted) {
      return;
    }

    final reportProvider = Provider.of<ReportProvider>(context, listen: false);

    final target = reportProvider.reports
        .where((r) => r.id == _targetReportId)
        .cast<dynamic>()
        .toList();

    if (target.isEmpty) {
      return;
    }

    final report = target.first;
    if (!_isReportPaymentPending(report)) {
      _autoPayTriggered = true;
      return;
    }

    _autoPayTriggered = true;
    await _initiatePayment(report.id);
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
                            final isPending = _isReportPaymentPending(report);
                            final isTarget = report.id == _targetReportId;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: isTarget
                                  ? RoundedRectangleBorder(
                                      side: const BorderSide(color: Colors.blue, width: 1.5),
                                      borderRadius: BorderRadius.circular(12),
                                    )
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isPending
                                          ? Colors.orange.withOpacity(0.2)
                                          : Colors.green.withOpacity(0.2),
                                      child: Icon(
                                        isPending ? Icons.pending : Icons.check_circle,
                                        color: isPending ? Colors.orange : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            report.addressDescription,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 15,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Packages: ${report.packageCount}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _paymentLabel(report),
                                            style: TextStyle(
                                              color: isPending ? Colors.orange : Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'UGX ${report.paymentAmount.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Colors.green,
                                          ),
                                        ),
                                        if (isPending) ...[
                                          const SizedBox(height: 4),
                                          SizedBox(
                                            height: 32,
                                            child: ElevatedButton(
                                              onPressed: _processingReportId == report.id
                                                  ? null
                                                  : () => _initiatePayment(report.id),
                                              style: ElevatedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
                                                textStyle: const TextStyle(fontSize: 12),
                                              ),
                                              child: _processingReportId == report.id
                                                  ? const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Text('Pay Now'),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
    );
  }

  int _getPendingCount() {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    return reportProvider.reports.where((r) => _isReportPaymentPending(r)).length;
  }

  String _calculateTotalPending() {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final total = reportProvider.reports
        .where((r) => _isReportPaymentPending(r))
        .fold<double>(0, (sum, r) => sum + r.paymentAmount);
    return total.toStringAsFixed(0);
  }

  bool _isReportPaymentPending(dynamic report) {
    final paymentStatus = (report.paymentStatus ?? 'pending').toString().toLowerCase();
    return !['successful', 'completed', 'paid'].contains(paymentStatus);
  }

  String _paymentLabel(dynamic report) {
    final paymentStatus = (report.paymentStatus ?? 'pending').toString().toLowerCase();

    if (['successful', 'completed', 'paid'].contains(paymentStatus)) {
      return 'Payment Complete';
    }

    if (paymentStatus == 'processing') {
      return 'Payment Processing';
    }

    if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
      return 'Payment Failed';
    }

    return 'Payment Pending';
  }

  Future<void> _initiatePayment(String reportId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    String? phone = authProvider.user?.phoneNumber;

    if (phone == null || phone.trim().isEmpty) {
      phone = await _promptPhoneNumber(authProvider.user?.phoneNumber);
    }

    if (phone == null || phone.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _processingReportId = reportId;
    });

    try {
      final validation = await _apiService.validatePaymentPhone(phone: phone);
      if (validation['success'] != true || validation['data']?['valid'] != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation['data']?['message']?.toString() ?? validation['message']?.toString() ?? 'Invalid phone number'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final formattedPhone = validation['data']?['formattedPhone']?.toString() ?? phone;
      final provider = validation['data']?['provider']?.toString() ?? 'UNKNOWN';
      final response = await _apiService.initiatePayment(
        orderId: reportId,
        method: 'marzpay',
        phone: formattedPhone,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        final transactionRef = data?['transactionRef']?.toString() ?? 'N/A';
        final status = data?['status']?.toString() ?? 'pending';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initiated. Ref: $transactionRef ($status).'),
            backgroundColor: Colors.green,
          ),
        );

        if (transactionRef != 'N/A') {
          unawaited(_pollAndSyncPaymentStatus(
            reportId: reportId,
            transactionRef: transactionRef,
          ));
        }

        await _showPaymentInstructionDialog(
          transactionRef: transactionRef,
          provider: provider,
        );

        await _loadReports();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']?.toString() ?? 'Failed to initiate payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingReportId = null;
        });
      }
    }
  }

  Future<void> _pollAndSyncPaymentStatus({
    required String reportId,
    required String transactionRef,
  }) async {
    if (_isSyncingPayment) return;
    _isSyncingPayment = true;

    try {
      for (var attempt = 0; attempt < 12; attempt++) {
        await Future.delayed(Duration(seconds: attempt == 0 ? 4 : 10));
        if (!mounted) return;

        final syncResult = await _apiService.syncPaymentStatus(
          transactionRef: transactionRef,
          reportId: reportId,
        );

        if (syncResult['success'] != true) {
          continue;
        }

        final data = syncResult['data'] as Map<String, dynamic>?;
        final paymentStatus = data?['new_payment_status']?.toString() ?? 'pending';

        if (paymentStatus == 'successful' || paymentStatus == 'failed') {
          await _loadReports();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                paymentStatus == 'successful'
                    ? 'Payment confirmed successfully.'
                    : 'Payment failed or expired. Please try again.',
              ),
              backgroundColor: paymentStatus == 'successful' ? Colors.green : Colors.red,
            ),
          );
          return;
        }
      }
    } finally {
      _isSyncingPayment = false;
    }
  }

  Future<String?> _promptPhoneNumber(String? initialPhone) async {
    final controller = TextEditingController(text: initialPhone ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mobile Money Payment'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your MTN or Airtel Uganda number to receive payment prompt.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '0783xxxxxx or +256783xxxxxx',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }
}
