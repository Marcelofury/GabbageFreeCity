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

      if (!mounted) return;

      if (plansResponse['success'] != true) {
        throw Exception(plansResponse['message'] ?? 'Failed to load plans');
      }

      if (subscriptionResponse['success'] != true) {
        throw Exception(subscriptionResponse['message'] ?? 'Failed to load subscription');
      }

      setState(() {
        _plans = (plansResponse['data']?['plans'] as List?) ?? [];
        _activeSubscription = subscriptionResponse['data']?['subscription'];
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment initiated. Please approve on your phone.')),
        );
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

  Widget _buildActiveCard() {
    if (_activeSubscription == null) {
      return const SizedBox.shrink();
    }

    final plan = _activeSubscription?['plan'] as Map<String, dynamic>?;
    final endDate = _activeSubscription?['end_date']?.toString() ?? '-';
    final remaining = _activeSubscription?['remaining_collections']?.toString() ?? '0';

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
