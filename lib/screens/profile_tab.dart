import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/common.dart';
import 'doctor/availability_editor_screen.dart';
import 'invoices_screen.dart';
import 'settings_screen.dart';

class ProfileTab extends StatelessWidget {
  final String uid;
  const ProfileTab({super.key, required this.uid});

  Future<void> _edit(
      BuildContext context, Map<String, dynamic> data, String role) async {
    final name = TextEditingController(text: '${data['name'] ?? ''}');
    final phone = TextEditingController(text: '${data['phone'] ?? ''}');
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit profile'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: validateName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: validatePhone,
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
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await AuthService.updateProfile(uid, role, name.text, phone.text);
      if (context.mounted) showMsg(context, 'Profile updated');
    } catch (e) {
      if (context.mounted) {
        showMsg(context, AuthService.message(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: DB.userStream(uid),
      builder: (context, snap) {
        final data = snap.data?.data() ?? <String, dynamic>{};
        final role = '${data['role'] ?? 'patient'}';
        final name = '${data['name'] ?? ''}';
        final gender = '${data['gender'] ?? ''}';
        final dob = '${data['dob'] ?? ''}';
        return Centered(
          maxWidth: 560,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              Center(child: InitialsAvatar(name, radius: 44)),
              const SizedBox(height: 12),
              Center(
                child: Text(role == 'doctor' ? _drPrefix(name) : name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Chip(
                  label: Text(role == 'doctor' ? 'Doctor' : 'Patient'),
                  backgroundColor: kPrimary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 16),

              // Personal details card
              Card(
                child: Column(
                  children: [
                    ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text('${data['email'] ?? ''}')),
                    const Divider(height: 1),
                    ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Phone'),
                        subtitle: Text('${data['phone'] ?? ''}')),
                    const Divider(height: 1),
                    ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Gender'),
                        subtitle: Text(gender.isEmpty ? 'Not set' : gender)),
                    const Divider(height: 1),
                    ListTile(
                        leading: const Icon(Icons.cake_outlined),
                        title: const Text('Date of Birth'),
                        subtitle: Text(dob.isEmpty
                            ? 'Not set'
                            : dob.length >= 10
                                ? dob.substring(0, 10)
                                : dob)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick actions
              OutlinedButton.icon(
                onPressed:
                    data.isEmpty ? null : () => _edit(context, data, role),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
              ),
              const SizedBox(height: 10),
              if (role == 'doctor') ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    final doc = await DB.getDoctor(uid);
                    if (!context.mounted) return;
                    if (doc == null) return;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AvailabilityEditorScreen(doctor: doc)));
                  },
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Manage Availability'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DoctorInvoicesScreen(doctorId: uid))),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Billing & Invoices'),
                ),
                const SizedBox(height: 10),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => InvoicesScreen(patientId: uid))),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('My Invoices'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Settings'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _drPrefix(String n) =>
      n.toLowerCase().startsWith('dr') ? n : 'Dr. $n';
}
