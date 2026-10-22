import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models.dart';
import '../../services/db_service.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../chat_screen.dart';
import 'book_appointment_screen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Doctor doctor;
  const DoctorProfileScreen({super.key, required this.doctor});

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

  void _openChat(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final cId = DB.chatId(me.uid, widget.doctor.id);
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(
              chatId: cId,
              otherName: drName(widget.doctor.name),
              myId: me.uid,
              myName: me.displayName ?? 'Patient',
            )));
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Message doctor',
            onPressed: () => _openChat(context),
          ),
        ],
      ),
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

            // Stats row — uses live review count from Firestore
            StreamBuilder<List<Snap>>(
              stream: DB.doctorReviews(doctor.id),
              builder: (context, snap) {
                final reviews = snap.data ?? [];
                double avgRating = doctor.rating;
                int reviewCount = doctor.reviewCount;
                if (reviews.isNotEmpty) {
                  double total = 0;
                  for (final r in reviews) {
                    total += (r.data()['rating'] as num?)?.toDouble() ?? 0;
                  }
                  reviewCount = reviews.length;
                  avgRating = double.parse(
                      (total / reviewCount).toStringAsFixed(1));
                }
                return Row(
                  children: [
                    _stat(Icons.workspace_premium,
                        '${doctor.experienceYears}+ yrs', 'Experience'),
                    const SizedBox(width: 10),
                    _stat(Icons.star, '$avgRating', '$reviewCount reviews'),
                    const SizedBox(width: 10),
                    _stat(Icons.currency_rupee, '${doctor.fee}',
                        'Consultation'),
                  ],
                );
              },
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

            // Reviews section — fully database-backed
            StreamBuilder<List<Snap>>(
              stream: DB.doctorReviews(doctor.id),
              builder: (context, snap) {
                final reviews = snap.data ?? [];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      'Patient Reviews',
                      trailing: TextButton.icon(
                        onPressed: () => _showReviewDialog(context, doctor),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Review'),
                      ),
                    ),
                    if (reviews.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No reviews yet. Be the first to review!'),
                        ),
                      )
                    else
                      for (final r in reviews.take(10))
                        _ReviewCard(data: r.data()),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => BookAppointmentScreen(doctor: doctor))),
                icon: const Icon(Icons.event_available),
                label: const Text('Book Appointment'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openChat(context),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Message Doctor'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, Doctor doctor) {
    showDialog(
        context: context,
        builder: (_) => _ReviewDialog(doctor: doctor));
  }
}

// ────────────────────────────────────────────
// Review card widget
// ────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReviewCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rating = (data['rating'] as num?)?.toDouble() ?? 0;
    final name = (data['patientName'] ?? '').toString();
    final comment = (data['comment'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name, radius: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Row(
                    children: List.generate(5, (i) {
                      return Icon(
                        i < rating
                            ? (rating - i >= 1
                                ? Icons.star
                                : Icons.star_half)
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                ],
              ),
              if (comment.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(comment),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// Review Dialog
// ────────────────────────────────────────────
class _ReviewDialog extends StatefulWidget {
  final Doctor doctor;
  const _ReviewDialog({required this.doctor});

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  double _rating = 5.0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final me = FirebaseAuth.instance.currentUser;
      await DB.addReview(
        doctorId: widget.doctor.id,
        patientId: me?.uid ?? DB.uid,
        patientName: me?.displayName ?? DB.myName,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        showMsg(context, 'Review submitted successfully!');
      }
    } catch (e) {
      setState(() {
        _error = 'Could not submit review. Please try again.';
        _submitting = false;
      });
    }
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
                  final dx = details.localPosition.dx;
                  setState(() => _rating = i + (dx < 24 ? 0.5 : 1.0));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
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
          const SizedBox(height: 8),
          Text('$_rating stars',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Write your experience (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Submit'),
        ),
      ],
    );
  }
}
