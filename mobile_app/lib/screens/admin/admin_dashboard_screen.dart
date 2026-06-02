import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<Map<String, dynamic>> _recentTransactions(List<Map<String, dynamic>> all) {
    return all.take(5).toList();
  }

  String _transactionRef(Map<String, dynamic> tx) {
    return (tx['reference'] ?? tx['transaction_ref'] ?? tx['uuid'] ?? tx['id'] ?? '-').toString();
  }

  String _transactionStatus(Map<String, dynamic> tx) {
    return (tx['status'] ?? tx['transactionStatus'] ?? tx['payment_status'] ?? 'unknown').toString();
  }

  String _transactionAmount(Map<String, dynamic> tx) {
    final amount = tx['amount'] ?? tx['totalAmount'] ?? tx['value'] ?? 0;
    return 'UGX ${_asInt(amount)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = context.watch<AdminProvider>();
    final dashboard = adminProvider.dashboard;
    final analytics = Map<String, dynamic>.from(dashboard['analytics'] ?? {});
    final transactions = _recentTransactions(adminProvider.transactions);
    final wallet = adminProvider.wallet;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await adminProvider.fetchDashboard();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Operations Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (adminProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  adminProvider.error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                _MetricCard(
                  title: 'Active Collectors',
                  value: '${dashboard['active_collectors'] ?? 0}',
                  icon: Icons.person_pin_circle,
                  color: Colors.green,
                ),
                _MetricCard(
                  title: 'Inactive Collectors',
                  value: '${dashboard['inactive_collectors'] ?? 0}',
                  icon: Icons.person_off,
                  color: Colors.red,
                ),
                _MetricCard(
                  title: 'Open Assignments',
                  value: '${dashboard['open_assignments'] ?? 0}',
                  icon: Icons.assignment_late,
                  color: Colors.orange,
                ),
                _MetricCard(
                  title: 'Collections Today',
                  value: '${dashboard['collections_today'] ?? 0}',
                  icon: Icons.check_circle,
                  color: Colors.blue,
                ),
                _MetricCard(
                  title: 'Reports Made',
                  value: '${dashboard['reports_made'] ?? 0}',
                  icon: Icons.assignment,
                  color: Colors.teal,
                ),
                _MetricCard(
                  title: 'Pending Reports',
                  value: '${dashboard['reports_pending'] ?? 0}',
                  icon: Icons.pending_actions,
                  color: Colors.amber.shade700,
                ),
                _MetricCard(
                  title: 'Accepted Reports',
                  value: '${dashboard['reports_accepted'] ?? 0}',
                  icon: Icons.task_alt,
                  color: Colors.indigo,
                ),
                _MetricCard(
                  title: 'Completed Reports',
                  value: '${dashboard['reports_completed'] ?? 0}',
                  icon: Icons.done_all,
                  color: Colors.green.shade700,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Financial Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Central Wallet Balance',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'UGX ${_asInt(wallet['balance'] ?? wallet['available_balance'] ?? 0)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if ((wallet['currency'] ?? '').toString().isNotEmpty)
                      Text('Currency: ${wallet['currency']}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analytics',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _analyticsRow('Completion Rate', '${_asDouble(analytics['completion_rate_percent']).toStringAsFixed(1)}%'),
                    _analyticsRow('Payment Success', '${_asInt(analytics['paid_transactions'])}'),
                    _analyticsRow('Successful Transactions', '${_asInt(analytics['successful_transactions'])}'),
                    _analyticsRow('Pending Payments', '${_asInt(analytics['pending_payments'])}'),
                    _analyticsRow('Failed Payments', '${_asInt(analytics['failed_payments'])}'),
                    _analyticsRow('Total Revenue', 'UGX ${_asInt(analytics['total_revenue_ugx'])}'),
                    _analyticsRow('Avg Completion Time', '${_asInt(analytics['average_completion_minutes'])} min'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (transactions.isEmpty)
                      const Text('No transactions available')
                    else
                      ...transactions.map(
                        (tx) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long),
                          title: Text(_transactionAmount(tx)),
                          subtitle: Text('Ref: ${_transactionRef(tx)}'),
                          trailing: Text(_transactionStatus(tx)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('Manage Collectors'),
                subtitle: const Text('Activate/deactivate and review collector workload'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/admin-collectors'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.fact_check),
                title: const Text('Collections Proof'),
                subtitle: const Text('Review QR-verified collection records'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/admin-collections'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _analyticsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Icon(icon, color: color),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
