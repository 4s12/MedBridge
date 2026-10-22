import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';

/// Settings screen with dark mode toggle, language, notifications,
/// change password, help center, and logout.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  Future<void> _changePassword() async {
    final currentPw = TextEditingController();
    final newPw = TextEditingController();
    final confirmPw = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPw,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Enter your current password'
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: newPw,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  helperText: 'Min 8 chars with uppercase, lowercase, digit & special',
                  helperMaxLines: 2,
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmPw,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) =>
                    v != newPw.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Change')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    try {
      await AuthService.changePassword(currentPw.text, newPw.text);
      if (mounted) showMsg(context, 'Password changed successfully');
    } catch (e) {
      if (mounted) showMsg(context, AuthService.message(e), error: true);
    }
  }

  Future<void> _logout() async {
    final yes = await confirmDialog(
        context, 'Logout', 'Do you want to log out of MedBridge?',
        yes: 'Logout');
    if (!yes || !mounted) return;
    // Capture the navigator before the async gap.
    final navigator = Navigator.of(context);
    await AuthService.logout();
    // Settings was pushed on top of AuthGate; pop back to the root route
    // so AuthGate (which now shows the Login screen) becomes visible.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.value == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Centered(
        maxWidth: 560,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Appearance
            const _SectionLabel('Appearance'),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark Mode'),
                subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active'),
                value: isDark,
                onChanged: (v) {
                  setDarkMode(v);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(height: 16),

            // Notifications
            const _SectionLabel('Notifications'),
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Push Notifications'),
                subtitle: const Text('Get appointment reminders and updates'),
                value: _notificationsEnabled,
                onChanged: (v) => setState(() => _notificationsEnabled = v),
              ),
            ),
            const SizedBox(height: 16),

            // Security
            const _SectionLabel('Security'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Support
            const _SectionLabel('Support'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help Center'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openUrl('https://medbridge.app/help'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openUrl('https://medbridge.app/privacy'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openUrl('https://medbridge.app/terms'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About
            const _SectionLabel('About'),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('MedBridge'),
                    subtitle:
                        Text('Version 1.0.0\nBridging Care. Connecting Lives.'),
                    isThreeLine: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600),
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
            letterSpacing: 0.5,
          )),
    );
  }
}
