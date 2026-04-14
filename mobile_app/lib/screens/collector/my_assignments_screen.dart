import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/collector_provider.dart';

class MyAssignmentsScreen extends StatefulWidget {
  const MyAssignmentsScreen({super.key});

  @override
  State<MyAssignmentsScreen> createState() => _MyAssignmentsScreenState();
}

class _MyAssignmentsScreenState extends State<MyAssignmentsScreen> {
  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double? _assignmentLatitude(Map<String, dynamic> assignment) {
    return _asDouble(assignment['latitude'] ?? assignment['lat']);
  }

  double? _assignmentLongitude(Map<String, dynamic> assignment) {
    return _asDouble(assignment['longitude'] ?? assignment['lng']);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssignments(context);
    });
  }

  Future<void> _loadAssignments(BuildContext context) async {
    final provider = Provider.of<CollectorProvider>(context, listen: false);
    await provider.fetchMyAssignments();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CollectorProvider>(context);
    final assignments = provider.assignments;
    final assignedCount = assignments.where((a) => (a['status'] ?? '') == 'assigned').length;
    final inProgressCount = assignments.where((a) => (a['status'] ?? '') == 'in_progress').length;
    final totalCount = assignments.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assignments'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(provider.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _loadAssignments(context),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : assignments.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'No assignments yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check nearby reports to accept assignments',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadAssignments(context),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                // Summary Card
                Card(
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Assigned', '$assignedCount', Colors.orange),
                        _buildStat('In Progress', '$inProgressCount', Colors.blue),
                        _buildStat('Total', '$totalCount', Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Current Assignments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...assignments.map((assignment) {
                  final status = (assignment['status'] ?? 'assigned').toString();
                  final address = (assignment['address_description'] ?? assignment['address'] ?? 'Unknown location').toString();
                  final assignedRaw = assignment['assigned_at'] ?? assignment['assignedAt'];
                  final assignedAt = assignedRaw is DateTime
                      ? assignedRaw
                      : DateTime.tryParse(assignedRaw?.toString() ?? '') ?? DateTime.now();
                  final amount = assignment['payment_amount'] ?? assignment['amount'] ?? 0;
                  final volume = (assignment['estimated_volume'] ?? assignment['volume'] ?? '-').toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(status)
                                .withOpacity(0.2),
                            child: Icon(
                              _getStatusIcon(status),
                              color: _getStatusColor(status),
                            ),
                          ),
                          title: Text(address),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Volume: $volume'),
                              Text(
                                'Assigned: ${DateFormat.yMMMd().add_jm().format(assignedAt)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getStatusText(status),
                                style: TextStyle(
                                  color: _getStatusColor(status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/assignment-details',
                              arguments: {
                                'assignmentId': assignment['id']?.toString(),
                                'id': assignment['id'],
                                'status': status,
                                'amount': amount,
                                'address': address,
                                'landmark': assignment['resident']?['area'] ?? 'Area not provided',
                                'reportedAt': assignedAt,
                                'volume': volume,
                                'garbageType': assignment['garbage_type'] ?? 'mixed',
                                'distanceKm': assignment['distance_km'] ?? 0,
                                'etaMinutes': assignment['eta_minutes'] ?? 0,
                                'latitude': _assignmentLatitude(assignment),
                                'longitude': _assignmentLongitude(assignment),
                              },
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    final lat = _assignmentLatitude(assignment);
                                    final lng = _assignmentLongitude(assignment);
                                    if (lat != null && lng != null) {
                                      _showDirections(context, lat: lat, lng: lng);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Assignment location is unavailable')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.directions, size: 18),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Directions', maxLines: 1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
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

                                    _updateStatus(context, assignment['id'].toString(), status);
                                  },
                                  icon: Icon(status == 'in_progress' ? Icons.qr_code_scanner : Icons.check, size: 18),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _getActionText(status),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                ],
              ),
            ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'assigned':
        return Icons.assignment;
      case 'in_progress':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  String _getActionText(String status) {
    switch (status) {
      case 'assigned':
        return 'Start Collection';
      case 'in_progress':
        return 'Scan QR to Complete';
      default:
        return 'View';
    }
  }

  void _showDirections(BuildContext context, {required double lat, required double lng}) async {
    Navigator.pushNamed(
      context,
      '/collector-directions',
      arguments: {
        'latitude': lat,
        'longitude': lng,
      },
    );
  }

  Future<void> _updateStatus(BuildContext context, String reportId, String currentStatus) async {
    final newStatus = currentStatus == 'assigned' ? 'in_progress' : 'completed';
    final provider = Provider.of<CollectorProvider>(context, listen: false);
    final ok = await provider.updateAssignmentStatus(reportId: reportId, status: newStatus);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Status updated to "$newStatus"' : (provider.error ?? 'Failed to update status')),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );

    if (ok) {
      await provider.fetchMyAssignments();
    }
  }
}
