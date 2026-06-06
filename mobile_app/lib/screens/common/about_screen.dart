import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About KCCA'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      size: 64,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Kampala Capital City Authority',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Garbage Free City Initiative',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Our Mission',
              content:
                  'To deliver accountable, technology-enabled waste management for Kampala residents through accurate reporting, fair pricing, and traceable collection workflows.',
              icon: Icons.flag,
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'How It Works',
                content:
                  '1. Choose a subscription plan (1x or 2x weekly collection)\n'
                  '2. Pay monthly or 3 months in advance using Mobile Money via MarzPay\n'
                  '3. Report collection using package count when needed\n'
                  '4. Collector is assigned and completes with resident QR verification\n'
                  '5. Track status and history from your report details',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 16),
            _buildSection(
                title: 'Current Subscription Pricing',
                content:
                  '1x weekly (4 collections/month): UGX 30,000\n'
                  '2x weekly (8 collections/month): UGX 60,000\n\n'
                  '3 months prepaid:\n'
                  '1x weekly = UGX 90,000\n'
                  '2x weekly = UGX 180,000\n\n'
                  'Collections are recorded in packages.',
              icon: Icons.money,
            ),
            const SizedBox(height: 16),
            _buildSection(
              title: 'Operational Integrity Features',
              content:
                  '• Admin oversight for collector management\n'
                  '• Location-based collector assignment\n'
                  '• Final collection confirmation by QR scan\n'
                  '• In-app notifications and report history\n'
                  '• Receipt visibility for paid reports',
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactTile(
              icon: Icons.phone,
              title: 'Call Center',
              subtitle: '+256 800 800 800',
              onTap: () => _launchPhone('+256800800800'),
            ),
            _buildContactTile(
              icon: Icons.email,
              title: 'Email',
              subtitle: 'info@kcca.go.ug',
              onTap: () => _launchEmail('info@kcca.go.ug'),
            ),
            _buildContactTile(
              icon: Icons.web,
              title: 'Website',
              subtitle: 'www.kcca.go.ug',
              onTap: () => _launchUrl('https://www.kcca.go.ug'),
            ),
            _buildContactTile(
              icon: Icons.location_on,
              title: 'Address',
              subtitle: 'City Hall, Kampala, Uganda',
              onTap: null,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    'App Version 1.0.0',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2026 KCCA. All rights reserved.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: const TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.shade100,
        child: Icon(icon, color: Colors.green),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap != null
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : null,
      onTap: onTap,
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
