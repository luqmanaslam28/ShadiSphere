import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../consumer/presentation/consumer_providers.dart';

// SRS §3.3: Bidirectional Transactional Booking Flow
// 5-Stage Lifecycle: Assembly → Dispatch → Alerting → Evaluation → Update

enum BookingStage {
  assembly,      // User building the cart / finalizing selections
  dispatch,      // Global booking inquiry executed, split per vendor
  alerting,      // Vendor notification sent (FCM + in-app)
  evaluation,    // Merchant reviewing within 48-hour window
  update,        // Final status communicated back to client
}

class Booking {
  final String id;
  final String? transactionId;
  final String consumerId;
  final String consumerName;
  final String vendorId;
  final String vendorName;
  final String category;
  final double amount;
  final BookingStage stage;
  final String status; // 'pending', 'accepted', 'rejected', 'expired'
  final DateTime createdAt;
  final DateTime? evaluationDeadline; // 48-hour window
  final String? eventDate;
  final String? notes;
  final int? numberOfGuests;

  const Booking({
    required this.id,
    this.transactionId,
    required this.consumerId,
    required this.consumerName,
    required this.vendorId,
    required this.vendorName,
    required this.category,
    required this.amount,
    required this.stage,
    required this.status,
    required this.createdAt,
    this.evaluationDeadline,
    this.eventDate,
    this.notes,
    this.numberOfGuests,
  });

  factory Booking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Booking(
      id: doc.id,
      transactionId: data['transactionId'] as String?,
      consumerId: data['consumerId'] ?? '',
      consumerName: data['consumerName'] ?? 'Unknown',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown',
      category: data['category'] ?? 'Uncategorized',
      amount: (data['amount'] ?? 0).toDouble(),
      stage: BookingStage.values[data['stage'] ?? 0],
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      evaluationDeadline: (data['evaluationDeadline'] as Timestamp?)?.toDate(),
      eventDate: data['eventDate'],
      notes: data['notes'],
      numberOfGuests: data['numberOfGuests'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'consumerId': consumerId,
      'consumerName': consumerName,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'category': category,
      'amount': amount,
      'stage': stage.index,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'evaluationDeadline': evaluationDeadline != null ? Timestamp.fromDate(evaluationDeadline!) : null,
      'eventDate': eventDate,
      'notes': notes,
      'numberOfGuests': numberOfGuests,
    };
  }

  Booking copyWith({
    BookingStage? stage,
    String? status,
    DateTime? evaluationDeadline,
  }) {
    return Booking(
      id: id,
      consumerId: consumerId,
      consumerName: consumerName,
      vendorId: vendorId,
      vendorName: vendorName,
      category: category,
      amount: amount,
      stage: stage ?? this.stage,
      status: status ?? this.status,
      createdAt: createdAt,
      evaluationDeadline: evaluationDeadline ?? this.evaluationDeadline,
      eventDate: eventDate,
      notes: notes,
      numberOfGuests: numberOfGuests,
    );
  }

  String get stageLabel {
    switch (stage) {
      case BookingStage.assembly: return 'Assembling';
      case BookingStage.dispatch: return 'Dispatched';
      case BookingStage.alerting: return 'Vendor Notified';
      case BookingStage.evaluation: return 'Under Review';
      case BookingStage.update: return status == 'accepted' ? 'Confirmed' : status == 'rejected' ? 'Declined' : 'Updated';
    }
  }

