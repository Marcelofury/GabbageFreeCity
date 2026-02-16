import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class MyAssignmentsScreen extends StatelessWidget {
  const MyAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock data for demonstration
    final mockAssignments = [
      {
        'id': '1',
        'address': 'Nakawa Market Area',
        'volume': 'medium',
        'status': 'assigned',
        'amount': 5000,
        'assignedAt': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'id': '2',
        'address': 'Ntinda Shopping Center',
        'volume': 'small',
        'status': 'in_progress',
        'amount': 3000,
        'assignedAt': DateTime.now().subtract(const Duration(days: 1)),
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assignments'),
      ),
      body: mockAssignments.isEmpty
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
          : ListView(
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
                        _buildStat('Active', '1', Colors.orange),
                        _buildStat('In Progress', '1', Colors.blue),
                        _buildStat('Completed', '0', Colors.green),
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
                ...mockAssignments.map((assignment) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(assignment['status'] as String)
                                .withOpacity(0.2),
                            child: Icon(
                              _getStatusIcon(assignment['status'] as String),
                              color: _getStatusColor(assignment['status'] as String),
                            ),
                          ),
                          title: Text(assignment['address'] as String),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Volume: ${assignment['volume']}'),
                              Text(
                                'Assigned: ${DateFormat.yMMMd().add_jm().format(assignment['assignedAt'] as DateTime)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'UGX ${assignment['amount']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getStatusText(assignment['status'] as String),
                                style: TextStyle(
                                  color: _getStatusColor(assignment['status'] as String),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    _showDirections(context);
                                  },
                                  icon: const Icon(Icons.directions, size: 18),
                                  label: const Text('Directions'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    _updateStatus(context, assignment['status'] as String);
                                  },
                                  icon: const Icon(Icons.check, size: 18),
                                  label: Text(
                                    _getActionText(assignment['status'] as String),
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
        return 'Mark Complete';
      default:
        return 'View';
    }
  }

  void _showDirections(BuildContext context) async {
    // Mock coordinates - in real app, get from assignment
    const lat = 0.3476;
    const lng = 32.6169;
    
    // Use OpenStreetMap for directions
    final url = Uri.parse('https://www.openstreetmap.org/directions?to=$lat,$lng');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Opening OpenStreetMap directions...'),
              action: SnackBarAction(
                label: 'Coordinates',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location: $lat, $lng'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Directions to: $lat, $lng'),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  void _updateStatus(BuildContext context, String currentStatus) {
    final newStatus = currentStatus == 'assigned' ? 'in_progress' : 'completed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status update to "$newStatus" - API integration pending'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
