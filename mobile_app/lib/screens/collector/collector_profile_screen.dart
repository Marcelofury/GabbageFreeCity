import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class CollectorProfileScreen extends StatefulWidget {
  const CollectorProfileScreen({super.key});

  @override
  State<CollectorProfileScreen> createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen> {
  bool _available = true;
  bool _autoAccept = false;
  bool _pushNotifications = true;
  bool _smsFallback = true;
  bool _appLock = false;
  double _radius = 5;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF2E7D32),
                    child: Icon(Icons.local_shipping, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'Collector',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(user?.phoneNumber ?? '-', style: TextStyle(color: Colors.grey[600])),
                        Text(
                          user?.area ?? 'Kampala Division',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const Chip(
                    label: Text('Verified'),
                    avatar: Icon(Icons.verified, color: Colors.green, size: 18),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _StatItem(label: 'Jobs', value: '42'),
                  _StatItem(label: 'Rating', value: '4.8'),
                  _StatItem(label: 'Week UGX', value: '95K'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Operations'),
          SwitchListTile(
            value: _available,
            title: const Text('Availability'),
            subtitle: const Text('Receive assignments while active'),
            onChanged: (v) => setState(() => _available = v),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Preferred Radius'),
            subtitle: Text('${_radius.toStringAsFixed(0)} km'),
          ),
          Slider(
            value: _radius,
            min: 1,
            max: 20,
            divisions: 19,
            label: '${_radius.toStringAsFixed(0)} km',
            onChanged: (v) => setState(() => _radius = v),
          ),
          SwitchListTile(
            value: _autoAccept,
            title: const Text('Auto-accept assignments'),
            onChanged: (v) => setState(() => _autoAccept = v),
          ),
          const SizedBox(height: 8),
          _sectionTitle('Notifications'),
          SwitchListTile(
            value: _pushNotifications,
            title: const Text('Push Notifications'),
            onChanged: (v) => setState(() => _pushNotifications = v),
          ),
          SwitchListTile(
            value: _smsFallback,
            title: const Text('SMS Fallback'),
            onChanged: (v) => setState(() => _smsFallback = v),
          ),
          const SizedBox(height: 8),
          _sectionTitle('Privacy & Security'),
          SwitchListTile(
            value: _appLock,
            title: const Text('App Lock'),
            onChanged: (v) => setState(() => _appLock = v),
          ),
          const SizedBox(height: 8),
          _sectionTitle('Support'),
          const ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Help Center'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.bug_report_outlined),
            title: Text('Report Issue'),
            trailing: Icon(Icons.chevron_right),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Terms & Privacy'),
            trailing: Icon(Icons.chevron_right),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              await authProvider.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('App Version 1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings saved locally (API pending)')),
            );
          },
          child: const Text('Save Settings'),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
