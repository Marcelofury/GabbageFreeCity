import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
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
              childAspectRatio: 1.35,
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
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.groups),
                title: const Text('Manage Collectors'),
                subtitle: const Text('Activate/deactivate and review collector workload'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/admin-collectors'),
              ),
            ),
          ],
        ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
