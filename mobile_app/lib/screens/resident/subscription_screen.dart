import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _activeSubscription;
  List<dynamic> _plans = [];
  List<Map<String, dynamic>> _collectionHistory = [];
  String _historyPeriod = 'month';
  bool _isLoadingHistory = false;
  bool _isSyncingPayment = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final plansResponse = await _apiService.getSubscriptionPlans();
      final subscriptionResponse = await _apiService.getMySubscription();
      final historyResponse = await _apiService.getResidentCollectionHistory(period: _historyPeriod);

      if (!mounted) return;

      if (plansResponse['success'] != true) {
        throw Exception(plansResponse['message'] ?? 'Failed to load plans');
      }

      if (subscriptionResponse['success'] != true) {
        throw Exception(subscriptionResponse['message'] ?? 'Failed to load subscription');
      }

      if (historyResponse['success'] != true) {
        throw Exception(historyResponse['message'] ?? 'Failed to load collection history');
      }

      setState(() {
        _plans = (plansResponse['data']?['plans'] as List?) ?? [];
        _activeSubscription = subscriptionResponse['data']?['subscription'];
        final rows = (historyResponse['data']?['reports'] as List?) ?? [];
        _collectionHistory = rows
            .whereType<Map<String, dynamic>>()
            .map(Map<String, dynamic>.from)
            .toList();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHistory({String? period}) async {
    setState(() {
      _isLoadingHistory = true;
      if (period != null) {
        _historyPeriod = period;
      }
    });

    try {
      final response = await _apiService.getResidentCollectionHistory(period: _historyPeriod);
      if (!mounted) return;

      if (response['success'] == true) {
        final rows = (response['data']?['reports'] as List?) ?? [];
        setState(() {
          _collectionHistory = rows
              .whereType<Map<String, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList();
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load collection history');
      }
    } catch (_) {
      // Leave the last successful history list visible.
    } finally {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  String _scheduleLabelFromWeekly(dynamic weekly) {
    final weeklyInt = int.tryParse(weekly?.toString() ?? '');
    if (weeklyInt == 1) return 'Tuesday';
    if (weeklyInt == 2) return 'Tuesday, Thursday';
    return 'Custom';
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _purchasePlan(Map<String, dynamic> plan) async {
    final phoneController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Mobile Money Number'),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+256XXXXXXXXX',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.purchaseSubscription(
        planId: plan['id'].toString(),
        phone: phoneController.text.trim(),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>?;
        final transactionRef = data?['transactionRef']?.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment initiated. Please approve on your phone.')),
        );

        if (transactionRef != null && transactionRef.isNotEmpty) {
          unawaited(_pollAndSyncSubscriptionStatus(transactionRef: transactionRef));
        }

        await _loadData();
      } else {
        throw Exception(response['message'] ?? 'Failed to start subscription payment');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pollAndSyncSubscriptionStatus({
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
        );

        if (syncResult['success'] != true) {
          continue;
        }

        final syncData = syncResult['data'] as Map<String, dynamic>?;
        final paymentStatus = syncData?['new_payment_status']?.toString() ?? 'pending';

        if (paymentStatus == 'successful') {
          await _loadData();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Subscription activated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          return;
        }

        if (paymentStatus == 'failed') {
          await _loadData();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    } finally {
      _isSyncingPayment = false;
    }
  }

  Widget _buildActiveCard() {
    if (_activeSubscription == null) {
      return const SizedBox.shrink();
    }

    final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
    final endDate = _activeSubscription?['end_date']?.toString() ?? '-';
    final remaining = _activeSubscription?['remaining_collections']?.toString() ?? '0';
    final scheduleLabel = _scheduleLabelFromWeekly(plan?['weekly_collections']);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Subscription',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(plan?['name']?.toString() ?? 'Subscription Plan'),
            const SizedBox(height: 6),
            Text('Remaining collections: $remaining'),
            const SizedBox(height: 6),
            Text('Expires: $endDate'),
            const SizedBox(height: 6),
            Text('Scheduled days: $scheduleLabel'),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final name = plan['name']?.toString() ?? 'Plan';
    final weekly = plan['weekly_collections']?.toString() ?? '-';
    final monthly = plan['monthly_collections']?.toString() ?? '-';
    final monthlyPrice = plan['monthly_price_ugx']?.toString() ?? '-';
    final prepayMonths = plan['prepay_months']?.toString() ?? '3';
    final prepayPrice = plan['prepay_price_ugx']?.toString() ?? '-';
    final scheduleLabel = _scheduleLabelFromWeekly(plan['weekly_collections']);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text('${weekly}x/week • $monthly/month'),
            const SizedBox(height: 6),
            Text('UGX $monthlyPrice per month'),
            const SizedBox(height: 6),
            Text('$prepayMonths months prepaid: UGX $prepayPrice'),
            const SizedBox(height: 6),
            Text('Scheduled days: $scheduleLabel'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _purchasePlan(plan),
                child: const Text('Subscribe (3 months prepaid)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildActiveCard(),
                    if (_activeSubscription != null) const SizedBox(height: 16),
                    if (_activeSubscription != null) ...[
                      const Text(
                        'Collection Proof',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('This Week'),
                              selected: _historyPeriod == 'week',
                              onSelected: (_) => _loadHistory(period: 'week'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('This Month'),
                              selected: _historyPeriod == 'month',
                              onSelected: (_) => _loadHistory(period: 'month'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('All Time'),
                              selected: _historyPeriod == 'all',
                              onSelected: (_) => _loadHistory(period: 'all'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingHistory)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_collectionHistory.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('No completed collections for this filter.'),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Report ID')),
                              DataColumn(label: Text('Collector')),
                              DataColumn(label: Text('Schedule')),
                              DataColumn(label: Text('QR')),
                              DataColumn(label: Text('Status')),
                            ],
                            rows: _collectionHistory.map((item) {
                              final log = item['collection_log'] as Map<String, dynamic>?;
                              final collector = item['assigned_collector'] as Map<String, dynamic>?;
                              final schedule = (log?['scheduled_days'] ?? 'Custom').toString();
                              final qrScanned = log?['qr_code_scanned'] == true ? 'Yes' : 'No';
                              final outOfSchedule = log?['out_of_schedule'] == true;
                              return DataRow(
                                cells: [
                                  DataCell(Text(_formatDate(item['completed_at']))),
                                  DataCell(Text(item['id']?.toString() ?? '-')),
                                  DataCell(Text(collector?['full_name']?.toString() ?? '-')),
                                  DataCell(Text(schedule)),
                                  DataCell(Text(qrScanned)),
                                  DataCell(Text(outOfSchedule ? 'Out of schedule' : 'Completed')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Plans',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._plans.map((plan) => _buildPlanCard(plan as Map<String, dynamic>)),
                  ],
                ),
    );
  }
}