  Duration? get timeRemaining {
    if (evaluationDeadline == null) return null;
    final remaining = evaluationDeadline!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

// Consumer-side bookings stream
final consumerBookingsProvider = StreamProvider<List<Booking>>((ref) {
  final uid = ref.watch(authProvider).userId;
  if (uid == null || uid.isEmpty) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('consumerId', isEqualTo: uid)
      .snapshots()
      .asyncMap((snapshot) async {
        final list = snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList();

        // Cross-check with vendor_inquiries to sync cancelled status
        final updatedList = <Booking>[];
        for (final booking in list) {
          final st = booking.status.toLowerCase();
          if (st == 'cancelled' || st == 'rejected') {
            continue; // Filter out cancelled bookings
          }

          if (st == 'confirmed' || st == 'accepted' || st == 'booked') {
            bool isCancelledInInquiries = false;
            try {
              final inqSnap = await FirebaseFirestore.instance
                  .collection('vendor_inquiries')
                  .where('vendorId', isEqualTo: booking.vendorId)
                  .where('consumerId', isEqualTo: uid)
                  .get();

              for (final inqDoc in inqSnap.docs) {
                final inqStatus = inqDoc.data()['status']?.toString().toLowerCase() ?? '';
                if (inqStatus == 'cancelled' || inqStatus == 'rejected') {
                  final inqDate = inqDoc.data()['eventDate']?.toString() ?? inqDoc.data()['detail']?.toString() ?? inqDoc.data()['date']?.toString() ?? '';
                  final bDate = booking.eventDate ?? '';
                  final normInqDate = normalizeSingleDate(inqDate);
                  final normBDate = normalizeSingleDate(bDate);
                  if (normInqDate != null && normBDate != null && normInqDate == normBDate) {
                    isCancelledInInquiries = true;
                    // Auto-update stale booking doc in Firestore
                    FirebaseFirestore.instance.collection('bookings').doc(booking.id).update({'status': 'Cancelled'});
                    break;
                  }
                }
              }
            } catch (e) {
              print("Error checking inquiry status: $e");
            }

            if (isCancelledInInquiries) {
              continue; // Exclude from active confirmed bookings list
            }
          }

          updatedList.add(booking);
        }

        updatedList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return updatedList;
      })
      .handleError((_) => <Booking>[]);
});

// Vendor-side bookings stream
final vendorBookingsProvider = StreamProvider.family<List<Booking>, String>((ref, vendorId) {
  return FirebaseFirestore.instance
      .collection('bookings')
      .where('vendorId', isEqualTo: vendorId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => Booking.fromFirestore(doc)).toList());
});

// SRS §3.3 Stage 1: Assembly — Execute Global Booking Inquiry
Future<String> createBookingInquiry({
  required String consumerId,
  required String consumerName,
  required String vendorId,
  required String vendorName,
  required String category,
  required double amount,
  String? eventDate,
  String? notes,
  int? numberOfGuests,
}) async {
  final bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
  final now = DateTime.now();
  
  final booking = Booking(
    id: bookingRef.id,
    consumerId: consumerId,
    consumerName: consumerName,
    vendorId: vendorId,
    vendorName: vendorName,
    category: category,
    amount: amount,
    stage: BookingStage.dispatch, // Skip assembly, go directly to dispatch
    status: 'pending',
    createdAt: now,
    evaluationDeadline: now.add(const Duration(hours: 48)), // SRS: 48-hour window
    eventDate: eventDate,
    notes: notes,
    numberOfGuests: numberOfGuests,
  );

  await bookingRef.set(booking.toFirestore());

  // SRS §3.3 Stage 3: Create notification for vendor
  await FirebaseFirestore.instance.collection('notifications').add({
    'userId': vendorId,
    'title': 'New Booking Inquiry!',
    'message': '$consumerName has requested a booking for $category — Rs. ${amount.toStringAsFixed(0)}',
    'time': Timestamp.fromDate(now),
    'isRead': false,
    'type': 'booking',
  });

  return bookingRef.id;
}

// SRS §3.3 Stage 4: Merchant Evaluation — Accept
Future<void> acceptBooking(String bookingId) async {
  final doc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
  if (!doc.exists) return;

  await doc.reference.update({
    'stage': BookingStage.update.index,
    'status': 'accepted',
  });

  final data = doc.data()!;
  final consumerId = data['consumerId'] as String?;
  final vendorName = data['vendorName'] as String? ?? 'A vendor';

  if (consumerId != null && consumerId.isNotEmpty) {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': consumerId,
      'title': 'Booking Approved',
      'message': '$vendorName has approved your booking inquiry!',
      'time': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'booking',
    });
  }
}

// SRS §3.3 Stage 4: Merchant Evaluation — Reject
Future<void> rejectBooking(String bookingId) async {
  final doc = await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();
  if (!doc.exists) return;

  await doc.reference.update({
    'stage': BookingStage.update.index,
    'status': 'rejected',
  });

  final data = doc.data()!;
  final consumerId = data['consumerId'] as String?;
  final vendorName = data['vendorName'] as String? ?? 'A vendor';

  if (consumerId != null && consumerId.isNotEmpty) {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': consumerId,
      'title': 'Booking Declined',
      'message': '$vendorName has declined your booking inquiry.',
      'time': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'booking',
    });
  }
}

// =========================================================
// SRS §3.2: Token-Based Collaborative Authorization
// =========================================================

class SharedInstance {
  final String id;
  final String token;
  final String creatorId;
  final String creatorName;
  final List<String> memberIds;
  final List<String> memberNames;
  final DateTime createdAt;

  const SharedInstance({
    required this.id,
    required this.token,
    required this.creatorId,
    required this.creatorName,
    required this.memberIds,
    required this.memberNames,
    required this.createdAt,
  });

  factory SharedInstance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SharedInstance(
      id: doc.id,
      token: data['token'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      memberNames: List<String>.from(data['memberNames'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// SRS: Cryptographic 8-character token
String generateCollaborativeToken() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random.secure();
  final code = List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  // Format: SS-XXXX-XXXX
  return 'SS-${code.substring(0, 4)}-${code.substring(4)}';
}

// Create shared wedding instance
Future<String> createSharedInstance({
  required String creatorId,
  required String creatorName,
}) async {
  final token = generateCollaborativeToken();
  final ref = FirebaseFirestore.instance.collection('shared_instances').doc();
  
  await ref.set({
    'token': token,
    'creatorId': creatorId,
    'creatorName': creatorName,
    'memberIds': [creatorId],
    'memberNames': [creatorName],
    'createdAt': Timestamp.fromDate(DateTime.now()),
  });

  return token;
}

// Join shared wedding instance by token
Future<bool> joinSharedInstance({
  required String token,
  required String userId,
  required String userName,
}) async {
  final query = await FirebaseFirestore.instance
      .collection('shared_instances')
      .where('token', isEqualTo: token)
      .limit(1)
      .get();

  if (query.docs.isEmpty) return false;

  final doc = query.docs.first;
  await doc.reference.update({
    'memberIds': FieldValue.arrayUnion([userId]),
    'memberNames': FieldValue.arrayUnion([userName]),
  });

  return true;
}
