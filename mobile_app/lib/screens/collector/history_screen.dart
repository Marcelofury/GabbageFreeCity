import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock completed collections
    final completedCollections = [
      {
        'id': '001',
        'address': 'Nakawa Market Area',
        'completedAt': DateTime.now().subtract(const Duration(days: 1)),
        'amount': 5000,
        'volume': 'medium',
        'rating': 5,
      },
      {
        'id': '002',
        'address': 'Ntinda Shopping Center',
        'completedAt': DateTime.now().subtract(const Duration(days: 3)),
        'amount': 3000,
        'volume': 'small',
        'rating': 4,
      },
      {
        'id': '003',
        'address': 'Bukoto Street',
        'completedAt': DateTime.now().subtract(const Duration(days: 5)),
        'amount': 10000,
        'volume': 'large',
        'rating': 5,
      },
      {
        'id': '004',
        'address': 'Kamwokya Shopping Area',
        'completedAt': DateTime.now().subtract(const Duration(days: 7)),
        'amount': 5000,
        'volume': 'medium',
        'rating': 5,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection History'),
      ),
      body: Column(
        children: [
          // Stats Card
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
                    'Total\nCollections',
                    '${completedCollections.length}',
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
                    'Total\nEarnings',
                    'UGX ${_calculateTotal(completedCollections)}',
                    Icons.monetization_on,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildStatColumn(
                    'Avg\nRating',
                    '${_calculateAvgRating(completedCollections).toStringAsFixed(1)} ⭐',
                    Icons.star,
                  ),
                ),
              ],
            ),
          ),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('This Week'),
                  selected: true,
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('This Month'),
                  selected: false,
                  onSelected: (_) {},
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All Time'),
                  selected: false,
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // History list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: completedCollections.length,
              itemBuilder: (context, index) {
                final collection = completedCollections[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: const Icon(Icons.check, color: Colors.green),
                    ),
                    title: Text(
                      collection['address'] as String,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.yMMMd().add_jm().format(
                            collection['completedAt'] as DateTime,
                          ),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Volume: ${collection['volume']}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...List.generate(
                              collection['rating'] as int,
                              (i) => const Icon(Icons.star, size: 14, color: Colors.orange),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 80,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'UGX ${collection['amount']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'ID: ${collection['id']}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    onTap: () => _showCollectionDetails(context, collection),
                  ),
                );
              },
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
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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
          overflow: TextOverflow.visible,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _calculateTotal(List<Map<String, dynamic>> collections) {
    final total = collections.fold<int>(
      0,
      (sum, item) => sum + (item['amount'] as int),
    );
    return total.toString();
  }

  double _calculateAvgRating(List<Map<String, dynamic>> collections) {
    if (collections.isEmpty) return 0;
    final total = collections.fold<int>(
      0,
      (sum, item) => sum + (item['rating'] as int),
    );
    return total / collections.length;
  }

  void _showCollectionDetails(BuildContext context, Map<String, dynamic> collection) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collection['address'] as String,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Collection ID: ${collection['id']}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow('Volume', collection['volume'] as String),
            _buildDetailRow('Amount', 'UGX ${collection['amount']}'),
            _buildDetailRow(
              'Completed',
              DateFormat.yMMMd().add_jm().format(
                collection['completedAt'] as DateTime,
              ),
            ),
            _buildDetailRow(
              'Rating',
              '${collection['rating']} stars',
            ),
            const SizedBox(height: 20),
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
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
