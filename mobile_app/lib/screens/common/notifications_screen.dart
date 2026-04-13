import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/notification_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';
  bool _initialized = false;

  List<String> get _filters => ['All', 'Payments', 'Assignments', 'Reports', 'System'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final notifications = Provider.of<NotificationProvider>(context, listen: false);
    notifications.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notificationsProvider = Provider.of<NotificationProvider>(context);

    final visible = notificationsProvider.notifications.where((n) {
      if (_filter == 'All') return true;
      final rawType = (n['type'] ?? '').toString().toLowerCase();
      switch (_filter) {
        case 'Payments':
          return rawType == 'payment';
        case 'Assignments':
          return rawType == 'assignment';
        case 'Reports':
          return rawType == 'report' || rawType == 'collection';
        case 'System':
          return rawType == 'system';
        default:
          return true;
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await notificationsProvider.markAllAsRead();
            },
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final f = _filters[index];
                return ChoiceChip(
                  label: Text(f),
                  selected: f == _filter,
                  onSelected: (_) => setState(() => _filter = f),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => notificationsProvider.fetchNotifications(),
              child: notificationsProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : notificationsProvider.error != null
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 12),
                            Text(notificationsProvider.error!, textAlign: TextAlign.center),
                            const SizedBox(height: 10),
                            Center(
                              child: ElevatedButton(
                                onPressed: () => notificationsProvider.fetchNotifications(),
                                child: const Text('Retry'),
                              ),
                            ),
                          ],
                        )
                      : visible.isEmpty
                  ? ListView(children: [_emptyState()])
                  : ListView(
                      children: [
                        _group('Today', visible),
                        _group('Yesterday', visible),
                        _group('Earlier', visible),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(Map<String, dynamic> item) {
    final isRead = item['is_read'] == true;
    final id = item['id']?.toString();

    return Dismissible(
      key: ValueKey('${item['id'] ?? item['title']}'),
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.mark_email_read, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        setState(() {
          item['is_read'] = true;
        });

        if (id != null) {
          await Provider.of<NotificationProvider>(context, listen: false).markAsRead(id);
        }

        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _typeColor(item['type'].toString()).withOpacity(0.15),
          child: Icon(_typeIcon(item['type'].toString()), color: _typeColor(item['type'].toString())),
        ),
        title: Text(
          (item['title'] ?? 'Notification').toString(),
          style: TextStyle(fontWeight: isRead ? FontWeight.w500 : FontWeight.bold),
        ),
        subtitle: Text((item['message'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_timeLabel(item['created_at']?.toString()), style: const TextStyle(fontSize: 12)),
            if (!isRead)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
          ],
        ),
        onTap: () {
          if (id != null) {
            Provider.of<NotificationProvider>(context, listen: false).markAsRead(id);
          }

          final data = item['data'] is Map<String, dynamic>
              ? item['data'] as Map<String, dynamic>
              : <String, dynamic>{};
          final type = (item['type'] ?? '').toString();

          if (type == 'payment' || type == 'report' || type == 'collection') {
            final reportId = data['report_id']?.toString();
            if (reportId != null) {
              Navigator.pushNamed(context, '/report-details', arguments: {'reportId': reportId});
            }
          } else if (type == 'assignment') {
            final assignmentId = data['report_id']?.toString();
            if (assignmentId != null) {
              Navigator.pushNamed(context, '/assignment-details', arguments: {'assignmentId': assignmentId});
            }
          }
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text('No notifications yet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('You will see updates about reports, payments and assignments here.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'payment':
        return Icons.payment;
      case 'assignment':
        return Icons.assignment;
      case 'report':
      case 'collection':
        return Icons.delete_outline;
      default:
        return Icons.info_outline;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'payment':
        return Colors.green;
      case 'assignment':
        return Colors.orange;
      case 'report':
      case 'collection':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _timeLabel(String? isoDate) {
    final dt = DateTime.tryParse(isoDate ?? '');
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _dateGroupFromIso(String? isoDate) {
    final dt = DateTime.tryParse(isoDate ?? '') ?? DateTime.now();
    final now = DateTime.now();
    final dayDiff = DateTime(now.year, now.month, now.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;

    if (dayDiff == 0) return 'Today';
    if (dayDiff == 1) return 'Yesterday';
    return 'Earlier';
  }

  Widget _group(String title, List<Map<String, dynamic>> all) {
    final groupItems = all.where((e) => _dateGroupFromIso(e['created_at']?.toString()) == title).toList();
    if (groupItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        ...groupItems.map(_itemTile),
      ],
    );
  }
}
