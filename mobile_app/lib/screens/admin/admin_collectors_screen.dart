import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';

class AdminCollectorsScreen extends StatefulWidget {
  const AdminCollectorsScreen({super.key});

  @override
  State<AdminCollectorsScreen> createState() => _AdminCollectorsScreenState();
}

class _AdminCollectorsScreenState extends State<AdminCollectorsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchCollectors();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh(BuildContext context) async {
    await context.read<AdminProvider>().fetchCollectors(
          search: _searchController.text.trim(),
        );
  }

  Future<void> _toggleCollectorStatus(
    BuildContext context,
    Map<String, dynamic> collector,
  ) async {
    final provider = context.read<AdminProvider>();
    final collectorId = collector['id']?.toString() ?? '';
    final currentStatus = collector['is_active'] == true;

    if (collectorId.isEmpty) return;

    final success = await provider.updateCollectorStatus(
      collectorId: collectorId,
      isActive: !currentStatus,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (!currentStatus ? 'Collector activated' : 'Collector deactivated')
              : (provider.error ?? 'Action failed'),
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    if (success) {
      await _refresh(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final collectors = provider.collectors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collectors Management'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, username, phone, area',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () => _refresh(context),
                ),
              ),
              onSubmitted: (_) => _refresh(context),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: provider.statusFilter == 'all',
                  onSelected: (_) => context.read<AdminProvider>().setStatusFilter('all'),
                ),
                ChoiceChip(
                  label: const Text('Active'),
                  selected: provider.statusFilter == 'active',
                  onSelected: (_) => context.read<AdminProvider>().setStatusFilter('active'),
                ),
                ChoiceChip(
                  label: const Text('Inactive'),
                  selected: provider.statusFilter == 'inactive',
                  onSelected: (_) => context.read<AdminProvider>().setStatusFilter('inactive'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (provider.isLoading) const Center(child: CircularProgressIndicator()),
            if (!provider.isLoading && provider.error != null)
              Text(
                provider.error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (!provider.isLoading && collectors.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('No collectors found.')),
              ),
            ...collectors.map((collector) {
              final isActive = collector['is_active'] == true;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.green.shade100 : Colors.red.shade100,
                    child: Icon(
                      Icons.local_shipping,
                      color: isActive ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(collector['full_name']?.toString() ?? 'Unknown'),
                  subtitle: Text(
                    '${collector['phone_number'] ?? '-'}\n'
                    'Assignments: ${collector['active_assignments'] ?? 0}',
                  ),
                  isThreeLine: true,
                  trailing: Switch(
                    value: isActive,
                    onChanged: (_) => _toggleCollectorStatus(context, collector),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
