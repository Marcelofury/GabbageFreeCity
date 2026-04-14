import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/collector_provider.dart';

class AssignmentDetailsScreen extends StatefulWidget {
  const AssignmentDetailsScreen({super.key});

  @override
  State<AssignmentDetailsScreen> createState() => _AssignmentDetailsScreenState();
}

class _AssignmentDetailsScreenState extends State<AssignmentDetailsScreen> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final assignmentId = args?['assignmentId']?.toString() ?? args?['id']?.toString();
    final provider = Provider.of<CollectorProvider>(context, listen: false);

    if (provider.assignments.isEmpty ||
        (assignmentId != null && provider.findAssignmentById(assignmentId) == null)) {
      provider.fetchMyAssignments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final provider = Provider.of<CollectorProvider>(context);
    final assignmentId = args?['assignmentId']?.toString() ?? args?['id']?.toString();
    final found = assignmentId != null ? provider.findAssignmentById(assignmentId) : null;

    final assignment = _composeAssignmentMap(found, args) ??
        {
          'id': 'A-1024',
          'status': 'assigned',
          'amount': 5000,
          'address': 'Nakawa Market Area',
          'landmark': 'Near MTN service point',
          'reportedAt': DateTime.now().subtract(const Duration(hours: 3)),
          'volume': 'medium',
          'garbageType': 'mixed',
          'distanceKm': 1.8,
          'etaMinutes': 12,
        };

    if (provider.isLoading && found == null && assignmentId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Assignment Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = (assignment['status'] ?? 'assigned').toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Assignment Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assignment #${assignment['id']}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _StatusChip(status: status),
                      ],
                    ),
                  ),
                  Text(
                    'UGX ${assignment['amount']}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: 'Report Information',
            icon: Icons.description_outlined,
            children: [
              _buildRow('Address', assignment['address']?.toString() ?? '-'),
              _buildRow('Landmark', assignment['landmark']?.toString() ?? '-'),
              _buildRow('Volume', assignment['volume']?.toString() ?? '-'),
              _buildRow('Garbage Type', assignment['garbageType']?.toString() ?? '-'),
              _buildRow('Reported At', _formatDateTime(assignment['reportedAt'])),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: 'Location',
            icon: Icons.location_on_outlined,
            children: [
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Map preview (integration ready)'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildRow('Distance', '${assignment['distanceKm'] ?? 0} km'),
              _buildRow('ETA', '${assignment['etaMinutes'] ?? 0} mins'),
              _buildRow('Coordinates', '${assignment['latitude'] ?? '-'}, ${assignment['longitude'] ?? '-'}'),
            ],
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: 'Timeline',
            icon: Icons.timeline,
            children: [
              _timelineItem('Assigned', true),
              _timelineItem('Accepted', status != 'assigned'),
              _timelineItem('Started', status == 'in_progress' || status == 'completed'),
              _timelineItem('Completed', status == 'completed'),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final lat = _asDouble(assignment['latitude']);
                  final lng = _asDouble(assignment['longitude']);
                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Location unavailable for this assignment')),
                    );
                    return;
                  }

                  Navigator.pushNamed(
                    context,
                    '/collector-directions',
                    arguments: {
                      'latitude': lat,
                      'longitude': lng,
                      'address': assignment['address']?.toString() ?? 'Resident location',
                    },
                  );
                },
                icon: const Icon(Icons.directions),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Directions', maxLines: 1),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (status == 'in_progress') {
                    Navigator.pushNamed(
                      context,
                      '/qr-scanner',
                      arguments: {
                        'reportId': assignment['id']?.toString(),
                        'fromAssignment': true,
                      },
                    );
                    return;
                  }

                  final action = status == 'assigned' ? 'start' : 'complete';
                  _confirmAction(context, action, assignment['id'].toString());
                },
                icon: Icon(status == 'in_progress' ? Icons.qr_code_scanner : Icons.check),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    status == 'assigned' ? 'Start Collection' : 'Scan QR to Complete',
                    maxLines: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem(String label, bool isDone) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value is DateTime) {
      return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return value?.toString() ?? '-';
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _confirmAction(BuildContext context, String action, String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'start' ? 'Start Collection' : 'Mark Complete'),
        content: Text(
          action == 'start'
              ? 'Do you want to start this collection now?'
              : 'Confirm this assignment has been completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final provider = Provider.of<CollectorProvider>(context, listen: false);
              final status = action == 'start' ? 'in_progress' : 'completed';
              final ok = await provider.updateAssignmentStatus(
                reportId: reportId,
                status: status,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? (action == 'start' ? 'Collection started' : 'Marked complete')
                      : (provider.error ?? 'Failed to update status')),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );

              if (ok && context.mounted) {
                await provider.fetchMyAssignments();
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _composeAssignmentMap(
    Map<String, dynamic>? assignment,
    Map<String, dynamic>? args,
  ) {
    if (assignment == null) {
      return args;
    }

    final assignedRaw = assignment['assigned_at'];
    final assignedAt = DateTime.tryParse(assignedRaw?.toString() ?? '') ?? DateTime.now();

    return {
      'id': assignment['id'],
      'status': assignment['status'] ?? 'assigned',
      'amount': assignment['payment_amount'] ?? 0,
      'address': assignment['address_description'] ?? 'Unknown location',
      'landmark': args?['landmark'] ?? 'Nearby landmark',
      'reportedAt': assignedAt,
      'volume': assignment['estimated_volume'] ?? '-',
      'garbageType': assignment['garbage_type'] ?? 'mixed',
      'distanceKm': args?['distanceKm'] ?? 0,
      'etaMinutes': args?['etaMinutes'] ?? 0,
      'latitude': assignment['latitude'] ?? args?['latitude'],
      'longitude': assignment['longitude'] ?? args?['longitude'],
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'in_progress':
        color = Colors.blue;
        label = 'In Progress';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      default:
        color = Colors.orange;
        label = 'Assigned';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
