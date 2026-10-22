import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../prescriptions_screen.dart';
import '../record_view_screen.dart';
import 'doctor_profile_screen.dart';
import 'search_doctors_screen.dart';

class PatientDashboard extends StatelessWidget {
  final String uid;
  final String name;
  final ValueChanged<int> onSwitchTab;
  const PatientDashboard({
    super.key,
    required this.uid,
    required this.name,
    required this.onSwitchTab,
  });

  void _openSearch(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const SearchDoctorsScreen()));

  Widget _quick(BuildContext context, IconData icon, String label,
      VoidCallback onTap) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: kPrimary),
                ),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Centered(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hi, ${firstName(name)} 👋',
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text('Take care of your health today!',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 14),
          TextField(
            readOnly: true,
            onTap: () => _openSearch(context),
            decoration: const InputDecoration(
              hintText: 'Search doctors, specialities...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SectionTitle('Quick Actions'),
          Row(
            children: [
              _quick(context, Icons.event_available, 'Book\nAppointment',
                  () => _openSearch(context)),
              const SizedBox(width: 10),
              _quick(context, Icons.folder_shared, 'Medical\nRecords',
                  () => onSwitchTab(2)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _quick(
                  context,
                  Icons.medication,
                  'Prescriptions',
                  () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PrescriptionsScreen(patientId: uid)))),
              const SizedBox(width: 10),
              _quick(context, Icons.calendar_month, 'My\nAppointments',
                  () => onSwitchTab(1)),
            ],
          ),
          const SectionTitle('Upcoming Appointment'),
          StreamBuilder<List<Appointment>>(
            stream: DB.patientAppointments(uid),
            builder: (context, snap) {
              final upcoming =
                  (snap.data ?? []).where((a) => a.isActive).toList();
              if (!snap.hasData) {
                return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()));
              }
              if (upcoming.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No upcoming appointments. Book one now!'),
                  ),
                );
              }
              return AppointmentCard(
                  a: upcoming.first, onTap: () => onSwitchTab(1));
            },
          ),
          SectionTitle('Top Doctors',
              trailing: TextButton(
                  onPressed: () => _openSearch(context),
                  child: const Text('View all'))),
          ValueListenableBuilder<Map<String, List<Map<String, dynamic>>>>(
            valueListenable: DoctorProfileScreen.sessionReviews,
            builder: (context, reviewsMap, _) {
              return StreamBuilder<List<Doctor>>(
                stream: DB.doctors(),
                builder: (context, snap) {
                  final docs = [...(snap.data ?? <Doctor>[])];
                  
                  double getRating(Doctor d) {
                    final local = reviewsMap[d.id] ?? [];
                if (local.isEmpty) return d.rating;
                double total = d.rating * d.reviewCount;
                for (final r in local) {
                  total += (r['rating'] as num).toDouble();
                }
                return double.parse((total / (d.reviewCount + local.length)).toStringAsFixed(1));
              }

              docs.sort((a, b) => getRating(b).compareTo(getRating(a)));
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No doctors have registered yet. Register a doctor account to see them here.'),
                  ),
                );
              }
              return SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: docs.length > 6 ? 6 : docs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    return SizedBox(
                      width: 120,
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      DoctorProfileScreen(doctor: d))),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                InitialsAvatar(d.name, radius: 24),
                                const SizedBox(height: 6),
                                Text(drName(d.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                                Text(d.specialization,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.star,
                                        size: 14, color: Colors.amber),
                                    Text(' ${getRating(d)}',
                                        style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
            },
          ),
          SectionTitle('Recent Records',
              trailing: TextButton(
                  onPressed: () => onSwitchTab(2),
                  child: const Text('View all'))),
          StreamBuilder<List<Snap>>(
            stream: DB.records(uid),
            builder: (context, snap) {
              final items = (snap.data ?? []).take(2).toList();
              if (items.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No medical records yet.'),
                  ),
                );
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
        ],
      ),
    );
  }
}
