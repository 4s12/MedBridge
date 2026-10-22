import 'package:flutter/material.dart';

import '../../models.dart';
import '../../services/db_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../invoices_screen.dart';
import '../notifications_screen.dart';
import '../profile_tab.dart';
import 'availability_editor_screen.dart';
import 'doctor_dashboard.dart';
import 'patients_tab.dart';
import 'requests_tab.dart';

class DoctorHome extends StatefulWidget {
  final String uid;
  final String name;
  const DoctorHome({super.key, required this.uid, required this.name});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  int _index = 0;

  static const _titles = [
    'Doctor Dashboard',
    'Appointment Requests',
    'My Patients',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.start(widget.uid);
  }

  @override
  void dispose() {
    NotificationService.stop();
    super.dispose();
  }

  void _openAvailability() async {
    final doc = await DB.getDoctor(widget.uid);
    if (!mounted) return;
    if (doc == null) {
      showMsg(context, 'Could not load your profile.', error: true);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AvailabilityEditorScreen(doctor: doc)));
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: _titles[_index],
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      actions: [
        // Availability shortcut in AppBar
        if (_index == 0) ...[
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'Manage Availability',
            onPressed: _openAvailability,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'View Invoices',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DoctorInvoicesScreen(doctorId: widget.uid))),
          ),
        ],
        NotificationBell(uid: widget.uid),
      ],
      items: const [
        NavItem(Icons.dashboard_outlined, 'Dashboard'),
        NavItem(Icons.inbox_outlined, 'Requests'),
        NavItem(Icons.people_outline, 'Patients'),
        NavItem(Icons.person_outline, 'Profile'),
      ],
      pages: [
        DoctorDashboard(
          uid: widget.uid,
          name: widget.name,
          onSwitchTab: (i) => setState(() => _index = i),
        ),
        RequestsTab(uid: widget.uid),
        PatientsTab(uid: widget.uid),
        ProfileTab(uid: widget.uid),
      ],
    );
  }
}
