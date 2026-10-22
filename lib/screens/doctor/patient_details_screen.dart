import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../add_record_screen.dart';
import '../chat_screen.dart';
import '../prescriptions_screen.dart';
import '../record_view_screen.dart';
import 'create_prescription_screen.dart';

class PatientDetailsScreen extends StatelessWidget {
  final String patientId;
  final String patientName;
  const PatientDetailsScreen(
      {super.key, required this.patientId, required this.patientName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(patientName)),
      body: Centered(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile
            StreamBuilder(
              stream: DB.userStream(patientId),
              builder: (context, snap) {
                final m = snap.data?.data() ?? <String, dynamic>{};
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        InitialsAvatar(patientName, radius: 30),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(patientName,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              Text('${m['email'] ?? ''}'),
                              Text('${m['phone'] ?? ''}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => AddRecordScreen(
                                patientId: patientId,
                                patientName: patientName,
                                byDoctor: true))),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Add diagnosis'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => CreatePrescriptionScreen(
                                patientId: patientId,
                                patientName: patientName))),
                    icon: const Icon(Icons.medication),
                    label: const Text('Prescription'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final cId = DB.chatId(patientId, DB.uid);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(
                            chatId: cId,
                            otherName: patientName,
                            myId: DB.uid,
                            myName: DB.myName,
                          )));
                },
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Chat with Patient'),
              ),
            ),

            // Appointments with this doctor
            const SectionTitle('Appointments with you'),
            StreamBuilder<List<Appointment>>(
              stream: DB.doctorAppointments(DB.uid),
              builder: (context, snap) {
                final list = (snap.data ?? [])
                    .where((a) => a.patientId == patientId)
                    .toList()
                    .reversed
                    .toList();
                if (list.isEmpty) {
                  return const Card(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No appointments.')));
                }
                return Column(
                  children: [
                    for (final a in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppointmentCard(a: a, showPatient: true),
                      ),
                  ],
                );
              },
            ),

            // Records
            const SectionTitle('Medical records'),
            StreamBuilder<List<Snap>>(
              stream: DB.records(patientId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Card(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Could not load records.')));
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Card(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No records.')));
                }
                return Column(
                  children: [
                    for (final r in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                                r.data()['type'] == 'image'
                                    ? Icons.image
                                    : Icons.description,
                                color: kPrimary),
                            title: Text('${r.data()['title']}'),
                            subtitle: Text(tsText(r.data())),
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        RecordViewScreen(data: r.data()))),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Prescriptions issued by this doctor
            const SectionTitle('Your previous prescriptions'),
            StreamBuilder<List<Snap>>(
              stream: DB.prescriptions(patientId, doctorId: DB.uid),
              builder: (context, snap) {
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Card(
                      child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No prescriptions issued yet.')));
                }
                return Column(
                  children: [
                    for (final p in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PrescriptionCard(data: p.data()),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
