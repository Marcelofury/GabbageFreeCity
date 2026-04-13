import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CollectorProfileScreen extends StatefulWidget {
  const CollectorProfileScreen({super.key});

  @override
  State<CollectorProfileScreen> createState() => _CollectorProfileScreenState();
}

class _CollectorProfileScreenState extends State<CollectorProfileScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _available = true;
  Map<String, dynamic> _stats = {
    'assigned_count': 0,
    'in_progress_count': 0,
    'completed_count': 0,
    'managed_value_ugx': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.getCollectorProfile();
    if (!mounted) return;

    if (response['success'] == true) {
      final profile = Map<String, dynamic>.from(response['data']?['profile'] ?? {});
      final stats = Map<String, dynamic>.from(response['data']?['stats'] ?? {});

      _fullNameController.text = profile['full_name']?.toString() ?? '';
      _areaController.text = profile['area']?.toString() ?? '';

      setState(() {
        _available = profile['is_active'] == true;
        _stats = {
          'assigned_count': stats['assigned_count'] ?? 0,
          'in_progress_count': stats['in_progress_count'] ?? 0,
          'completed_count': stats['completed_count'] ?? 0,
          'managed_value_ugx': stats['managed_value_ugx'] ?? 0,
        };
        _isLoading = false;
      });

      return;
    }

    setState(() {
      _error = response['message']?.toString() ?? 'Failed to load profile';
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final response = await _apiService.updateCollectorProfile(
      fullName: _fullNameController.text.trim(),
      area: _areaController.text.trim(),
      isActive: _available,
    );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile settings saved')), 
      );
      await _loadProfile();
      return;
    }

    setState(() {
      _error = response['message']?.toString() ?? 'Failed to save profile';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile & Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
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
                  Chip(
                    label: Text(_available ? 'Active' : 'Inactive'),
                    avatar: Icon(
                      _available ? Icons.check_circle : Icons.pause_circle,
                      color: _available ? Colors.green : Colors.orange,
                      size: 18,
                    ),
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
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatItem(label: 'Assigned', value: '${_stats['assigned_count'] ?? 0}'),
                  _StatItem(label: 'In Progress', value: '${_stats['in_progress_count'] ?? 0}'),
                  _StatItem(label: 'Completed', value: '${_stats['completed_count'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Payments Managed (Central Wallet)'),
              subtitle: Text('UGX ${_stats['managed_value_ugx'] ?? 0}'),
            ),
          ),
          const SizedBox(height: 12),
          _sectionTitle('Profile'),
          TextField(
            controller: _fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _areaController,
            decoration: const InputDecoration(
              labelText: 'Area',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 8),
          _sectionTitle('Operations'),
          SwitchListTile(
            value: _available,
            title: const Text('Availability'),
            subtitle: const Text('Receive assignments while active'),
            onChanged: (v) => setState(() => _available = v),
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
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save Settings'),
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
