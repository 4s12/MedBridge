import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants.dart';
import '../models.dart';

class SlotTakenException implements Exception {}

typedef Snap = QueryDocumentSnapshot<Map<String, dynamic>>;

/// All Firestore access lives here. Queries use a single equality filter and
/// sort on the device, so no composite indexes are needed.
class DB {
  DB._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> col(String name) =>
      _db.collection(name);

  static String get uid => FirebaseAuth.instance.currentUser!.uid;
  static String get myName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'User';

  // ---------- users / doctors ----------
  static Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String id) =>
      col('users').doc(id).snapshots();

  static Stream<List<Doctor>> doctors() => col('doctors')
      .snapshots()
      .map((s) => s.docs.map((d) => Doctor.fromDoc(d)).toList());

  // ---------- appointments ----------
  static List<Appointment> _toAppointments(
      QuerySnapshot<Map<String, dynamic>> s) {
    final l = s.docs.map((d) => Appointment.fromDoc(d)).toList();
    l.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return l;
  }

  static Stream<List<Appointment>> patientAppointments(String patientId) =>
      col('appointments')
          .where('patientId', isEqualTo: patientId)
          .snapshots()
          .map(_toAppointments);

  static Stream<List<Appointment>> doctorAppointments(String doctorId) =>
      col('appointments')
          .where('doctorId', isEqualTo: doctorId)
          .snapshots()
          .map(_toAppointments);

  /// Ids of slots already booked for a doctor on a given date.
  static Stream<Set<String>> bookedSlotKeys(String doctorId, String date) =>
      col('bookedSlots')
          .where('doctorId', isEqualTo: doctorId)
          .snapshots()
          .map((s) => s.docs
              .where((d) => d.data()['date'] == date)
              .map((d) => d.id)
              .toSet());

  /// Books an appointment. A transaction on the `bookedSlots` document makes
  /// sure two patients can never book the same doctor, date and time.
  static Future<Appointment> book({
    required Doctor doctor,
    required String patientId,
    required String patientName,
    required String date,
    required Slot slot,
  }) async {
    final key = makeSlotKey(doctor.id, date, slot);
    final slotRef = col('bookedSlots').doc(key);
    final apptRef = col('appointments').doc();
    final appt = Appointment(
      id: apptRef.id,
      patientId: patientId,
      patientName: patientName,
      doctorId: doctor.id,
      doctorName: doctor.name,
      specialization: doctor.specialization,
      hospital: doctor.hospital,
      date: date,
      timeSlot: slot.label,
      sortKey: '$date ${slot.time24}',
      slotKey: key,
      fee: doctor.fee,
      status: 'pending',
    );

    await _db.runTransaction((tx) async {
      final snap = await tx.get(slotRef);
      if (snap.exists) throw SlotTakenException();
      tx.set(slotRef, {
        'doctorId': doctor.id,
        'date': date,
        'timeSlot': slot.label,
        'appointmentId': apptRef.id,
      });
      tx.set(apptRef, {
        ...appt.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await notify(
      patientId,
      'Booking submitted',
      'Your appointment with ${drName(doctor.name)} on ${prettyDate(date)} at ${slot.label} is waiting for confirmation. ID: ${apptRef.id}',
      type: 'booking',
    );
    await notify(
      doctor.id,
      'New appointment request',
      '$patientName requested ${prettyDate(date)} at ${slot.label}.',
      type: 'request',
    );
    return appt;
  }

  static Future<void> changeStatus(Appointment a, String status) async {
    final batch = _db.batch();
    batch.update(col('appointments').doc(a.id), {'status': status});
    if (status == 'cancelled' || status == 'rejected') {
      batch.delete(col('bookedSlots').doc(a.slotKey));
    }
    await batch.commit();

    final dr = drName(a.doctorName);
    final when = '${prettyDate(a.date)} at ${a.timeSlot}';
    switch (status) {
      case 'accepted':
        await notify(a.patientId, 'Appointment confirmed',
            '$dr accepted your appointment on $when.',
            type: 'booking');
        break;
      case 'rejected':
        await notify(a.patientId, 'Appointment rejected',
            '$dr could not accept your appointment on $when. Please choose another slot.',
            type: 'booking');
        break;
      case 'completed':
        await notify(a.patientId, 'Appointment completed',
            'Your visit with $dr on $when is marked completed.',
            type: 'booking');
        break;
      case 'cancelled':
        await notify(a.doctorId, 'Appointment cancelled',
            '${a.patientName} cancelled the appointment on $when.',
            type: 'booking');
        break;
    }
  }

  // ---------- records ----------
  static List<Snap> _sortDesc(QuerySnapshot<Map<String, dynamic>> s) {
    final l = s.docs.toList();
    l.sort((a, b) => tsOf(b.data()).compareTo(tsOf(a.data())));
    return l;
  }

  static Stream<List<Snap>> records(String patientId) => col('records')
      .where('patientId', isEqualTo: patientId)
      .snapshots()
      .map(_sortDesc);

  static Future<void> addRecord({
    required String patientId,
    required String title,
    required String notes,
    required String addedBy,
    required String addedByName,
    required bool byDoctor,
    String? imageBase64,
  }) async {
    await col('records').add({
      'patientId': patientId,
      'title': title.trim(),
      'notes': notes.trim(),
      'type': imageBase64 == null ? 'note' : 'image',
      'imageBase64': imageBase64,
      'addedBy': addedBy,
      'addedByName': addedByName,
      'byDoctor': byDoctor,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (byDoctor) {
      await notify(patientId, 'New medical record',
          '${drName(addedByName)} added "${title.trim()}" to your records.',
          type: 'record');
    }
  }

  static Future<void> deleteRecord(String id) => col('records').doc(id).delete();

  // ---------- prescriptions ----------
  static Stream<List<Snap>> prescriptions(String patientId,
      {String? doctorId}) {
    Query<Map<String, dynamic>> q =
        col('prescriptions').where('patientId', isEqualTo: patientId);
    if (doctorId != null) {
      q = q.where('doctorId', isEqualTo: doctorId);
    }
    return q.snapshots().map(_sortDesc);
  }

  static Future<void> addPrescription({
    required String patientId,
    required String patientName,
    required String doctorId,
    required String doctorName,
    required List<Map<String, String>> medicines,
    required String instructions,
  }) async {
    await col('prescriptions').add({
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'medicines': medicines,
      'instructions': instructions.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await notify(patientId, 'New prescription',
        '${drName(doctorName)} issued a prescription for you.',
        type: 'prescription');
  }

  // ---------- notifications ----------
  static Future<void> notify(String userId, String title, String body,
      {String type = 'info'}) async {
    try {
      await col('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Stream<List<Snap>> notifications(String userId) =>
      col('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map(_sortDesc);

  static Future<void> markRead(String id) =>
      col('notifications').doc(id).update({'read': true});

  static Future<void> markAllRead(List<Snap> items) async {
    final batch = _db.batch();
    for (final d in items) {
      if (d.data()['read'] != true) {
        batch.update(d.reference, {'read': true});
      }
    }
    await batch.commit();
  }

  // ---------- chat ----------
  /// Deterministic chat ID for a patient-doctor pair.
  static String chatId(String patientId, String doctorId) {
    final ids = [patientId, doctorId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Stream of messages in a chat, ordered by timestamp.
  static Stream<List<ChatMessage>> chatMessages(String chatDocId) => col('chats')
      .doc(chatDocId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((s) => s.docs.map((d) => ChatMessage.fromDoc(d)).toList());

  /// Send a message in a chat.
  static Future<void> sendMessage({
    required String chatDocId,
    required String senderId,
    required String senderName,
    required String text,
    String? imageBase64,
  }) async {
    final chatRef = col('chats').doc(chatDocId);
    // Ensure the chat document exists.
    await chatRef.set({
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': FieldValue.arrayUnion([senderId]),
    }, SetOptions(merge: true));

    await chatRef.collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text.trim(),
      'imageBase64': imageBase64,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  // ---------- doctor availability ----------
  static Future<void> updateAvailability(
      String doctorId, Map<String, dynamic> availability) async {
    await col('doctors').doc(doctorId).update({'availability': availability});
  }

  // ---------- reviews ----------
  static Future<void> addReview({
    required String doctorId,
    required String patientId,
    required String patientName,
    required double rating,
    required String comment,
  }) async {
    await col('reviews').add({
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'rating': rating,
      'comment': comment.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      // Update doctor's average rating.
      final reviews = await col('reviews')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      if (reviews.docs.isNotEmpty) {
        double total = 0;
        for (final r in reviews.docs) {
          total += (r.data()['rating'] as num?)?.toDouble() ?? 0;
        }
        final avg = total / reviews.docs.length;
        await col('doctors').doc(doctorId).update({
          'rating': double.parse(avg.toStringAsFixed(1)),
          'reviewCount': reviews.docs.length,
        });
      }
    } catch (e) {
      print('Could not update doctor rating (Firebase Rules blocked it): $e');
    }
  }

  static Stream<List<Snap>> doctorReviews(String doctorId) => col('reviews')
      .where('doctorId', isEqualTo: doctorId)
      .snapshots()
      .map(_sortDesc);
}
