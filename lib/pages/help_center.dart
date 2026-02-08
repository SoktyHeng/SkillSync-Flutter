import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            title: 'Contact Support',
            icon: Icons.support_agent,
            children: [
              _buildContactItem(
                context,
                icon: Icons.email,
                title: 'Email Support',
                subtitle: 'support@skillsync.com',
                onTap: () => _launchEmail('support@skillsync.com'),
              ),
              _buildContactItem(
                context,
                icon: Icons.chat,
                title: 'Live Chat',
                subtitle: 'Available 9 AM - 6 PM',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Live chat coming soon!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'Legal',
            icon: Icons.gavel,
            children: [
              _buildResourceItem(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy policy coming soon!'),
                    ),
                  );
                },
              ),
              _buildResourceItem(
                context,
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Terms of service coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'App Version 1.0.0',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildContactItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildResourceItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=SkillSync Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
}
