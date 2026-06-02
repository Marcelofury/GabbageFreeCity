import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/admin_provider.dart';

class AdminCollectionsScreen extends StatefulWidget {
  const AdminCollectionsScreen({super.key});

  @override
  State<AdminCollectionsScreen> createState() => _AdminCollectionsScreenState();
}

class _AdminCollectionsScreenState extends State<AdminCollectionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchCollections();
    });
  }

  Future<void> _changePeriod(String period) async {
    await context.read<AdminProvider>().fetchCollections(period: period);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _asDate(dynamic value) {
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  String _scheduleLabel(Map<String, dynamic> item) {
    final log = item['collection_log'] as Map<String, dynamic>?;
    return (log?['scheduled_days'] ?? 'Custom').toString();
  }

  bool _outOfSchedule(Map<String, dynamic> item) {
    final log = item['collection_log'] as Map<String, dynamic>?;
    return log?['out_of_schedule'] == true;
  }

  bool _qrScanned(Map<String, dynamic> item) {
    final log = item['collection_log'] as Map<String, dynamic>?;
    return log?['qr_code_scanned'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminProvider>();
    final collections = provider.collections;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections Proof'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => provider.fetchCollections(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        provider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const Text(
                    'Collection Records',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('This Week'),
                          selected: provider.collectionPeriod == 'week',
                          onSelected: (_) => _changePeriod('week'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('This Month'),
                          selected: provider.collectionPeriod == 'month',
                          onSelected: (_) => _changePeriod('month'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('All Time'),
                          selected: provider.collectionPeriod == 'all',
                          onSelected: (_) => _changePeriod('all'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (collections.isEmpty)
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.history_toggle_off, size: 56, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          const Text('No collections found for this filter'),
                        ],
                      ),
                    )
                  else
                    ...collections.map((item) {
                      final resident = item['resident'] as Map<String, dynamic>?;
                      final collector = item['collector'] as Map<String, dynamic>?;
                      final completedAt = _asDate(item['completed_at']);
                      final scheduledDays = _scheduleLabel(item);
                      final outOfSchedule = _outOfSchedule(item);
                      final qrScanned = _qrScanned(item);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: outOfSchedule ? Colors.orange.shade100 : Colors.green.shade100,
                            child: Icon(
                              outOfSchedule ? Icons.warning_amber_rounded : Icons.check_circle,
                              color: outOfSchedule ? Colors.orange : Colors.green,
                            ),
                          ),
                          title: Text((item['address_description'] ?? 'Unknown location').toString()),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Resident: ${resident?['full_name'] ?? '-'}'),
                              Text('Collector: ${collector?['full_name'] ?? '-'}'),
                              Text('Schedule: $scheduledDays'),
                              Text('QR Scanned: ${qrScanned ? 'Yes' : 'No'}'),
                              if (outOfSchedule)
                                const Text(
                                  'Completed outside schedule',
                                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'UGX ${_asInt(item['payment_amount'])}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              Text(
                                completedAt != null
                                    ? DateFormat.yMMMd().add_jm().format(completedAt)
                                    : 'Date unavailable',
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                textAlign: TextAlign.right,
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
}
