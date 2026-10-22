import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'book_appointment_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Doctor doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

  // Store local reviews per doctor so they persist until app restart/logout
  static final ValueNotifier<Map<String, List<Map<String, dynamic>>>> sessionReviews = ValueNotifier({});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {

  Widget _stat(IconData icon, String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: kPrimary),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, List<Map<String, dynamic>>>>(
      valueListenable: DoctorProfileScreen.sessionReviews,
      builder: (context, reviewsMap, _) {
        final doctor = widget.doctor;
        final localDocReviews = reviewsMap[doctor.id] ?? [];
        
        double currentRating = doctor.rating;
    int currentCount = doctor.reviewCount;
    if (localDocReviews.isNotEmpty) {
      double total = doctor.rating * doctor.reviewCount;
      for (final r in localDocReviews) {
        total += (r['rating'] as num).toDouble();
      }
      currentCount += localDocReviews.length;
      currentRating = double.parse((total / currentCount).toStringAsFixed(1));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Profile')),
      body: Centered(
        maxWidth: 640,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: InitialsAvatar(doctor.name, radius: 50)),
            const SizedBox(height: 12),
            Text(drName(doctor.name),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(doctor.specialization,
                textAlign: TextAlign.center,
                style: const TextStyle(color: kPrimary, fontSize: 16)),
            const SizedBox(height: 4),
            Text(doctor.hospital,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            if (doctor.isVerified) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 4),
                  Text('Verified Doctor',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _stat(Icons.workspace_premium, '${doctor.experienceYears}+ yrs',
                    'Experience'),
                const SizedBox(width: 10),
                _stat(Icons.star, '$currentRating',
                    '$currentCount reviews'),
                const SizedBox(width: 10),
                _stat(Icons.currency_rupee, '${doctor.fee}', 'Consultation'),
              ],
            ),
            const SectionTitle('About'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    doctor.about.isEmpty ? 'No details provided.' : doctor.about,
                    style: const TextStyle(height: 1.4)),
              ),
            ),

            // Reviews
            SectionTitle(
              'Patient Reviews',
              trailing: TextButton.icon(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (_) => _ReviewDialog(
                            doctor: doctor,
                              onReviewAdded: (review) {
                                final map = Map<String, List<Map<String, dynamic>>>.from(DoctorProfileScreen.sessionReviews.value);
                                if (map[doctor.id] == null) {
                                  map[doctor.id] = [];
                                }
                                map[doctor.id]!.insert(0, review);
                                DoctorProfileScreen.sessionReviews.value = map;
                            },
                          ));
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Review'),
              ),
            ),
            StreamBuilder<List<Snap>>(
              stream: DB.doctorReviews(doctor.id),
              builder: (context, snap) {
                final dbReviews = snap.data ?? [];
                
                // Combine local reviews with database reviews
                final List<dynamic> allReviews = [
                  ...localDocReviews.map((r) => {'data': () => r}),
                  ...dbReviews
                ];

                if (allReviews.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No reviews yet.'),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final r in allReviews.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    InitialsAvatar(
                                        '${r is Map ? r['data']()['patientName'] : r.data()['patientName']}',
                                        radius: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('${r is Map ? r['data']()['patientName'] : r.data()['patientName']}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    Row(
                                      children: List.generate(5, (i) {
                                        final rating =
                                            (r is Map ? r['data']()['rating'] : (r.data()['rating'] as num?))
                                                    ?.toDouble() ??
                                                0;
                                        return Icon(
                                          i < rating
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 16,
                                          color: Colors.amber,
                                        );
                                      }),
                                    ),
                                  ],
                                ),
                                if ('${r is Map ? (r['data']()['comment'] ?? '') : (r.data()['comment'] ?? '')}'.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text('${r is Map ? r['data']()['comment'] : r.data()['comment']}'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            BookAppointmentScreen(doctor: doctor))),
                icon: const Icon(Icons.event_available),
                label: const Text('Book Appointment'),
              ),
            ),
          ],
        ),
      ),
    ); // Scaffold
      }, // builder
    ); // ValueListenableBuilder
  } // build
} // _DoctorProfileScreenState

class _ReviewDialog extends StatefulWidget {
  final Doctor doctor;
  final Function(Map<String, dynamic>) onReviewAdded;
  const _ReviewDialog({required this.doctor, required this.onReviewAdded});
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  double _rating = 5.0;
  final _commentCtrl = TextEditingController();

  void _submit() {
    widget.onReviewAdded({
      'patientName': DB.myName,
      'rating': _rating,
      'comment': _commentCtrl.text.trim(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Leave a Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTapDown: (details) {
                  // A 32px icon + 8px padding on each side = 48px width. Middle is ~24px.
                  final dx = details.localPosition.dx;
                  setState(() => _rating = i + (dx < 24 ? 0.5 : 1.0));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Icon(
                    _rating >= i + 1.0
                        ? Icons.star
                        : _rating >= i + 0.5
                            ? Icons.star_half
                            : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your experience (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
