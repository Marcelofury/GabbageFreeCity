import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/collector_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final provider = Provider.of<CollectorProvider>(context, listen: false);
    await provider.fetchCollectionHistory();
  }

  Future<void> _changePeriod(String period) async {
    final provider = Provider.of<CollectorProvider>(context, listen: false);
    await provider.setHistoryPeriod(period);
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CollectorProvider>(context);
    final history = provider.collectionHistory;
    final totalManagedValue = history.fold<int>(
      0,
      (sum, item) => sum + _asInt(item['payment_amount']),
    );
    final totalPackages = history.fold<int>(
      0,
      (sum, item) => sum + _asInt(item['package_count']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection History'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(provider.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatColumn(
                              'Collections',
                              '${history.length}',
                              Icons.check_circle,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          Expanded(
                            child: _buildStatColumn(
                              'Managed Value',
                              'UGX $totalManagedValue',
                              Icons.account_balance_wallet,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 50,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          Expanded(
                            child: _buildStatColumn(
                              'Packages',
                              '$totalPackages',
                              Icons.inventory_2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('This Week'),
                            selected: provider.historyPeriod == 'week',
                            onSelected: (_) => _changePeriod('week'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('This Month'),
                            selected: provider.historyPeriod == 'month',
                            onSelected: (_) => _changePeriod('month'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('All Time'),
                            selected: provider.historyPeriod == 'all',
                            onSelected: (_) => _changePeriod('all'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: history.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.history_toggle_off, size: 56, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No completed collections for this filter',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadHistory,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: history.length,
                                itemBuilder: (context, index) {
                                  final item = history[index];
                                  final address = (item['address_description'] ?? 'Unknown location').toString();
                                  final completedAt = _asDate(item['completed_at']);
                                  final packages = _asInt(item['package_count']);
                                  final amount = _asInt(item['payment_amount']);
                                  final residentArea = (item['resident']?['area'] ?? 'Area not provided').toString();
                                  final log = item['collection_log'] as Map<String, dynamic>?;
                                  final scheduledDays = (log?['scheduled_days'] ?? 'Custom').toString();
                                  final outOfSchedule = log?['out_of_schedule'] == true;
                                  final qrScanned = log?['qr_code_scanned'] == true;

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.green.shade100,
                                        child: const Icon(Icons.check, color: Colors.green),
                                      ),
                                      title: Text(
                                        address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            completedAt != null
                                                ? DateFormat.yMMMd().add_jm().format(completedAt)
                                                : 'Completion date unavailable',
                                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 4),
                                          Text('Packages: $packages | Area: $residentArea'),
                                          Text('Schedule: $scheduledDays | QR: ${qrScanned ? 'Yes' : 'No'}'),
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
                                            'UGX $amount',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          Text(
                                            'ID: ${item['id']}',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _showCollectionDetails(context, item),
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }

  void _showCollectionDetails(BuildContext context, Map<String, dynamic> item) {
    final completedAt = _asDate(item['completed_at']);
    final log = item['collection_log'] as Map<String, dynamic>?;
    final scheduledDays = (log?['scheduled_days'] ?? 'Custom').toString();
    final outOfSchedule = log?['out_of_schedule'] == true;
    final qrScanned = log?['qr_code_scanned'] == true;

    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (item['address_description'] ?? 'Unknown location').toString(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Report ID', '${item['id']}'),
            _buildDetailRow('Packages', '${_asInt(item['package_count'])}'),
            _buildDetailRow('Amount', 'UGX ${_asInt(item['payment_amount'])}'),
            _buildDetailRow('Schedule', scheduledDays),
            _buildDetailRow('QR Scanned', qrScanned ? 'Yes' : 'No'),
            _buildDetailRow('Out of Schedule', outOfSchedule ? 'Yes' : 'No'),
            _buildDetailRow(
              'Completed',
              completedAt != null
                  ? DateFormat.yMMMd().add_jm().format(completedAt)
                  : 'Unavailable',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
