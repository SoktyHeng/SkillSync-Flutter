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
                    const SnackBar(
                      content: Text('Live chat is not available at the moment.'),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            title: 'Legal',
            children: [
              _buildResourceItem(
                context,
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _LegalPage(
                      title: 'Privacy Policy',
                      content: _privacyPolicyText,
                    ),
                  ),
                ),
              ),
              _buildResourceItem(
                context,
                icon: Icons.description,
                title: 'Terms of Service',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _LegalPage(
                      title: 'Terms of Service',
                      content: _termsOfServiceText,
                    ),
                  ),
                ),
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

const String _privacyPolicyText = '''
Last updated: February 2026

1. Information We Collect
We collect information you provide directly, such as your name, email address, and profile details when you create an account. We also collect usage data to improve our services.

2. How We Use Your Information
We use collected information to provide and maintain the SkillSync service, personalize your experience, communicate updates, and improve our platform.

3. Data Sharing
We do not sell your personal information. We may share data with service providers who assist in operating our platform, subject to confidentiality agreements.

4. Data Security
We implement industry-standard security measures to protect your information. However, no method of electronic transmission is 100% secure.

5. Your Rights
You may access, update, or delete your personal information at any time through your account settings. You may also contact us to request data export.

6. Contact Us
If you have questions about this Privacy Policy, please contact us at support@skillsync.com.
''';

const String _termsOfServiceText = '''
Last updated: February 2026

1. Acceptance of Terms
By accessing or using SkillSync, you agree to be bound by these Terms of Service. If you do not agree, please do not use the service.

2. User Accounts
You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.

3. Acceptable Use
You agree not to misuse the platform, including but not limited to: uploading harmful content, impersonating others, or attempting to gain unauthorized access.

4. Intellectual Property
All content and materials on SkillSync are owned by or licensed to us. You retain ownership of content you create and share on the platform.

5. Termination
We reserve the right to suspend or terminate accounts that violate these terms or engage in harmful behavior.

6. Limitation of Liability
SkillSync is provided "as is" without warranties. We are not liable for any indirect, incidental, or consequential damages arising from your use of the service.

7. Contact Us
For questions about these Terms, please contact us at support@skillsync.com.
''';

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          content,
          style: const TextStyle(fontSize: 15, height: 1.6),
        ),
      ),
    );
  }
}
