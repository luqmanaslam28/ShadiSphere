import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../../core/services/notification_service.dart';

// --- Models ---

class VendorInquiry {
  final String id;
  final String clientName;
  final String date;
  final String detail;
  final String amount;
  final double numericAmount; // Pre-parsed numeric value for revenue calculations
  final String status; // "Pending", "Negotiating", "Accepted", "Completed", "Rejected", "User Accepted"
  final String? vendorId;
  final String? consumerId;
  final String? ledgerItemId;
  final String? ledgerCode;
  final DateTime? createdAt;

  const VendorInquiry({
    required this.id,
    required this.clientName,
    required this.date,
    required this.detail,
    required this.amount,
    this.numericAmount = 0.0,
    required this.status,
    this.vendorId,
    this.consumerId,
    this.ledgerItemId,
    this.ledgerCode,
    this.createdAt,
  });

  VendorInquiry copyWith({String? status, String? amount, double? numericAmount}) {
    return VendorInquiry(
      id: id,
      clientName: clientName,
      date: date,
      detail: detail,
      amount: amount ?? this.amount,
      numericAmount: numericAmount ?? this.numericAmount,
      status: status ?? this.status,
      vendorId: vendorId,
      consumerId: consumerId,
      ledgerItemId: ledgerItemId,
      ledgerCode: ledgerCode,
      createdAt: createdAt,
    );
  }

  /// Extract a numeric value from the raw Firestore 'amount' field.
  /// Tries: raw number first, then string parsing.
  static double _extractNumericAmount(dynamic rawAmount) {
    if (rawAmount == null) return 0.0;
    // If Firestore stored it as a number, use directly
    if (rawAmount is num) return rawAmount.toDouble();
    // Otherwise parse the string
    final str = rawAmount.toString();
    if (str.isEmpty) return 0.0;
    return _parseAmountString(str);
  }

  /// Robust parser for amount strings like "Rs. 1000000", "1,500,000", "50k", etc.
  static double _parseAmountString(String amountStr) {
    if (amountStr.isEmpty) return 0.0;
    String s = amountStr.toLowerCase().trim();
    bool hasK = s.contains('k');
    // Remove currency prefixes like "rs.", "rs", "pkr", "₨"
    s = s.replaceAll('rs.', '').replaceAll('rs', '').replaceAll('pkr', '');
    // Remove all non-digit, non-dot characters
    s = s.replaceAll(RegExp('[^0-9.]'), '');
    // Handle multiple dots (keep only first)
    final dotIndex = s.indexOf('.');
    if (dotIndex >= 0) {
      s = s.substring(0, dotIndex + 1) + s.substring(dotIndex + 1).replaceAll('.', '');
    }
    if (s.isEmpty) return 0.0;
    double val = double.tryParse(s) ?? 0.0;
    if (hasK) val *= 1000;
    return val;
  }

  static VendorInquiry fromFirestore(Map<String, dynamic> data, String id) {
    final rawAmount = data['amount'] ?? data['budget'] ?? data['price'] ?? data['totalCost'];
    final numAmt = _extractNumericAmount(rawAmount);
    return VendorInquiry(
      id: id,
      clientName: data['clientName']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      detail: data['detail']?.toString() ?? '',
      amount: rawAmount?.toString() ?? '0',
      numericAmount: numAmt,
      status: data['status']?.toString() ?? 'Pending',
      vendorId: data['vendorId']?.toString(),
      consumerId: data['consumerId']?.toString(),
      ledgerItemId: data['ledgerItemId']?.toString(),
      ledgerCode: data['ledgerCode']?.toString(),
      createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientName': clientName,
      'date': date,
      'detail': detail,
      'amount': amount,
      'status': status,
    };
  }
}

class CatalogPackage {
  final String id;
  final String name;
  final String price;
  final String pricingUnit;
  final String description;
  final String imageUrl;
  final String? vendorId;

  const CatalogPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.pricingUnit,
    required this.description,
    this.imageUrl = '',
    this.vendorId,
  });

  CatalogPackage copyWith({
    String? name,
    String? price,
    String? pricingUnit,
    String? description,
    String? imageUrl,
    String? vendorId,
  }) {
    return CatalogPackage(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      vendorId: vendorId ?? this.vendorId,
    );
  }

  static CatalogPackage fromFirestore(Map<String, dynamic> data, String id) {
    return CatalogPackage(
      id: id,
      name: data['name']?.toString() ?? '',
      price: data['price']?.toString() ?? '',
      pricingUnit: data['pricingUnit']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString() ?? '',
      vendorId: data['vendorId']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'pricingUnit': pricingUnit,
      'description': description,
      'imageUrl': imageUrl,
      if (vendorId != null) 'vendorId': vendorId,
    };
  }
}

class GenericSingleProduct {
  final String id;
  final String name;
  final double price;
  final String description;
  final String imageUrl;

  GenericSingleProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'imageUrl': imageUrl,
  };

  static GenericSingleProduct fromMap(Map<String, dynamic> data) => GenericSingleProduct(
    id: data['id']?.toString() ?? '',
    name: data['name']?.toString() ?? '',
    price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
    description: data['description']?.toString() ?? '',
    imageUrl: data['imageUrl']?.toString() ?? '',
  );
}

class GenericServicePackage {
  final String id;
  final String name;
  final double price;
  final String description;
  final List<String> items;
  final String imageUrl;

  GenericServicePackage({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.items,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'price': price,
    'description': description,
    'items': items,
    'imageUrl': imageUrl,
  };

  static GenericServicePackage fromMap(Map<String, dynamic> data) => GenericServicePackage(
    id: data['id']?.toString() ?? '',
    name: data['name']?.toString() ?? '',
    price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
    description: data['description']?.toString() ?? '',
    items: (data['items'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    imageUrl: data['imageUrl']?.toString() ?? '',
  );
}

class VendorProfile {
  final String businessName;
  final String location;
  final String category;
  final String bio;
  final String subscriptionTier;
  final String phone;
  final String email;
  final String website;
  final DateTime? subscriptionExpiry;
  final String accountStatus;
  final bool hasAcceptedTerms;
  
  // Venue-specific new fields
  final String ownerName;
  final String city;
  final int capacity;
  final double price;
  final bool isSetupComplete;
  final List<String> outsidePictures;
  final List<String> insidePictures;
  final double weekendPrice;
  final Map<String, double> specialPrices;
  final Map<String, double> beverages;
  final List<GenericSingleProduct> singleProducts;
  final List<GenericServicePackage> servicePackages;

  const VendorProfile({
    required this.businessName,
    required this.location,
    required this.category,
    required this.bio,
    this.subscriptionTier = 'free',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.subscriptionExpiry,
    this.accountStatus = 'active',
    this.hasAcceptedTerms = false,
    this.ownerName = '',
    this.city = '',
    this.capacity = 0,
    this.price = 0.0,
    this.isSetupComplete = false,
    this.outsidePictures = const [],
    this.insidePictures = const [],
    this.weekendPrice = 0.0,
    this.specialPrices = const {},
    this.beverages = const {},
    this.singleProducts = const [],
    this.servicePackages = const [],
  });

  VendorProfile copyWith({
    String? businessName,
    String? location,
    String? category,
    String? bio,
    String? subscriptionTier,
    String? phone,
    String? email,
    String? website,
    DateTime? subscriptionExpiry,
    String? accountStatus,
    bool? hasAcceptedTerms,
    String? ownerName,
    String? city,
    int? capacity,
    double? price,
    bool? isSetupComplete,
    List<String>? outsidePictures,
    List<String>? insidePictures,
    double? weekendPrice,
    Map<String, double>? specialPrices,
    Map<String, double>? beverages,
    List<GenericSingleProduct>? singleProducts,
    List<GenericServicePackage>? servicePackages,
  }) {
    return VendorProfile(
      businessName: businessName ?? this.businessName,
      location: location ?? this.location,
      category: category ?? this.category,
      bio: bio ?? this.bio,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      accountStatus: accountStatus ?? this.accountStatus,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      ownerName: ownerName ?? this.ownerName,
      city: city ?? this.city,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      outsidePictures: outsidePictures ?? this.outsidePictures,
      insidePictures: insidePictures ?? this.insidePictures,
      weekendPrice: weekendPrice ?? this.weekendPrice,
      specialPrices: specialPrices ?? this.specialPrices,
      beverages: beverages ?? this.beverages,
      singleProducts: singleProducts ?? this.singleProducts,
      servicePackages: servicePackages ?? this.servicePackages,
    );
  }

  static VendorProfile fromFirestore(Map<String, dynamic> data) {
    return VendorProfile(
      businessName: data['businessName']?.toString() ?? 'Business Name',
      location: data['location']?.toString() ?? 'Location',
      category: data['category']?.toString() ?? 'Venues',
      bio: data['bio']?.toString() ?? '',
      subscriptionTier: data['subscriptionTier']?.toString() ?? 'free',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      website: data['website']?.toString() ?? '',
      subscriptionExpiry: data['subscriptionExpiry'] != null ? DateTime.tryParse(data['subscriptionExpiry'].toString()) : null,
      accountStatus: data['accountStatus']?.toString() ?? 'active',
      hasAcceptedTerms: data['hasAcceptedTerms'] as bool? ?? true,
      ownerName: data['ownerName']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      capacity: int.tryParse(data['capacity']?.toString() ?? '0') ?? 0,
      price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
      isSetupComplete: data['isSetupComplete'] as bool? ?? false,
      outsidePictures: (data['outsidePictures'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      insidePictures: (data['insidePictures'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      weekendPrice: double.tryParse(data['weekendPrice']?.toString() ?? '0') ?? 0.0,
      specialPrices: (data['specialPrices'] as Map<String, dynamic>?)?.map((key, value) => MapEntry(key, double.tryParse(value.toString()) ?? 0.0)) ?? {},
      beverages: (data['beverages'] as Map<String, dynamic>?)?.map((key, value) => MapEntry(key, double.tryParse(value.toString()) ?? 0.0)) ?? {},
      singleProducts: (data['singleProducts'] as List<dynamic>?)?.map((e) => GenericSingleProduct.fromMap(e as Map<String, dynamic>)).toList() ?? [],
      servicePackages: (data['servicePackages'] as List<dynamic>?)?.map((e) => GenericServicePackage.fromMap(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class VendorReview {
  final String id;
  final String clientName;
  final String date;
  final double rating;
  final String comment;
  final String? reply;
  final String? vendorId;

  const VendorReview({
    required this.id,
    required this.clientName,
    required this.date,
    required this.rating,
    required this.comment,
    this.reply,
    this.vendorId,
  });

  VendorReview copyWith({String? reply, String? vendorId}) {
    return VendorReview(
      id: id,
      clientName: clientName,
      date: date,
      rating: rating,
      comment: comment,
      reply: reply ?? this.reply,
      vendorId: vendorId ?? this.vendorId,
    );
  }

  static VendorReview fromFirestore(Map<String, dynamic> data, String id) {
    return VendorReview(
      id: id,
      clientName: data['clientName']?.toString() ?? 'Unknown',
      date: data['date']?.toString() ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      comment: data['comment']?.toString() ?? '',
      reply: data['reply']?.toString(),
      vendorId: data['vendorId']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clientName': clientName,
      'date': date,
      'rating': rating,
      'comment': comment,
      'reply': reply,
      if (vendorId != null) 'vendorId': vendorId,
    };
  }
}

class VendorMessage {
  final String id;
  final String threadId;
  final String clientName;
  final String clientId;
  final String lastMessage;
  final String date;
  final int unreadCount;
  final String? vendorReply;
  final String? vendorId;

  const VendorMessage({
    required this.id,
    required this.threadId,
    required this.clientName,
    required this.clientId,
    required this.lastMessage,
    required this.date,
    required this.unreadCount,
    this.vendorReply,
    this.vendorId,
  });

  VendorMessage copyWith({
    String? vendorReply,
    int? unreadCount,
    String? vendorId,
  }) {
    return VendorMessage(
      id: id,
      threadId: threadId,
      clientName: clientName,
      clientId: clientId,
      lastMessage: lastMessage,
      date: date,
      unreadCount: unreadCount ?? this.unreadCount,
      vendorReply: vendorReply ?? this.vendorReply,
      vendorId: vendorId ?? this.vendorId,
    );
  }

  static VendorMessage fromFirestore(Map<String, dynamic> data, String id) {
    return VendorMessage(
      id: id,
      threadId: data['threadId']?.toString() ?? '',
      clientName: data['clientName']?.toString() ?? 'Unknown',
      clientId: data['clientId']?.toString() ?? 'anonymous',
      lastMessage: data['lastMessage']?.toString() ?? '',
      date: data['date']?.toString() ?? '',
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      vendorReply: data['vendorReply']?.toString(),
      vendorId: data['vendorId']?.toString(),
    );
  }
}

// --- NEW: Promotion Model ---

class VendorPromotion {
  final String id;
  final String title;
  final String description;
  final int discountPercent;
  final String startDate;
  final String endDate;
  final bool isActive;
  final String? linkedPackageId;
  final String? vendorId;

  const VendorPromotion({
    required this.id,
    required this.title,
    required this.description,
    required this.discountPercent,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.linkedPackageId,
    this.vendorId,
  });

  VendorPromotion copyWith({
    String? title,
    String? description,
    int? discountPercent,
    String? startDate,
    String? endDate,
    bool? isActive,
    String? linkedPackageId,
    String? vendorId,
  }) {
    return VendorPromotion(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      discountPercent: discountPercent ?? this.discountPercent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      linkedPackageId: linkedPackageId ?? this.linkedPackageId,
      vendorId: vendorId ?? this.vendorId,
    );
  }

  static VendorPromotion fromFirestore(Map<String, dynamic> data, String id) {
    return VendorPromotion(
      id: id,
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      discountPercent: (data['discountPercent'] as num?)?.toInt() ?? 0,
      startDate: data['startDate']?.toString() ?? '',
      endDate: data['endDate']?.toString() ?? '',
      isActive: data['isActive'] as bool? ?? true,
      linkedPackageId: data['linkedPackageId']?.toString(),
      vendorId: data['vendorId']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'discountPercent': discountPercent,
      'startDate': startDate,
      'endDate': endDate,
      'isActive': isActive,
      'linkedPackageId': linkedPackageId,
      if (vendorId != null) 'vendorId': vendorId,
    };
  }
}

// --- NEW: Availability Model ---

class VendorAvailabilityDay {
  final String date; // YYYY-MM-DD
  final bool isBlocked;
  final String note;

  const VendorAvailabilityDay({
    required this.date,
    required this.isBlocked,
    this.note = '',
  });

  VendorAvailabilityDay copyWith({bool? isBlocked, String? note}) {
    return VendorAvailabilityDay(
      date: date,
      isBlocked: isBlocked ?? this.isBlocked,
      note: note ?? this.note,
    );
  }

  static VendorAvailabilityDay fromMap(Map<String, dynamic> data) {
    return VendorAvailabilityDay(
      date: data['date']?.toString() ?? '',
      isBlocked: data['isBlocked'] as bool? ?? false,
      note: data['note']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'isBlocked': isBlocked,
      'note': note,
    };
  }
}

// --- Quick Reply Template ---

class QuickReplyTemplate {
  final String id;
  final String title;
  final String body;

  const QuickReplyTemplate({required this.id, required this.title, required this.body});

  QuickReplyTemplate copyWith({String? title, String? body}) {
    return QuickReplyTemplate(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  static QuickReplyTemplate fromMap(Map<String, dynamic> data) {
    return QuickReplyTemplate(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
    };
  }
}

// --- Notifiers ---

class VendorInquiriesNotifier extends Notifier<List<VendorInquiry>> {
  StreamSubscription? _sub;

  @override
  List<VendorInquiry> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('vendor_inquiries')
          .where('vendorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isEmpty) {
          state = const [];
        } else {
          state = snapshot.docs.map((doc) => VendorInquiry.fromFirestore(doc.data(), doc.id)).toList();
        }
      }, onError: (err) {
        print("Error listening to vendor_inquiries: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> acceptInquiry(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(id).update({
        'status': 'Accepted',
      });
      // Notify consumer
      final inq = state.firstWhere((i) => i.id == id, orElse: () => state.first);
      if (inq.consumerId != null && inq.consumerId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientUid: inq.consumerId!,
          title: 'Booking Accepted!',
          body: 'Your booking request for ${inq.detail} has been accepted.',
          type: 'inquiry_accepted',
          data: {'inquiryId': id},
        );
      }
    } catch (e) {
      print("Error accepting inquiry: $e");
      state = state.map((inq) => inq.id == id ? inq.copyWith(status: 'Accepted') : inq).toList();
    }
  }

  Future<void> rejectInquiry(String id) async {
    final inq = state.where((i) => i.id == id).firstOrNull;
    try {
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(id).update({
        'status': 'Cancelled',
      });

      // Update matching docs in 'bookings' collection to Cancelled
      try {
        final bSnap1 = await FirebaseFirestore.instance.collection('bookings').where('vendorInquiryId', isEqualTo: id).get();
        for (final doc in bSnap1.docs) {
          await doc.reference.update({'status': 'Cancelled'});
        }
      } catch (_) {}

      // Unblock date in vendor_availability if date is present
      if (inq != null && inq.vendorId != null && inq.vendorId!.isNotEmpty) {
        final rawDate = inq.date.isNotEmpty ? inq.date : inq.detail;
        final ymdMatch = RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(rawDate);
        String? normDate;
        if (ymdMatch != null) {
          normDate = '${ymdMatch.group(1)}-${ymdMatch.group(2)!.padLeft(2, '0')}-${ymdMatch.group(3)!.padLeft(2, '0')}';
        }
        if (normDate != null) {
          try {
            final bSnap2 = await FirebaseFirestore.instance.collection('bookings').where('vendorId', isEqualTo: inq.vendorId).get();
            for (final doc in bSnap2.docs) {
              final ed = doc.data()['eventDate']?.toString();
              if (ed != null) {
                final edMatch = RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(ed);
                if (edMatch != null) {
                  final edNorm = '${edMatch.group(1)}-${edMatch.group(2)!.padLeft(2, '0')}-${edMatch.group(3)!.padLeft(2, '0')}';
                  if (edNorm == normDate) {
                    await doc.reference.update({'status': 'Cancelled'});
                  }
                }
              }
            }
          } catch (_) {}

          try {
            final availDocRef = FirebaseFirestore.instance.collection('vendor_availability').doc(inq.vendorId);
            final availSnap = await availDocRef.get();
            if (availSnap.exists && availSnap.data() != null) {
              final List<dynamic> days = availSnap.data()!['days'] ?? [];
              final updatedDays = days.where((d) {
                if (d is Map && d['date'] != null) {
                  return d['date'].toString() != normDate;
                }
                return true;
              }).toList();
              await availDocRef.update({'days': updatedDays});
            }
          } catch (e) {
            print("Error unblocking vendor availability: $e");
          }
        }
      }

      // Notify consumer
      if (inq != null && inq.consumerId != null && inq.consumerId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientUid: inq.consumerId!,
          title: 'Booking Cancelled',
          body: 'Your booking request for ${inq.detail} was cancelled.',
          type: 'inquiry_rejected',
          data: {'inquiryId': id},
        );
      }
    } catch (e) {
      print("Error rejecting inquiry: $e");
      state = state.map((inq) => inq.id == id ? inq.copyWith(status: 'Cancelled') : inq).toList();
    }
  }

  Future<void> moveToNegotiating(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(id).update({
        'status': 'Negotiating',
      });
      // Notify consumer
      final inq = state.firstWhere((i) => i.id == id, orElse: () => state.first);
      if (inq.consumerId != null && inq.consumerId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientUid: inq.consumerId!,
          title: 'Booking Under Review',
          body: 'Your request for ${inq.detail} is now being negotiated.',
          type: 'inquiry_negotiating',
          data: {'inquiryId': id},
        );
      }
    } catch (e) {
      print("Error moving to negotiating: $e");
      state = state.map((inq) => inq.id == id ? inq.copyWith(status: 'Negotiating') : inq).toList();
    }
  }

  Future<void> sendOffer(String id, double priceAmount) async {
    final inq = state.firstWhere((i) => i.id == id);
    final formattedAmount = 'Rs. ${priceAmount.toStringAsFixed(0)}';
    
    try {
      // 1. Update Vendor Inquiry
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(id).update({
        'status': 'Negotiating',
        'amount': formattedAmount,
      });

      // 2. Update Ledger Item (if linked)
      if (inq.ledgerItemId != null && inq.ledgerItemId!.isNotEmpty) {
        DocumentReference ledgerRef;
        if (inq.ledgerCode != null && inq.ledgerCode!.isNotEmpty) {
          ledgerRef = FirebaseFirestore.instance.collection('shared_ledgers').doc(inq.ledgerCode).collection('items').doc(inq.ledgerItemId);
        } else {
          ledgerRef = FirebaseFirestore.instance.collection('ledger').doc(inq.ledgerItemId);
        }
        await ledgerRef.update({
          'amount': priceAmount,
          'status': 'Offer Received',
        });
      }

      // 3. Notify consumer about the offer
      if (inq.consumerId != null && inq.consumerId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientUid: inq.consumerId!,
          title: 'New Price Offer!',
          body: 'You received an offer of $formattedAmount for ${inq.detail}.',
          type: 'offer_sent',
          data: {'inquiryId': id, 'amount': formattedAmount},
        );
      }
    } catch (e) {
      print("Error sending offer: $e");
    }
  }

  Future<void> finalizeBooking(String id) async {
    final inq = state.firstWhere((i) => i.id == id);
    
    try {
      // 1. Update Vendor Inquiry
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(id).update({
        'status': 'Accepted',
      });

      // 2. Update Ledger Item (if linked)
      if (inq.ledgerItemId != null && inq.ledgerItemId!.isNotEmpty) {
        DocumentReference ledgerRef;
        if (inq.ledgerCode != null && inq.ledgerCode!.isNotEmpty) {
          ledgerRef = FirebaseFirestore.instance.collection('shared_ledgers').doc(inq.ledgerCode).collection('items').doc(inq.ledgerItemId);
        } else {
          ledgerRef = FirebaseFirestore.instance.collection('ledger').doc(inq.ledgerItemId);
        }
        await ledgerRef.update({
          'status': 'Confirmed',
        });
      }

      // 3. Notify consumer about confirmation
      if (inq.consumerId != null && inq.consumerId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientUid: inq.consumerId!,
          title: 'Booking Confirmed! 🎉',
          body: 'Your booking for ${inq.detail} has been confirmed.',
          type: 'booking_confirmed',
          data: {'inquiryId': id},
        );
      }
    } catch (e) {
      print("Error finalizing booking: $e");
    }
  }

  Future<void> markCompleted(String id) async {
    final inq = state.firstWhere((i) => i.id == id, orElse: () => state.first);
    
    try {
      // 1. Update Vendor Inquiry status
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(id).update({
        'status': 'Completed',
      });

      // 2. Update linked Ledger Item status to 'Completed'
      if (inq.ledgerItemId != null && inq.ledgerItemId!.isNotEmpty) {
        DocumentReference ledgerRef;
        if (inq.ledgerCode != null && inq.ledgerCode!.isNotEmpty) {
          ledgerRef = FirebaseFirestore.instance.collection('shared_ledgers').doc(inq.ledgerCode).collection('items').doc(inq.ledgerItemId);
        } else {
          ledgerRef = FirebaseFirestore.instance.collection('ledger').doc(inq.ledgerItemId);
        }
        await ledgerRef.update({
          'status': 'Completed',
        });
      }

      // 3. Notify consumer about completion
      if (inq.consumerId != null && inq.consumerId!.isNotEmpty) {
        await NotificationService.sendNotification(
          recipientUid: inq.consumerId!,
          title: 'Booking Completed ✅',
          body: 'Your booking for ${inq.detail} has been marked as completed.',
          type: 'booking_completed',
          data: {'inquiryId': id},
        );
      }
    } catch (e) {
      print("Error marking completed: $e");
      state = state.map((i) => i.id == id ? i.copyWith(status: 'Completed') : i).toList();
    }
  }
}

final vendorInquiriesProvider = NotifierProvider<VendorInquiriesNotifier, List<VendorInquiry>>(VendorInquiriesNotifier.new);

class VendorCatalogNotifier extends Notifier<List<CatalogPackage>> {
  StreamSubscription? _sub;

  @override
  List<CatalogPackage> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('vendor_catalog')
          .where('vendorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isEmpty) {
          state = const [];
        } else {
          state = snapshot.docs.map((doc) => CatalogPackage.fromFirestore(doc.data(), doc.id)).toList();
        }
      }, onError: (err) {
        print("Error listening to vendor_catalog: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> addPackage(String name, String price, String pricingUnit, String description, {String imageUrl = ''}) async {
    final userId = ref.read(authProvider).userId;
    final id = 'pkg_${DateTime.now().millisecondsSinceEpoch}';
    final pkg = CatalogPackage(id: id, name: name, price: price, pricingUnit: pricingUnit, description: description, imageUrl: imageUrl, vendorId: userId);
    try {
      await FirebaseFirestore.instance.collection('vendor_catalog').doc(id).set(pkg.toFirestore());
    } catch (e) {
      print("Error adding package to Firestore: $e");
      state = [...state, pkg];
    }
  }

  Future<void> updatePackage(String id, {String? name, String? price, String? pricingUnit, String? description, String? imageUrl}) async {
    final idx = state.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final updated = state[idx].copyWith(
      name: name,
      price: price,
      pricingUnit: pricingUnit,
      description: description,
      imageUrl: imageUrl,
    );
    try {
      await FirebaseFirestore.instance.collection('vendor_catalog').doc(id).update(updated.toFirestore());
    } catch (e) {
      print("Error updating package: $e");
      final newState = [...state];
      newState[idx] = updated;
      state = newState;
    }
  }

  Future<void> deletePackage(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_catalog').doc(id).delete();
    } catch (e) {
      print("Error deleting package: $e");
      state = state.where((p) => p.id != id).toList();
    }
  }
}

final vendorCatalogProvider = NotifierProvider<VendorCatalogNotifier, List<CatalogPackage>>(VendorCatalogNotifier.new);

class VendorProfileNotifier extends Notifier<VendorProfile> {
  StreamSubscription? _sub;

  @override
  VendorProfile build() {
    final auth = ref.watch(authProvider);
    final docId = (auth.isAuthenticated && auth.role == 'vendor') ? auth.userId! : 'profile_details';

    final dynamicDefault = VendorProfile(
      businessName: auth.businessName ?? 'My Business',
      location: '',
      category: 'Venues',
      bio: '',
      email: auth.email ?? '',
    );

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('vendor_profile').doc(docId).snapshots().listen((docSnapshot) {
        if (!docSnapshot.exists) {
          state = dynamicDefault;
        } else {
          final data = docSnapshot.data() ?? {};
          var profile = VendorProfile.fromFirestore(data);
          if (profile.email.isEmpty && auth.email != null) {
            profile = profile.copyWith(email: auth.email!);
          }
          
          if (profile.subscriptionTier != 'free' && profile.subscriptionExpiry != null) {
            if (DateTime.now().isAfter(profile.subscriptionExpiry!)) {
              profile = profile.copyWith(subscriptionTier: 'free');
              FirebaseFirestore.instance.collection('vendor_profile').doc(docId).update({
                'subscriptionTier': 'free',
                'subscriptionExpiry': FieldValue.delete(),
              }).catchError((_) {});
              FirebaseFirestore.instance.collection('vendors').doc(docId).update({
                'subscriptionTier': 'free',
                'subscriptionExpiry': FieldValue.delete(),
              }).catchError((_) {});
            }
          }
          state = profile;
        }
      }, onError: (err) {
        print("Error listening to vendor_profile: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return dynamicDefault;
  }

  Future<void> updateProfile({
    String? businessName, 
    String? location, 
    String? category, 
    String? bio, 
    String? subscriptionTier, 
    String? phone, 
    String? email, 
    String? website,
    String? ownerName,
    String? city,
    int? capacity,
    double? price,
    bool? isSetupComplete,
    List<String>? outsidePictures,
    List<String>? insidePictures,
    double? weekendPrice,
    Map<String, double>? specialPrices,
    Map<String, double>? beverages,
    List<GenericSingleProduct>? singleProducts,
    List<GenericServicePackage>? servicePackages,
  }) async {
    final updated = state.copyWith(
      businessName: businessName,
      location: location,
      category: category,
      bio: bio,
      subscriptionTier: subscriptionTier,
      phone: phone,
      email: email,
      website: website,
      ownerName: ownerName,
      city: city,
      capacity: capacity,
      price: price,
      isSetupComplete: isSetupComplete,
      outsidePictures: outsidePictures,
      insidePictures: insidePictures,
      weekendPrice: weekendPrice,
      specialPrices: specialPrices,
      beverages: beverages,
      singleProducts: singleProducts,
      servicePackages: servicePackages,
    );
    final auth = ref.read(authProvider);
    final docId = (auth.isAuthenticated && auth.role == 'vendor') ? auth.userId! : 'profile_details';

    try {
      await FirebaseFirestore.instance.collection('vendor_profile').doc(docId).set({
        'businessName': updated.businessName,
        'location': updated.location,
        'category': updated.category,
        'bio': updated.bio,
        'subscriptionTier': updated.subscriptionTier,
        'phone': updated.phone,
        'email': updated.email,
        'website': updated.website,
        'ownerName': updated.ownerName,
        'city': updated.city,
        'capacity': updated.capacity,
        'price': updated.price,
        'isSetupComplete': updated.isSetupComplete,
        'outsidePictures': updated.outsidePictures,
        'insidePictures': updated.insidePictures,
        'weekendPrice': updated.weekendPrice,
        'specialPrices': updated.specialPrices.map((key, value) => MapEntry(key, value.toString())),
        'beverages': updated.beverages.map((key, value) => MapEntry(key, value.toString())),
        'singleProducts': updated.singleProducts.map((p) => p.toMap()).toList(),
        'servicePackages': updated.servicePackages.map((p) => p.toMap()).toList(),
      }, SetOptions(merge: true));

      final combinedPictures = [
        ...updated.outsidePictures,
        ...updated.insidePictures,
      ].where((url) => url.isNotEmpty).toSet().toList();

      await FirebaseFirestore.instance.collection('vendors').doc(docId).set({
        'name': updated.businessName,
        'location': updated.location,
        'category': updated.category,
        'description': updated.bio,
        'subscriptionTier': updated.subscriptionTier,
        'outsidePictures': updated.outsidePictures,
        'insidePictures': updated.insidePictures,
        'images': combinedPictures,
        'beverages': updated.beverages.map((key, value) => MapEntry(key, value.toString())),
        'singleProducts': updated.singleProducts.map((p) => p.toMap()).toList(),
        'servicePackages': updated.servicePackages.map((p) => p.toMap()).toList(),
      }, SetOptions(merge: true));

      state = updated;
    } catch (e) {
      print("Error updating profile in Firestore: $e");
      state = updated;
    }
  }
}

final vendorProfileProvider = NotifierProvider<VendorProfileNotifier, VendorProfile>(VendorProfileNotifier.new);

class UploadedMediaNotifier extends Notifier<List<String>> {
  StreamSubscription? _sub;

  @override
  List<String> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('vendor_media').doc(userId).snapshots().listen((docSnapshot) {
        if (!docSnapshot.exists) {
          state = const [];
        } else {
          final data = docSnapshot.data() ?? {};
          final List<dynamic> list = data['urls'] ?? [];
          state = list.map((e) => e.toString()).toList();
        }
      }, onError: (err) {
        print("Error listening to vendor_media: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> uploadMedia(String url) async {
    final updated = [...state, url];
    state = updated; // Optimistic update
    final userId = ref.read(authProvider).userId;
    try {
      await FirebaseFirestore.instance.collection('vendor_media').doc(userId).set({
        'urls': updated,
      });
    } catch (e) {
      print("Error uploading media to Firestore: $e");
    }
  }

  Future<void> removeMedia(String url) async {
    final updated = state.where((u) => u != url).toList();
    state = updated; // Optimistic update
    final userId = ref.read(authProvider).userId;
    try {
      await FirebaseFirestore.instance.collection('vendor_media').doc(userId).set({
        'urls': updated,
      });
    } catch (e) {
      print("Error removing media from Firestore: $e");
    }
  }
}

final uploadedMediaProvider = NotifierProvider<UploadedMediaNotifier, List<String>>(UploadedMediaNotifier.new);

// --- Dynamic Analytics ---

class VendorAnalytics {
  final double totalEarnings;
  final double pendingRevenue;
  final int completedBookings;
  final int pendingBookings;
  final int rejectedBookings;
  final int negotiatingBookings;
  final int confirmedBookings;
  final double conversionRate;
  final int profileViews;
  final double averageRating;
  final int totalReviews;
  final List<double> monthlyRevenue;
  final List<String> monthLabels;

  const VendorAnalytics({
    required this.totalEarnings,
    required this.pendingRevenue,
    required this.completedBookings,
    required this.pendingBookings,
    required this.rejectedBookings,
    required this.negotiatingBookings,
    required this.confirmedBookings,
    required this.conversionRate,
    required this.profileViews,
    required this.averageRating,
    required this.totalReviews,
    required this.monthlyRevenue,
    required this.monthLabels,
  });
}

final vendorAnalyticsProvider = Provider<VendorAnalytics>((ref) {
  final inquiries = ref.watch(vendorInquiriesProvider);
  final reviews = ref.watch(vendorReviewsProvider);

  double totalEarnings = 0;
  double pendingRevenue = 0;
  int completedBookings = 0;
  int pendingBookings = 0;
  int rejectedBookings = 0;
  int negotiatingBookings = 0;
  int confirmedBookings = 0;
  int totalRequests = inquiries.length;

  for (final inq in inquiries) {
    final amt = inq.numericAmount;

    if (inq.status == 'Completed') {
      totalEarnings += amt;
      completedBookings++;
    } else if (inq.status == 'Confirmed' || inq.status == 'Accepted' || inq.status == 'User Accepted' || inq.status == 'Pending' || inq.status == 'Negotiating') {
      totalEarnings += amt;
      confirmedBookings++;
      pendingBookings++;
    } else if (inq.status == 'Rejected' || inq.status == 'Cancelled') {
      rejectedBookings++;
    }
  }

  final double conversionRate = totalRequests > 0 ? ((completedBookings + confirmedBookings) / totalRequests) * 100 : 0.0;

  double avgRating = 0.0;
  if (reviews.isNotEmpty) {
    avgRating = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
  }

  // Build monthly revenue from inquiry dates
  final Map<int, double> monthMap = {};
  final now = DateTime.now();
  for (final inq in inquiries) {
    if (inq.status == 'Confirmed' || inq.status == 'Accepted' || inq.status == 'Completed' || inq.status == 'Pending' || inq.status == 'Negotiating') {
      int month = now.month;
      try {
        final parts = inq.date.split('/');
        if (parts.isNotEmpty) {
          month = int.tryParse(parts[0]) ?? now.month;
        }
      } catch (_) {}
      monthMap[month] = (monthMap[month] ?? 0) + inq.numericAmount;
    }
  }

  // Build 6-month labels ending at current month
  final List<String> monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final List<String> labels = [];
  final List<double> revenues = [];
  for (int i = 5; i >= 0; i--) {
    int m = now.month - i;
    if (m <= 0) m += 12;
    labels.add(monthNames[m - 1]);
    revenues.add(monthMap[m] ?? 0.0);
  }

  return VendorAnalytics(
    totalEarnings: totalEarnings,
    pendingRevenue: pendingRevenue,
    completedBookings: completedBookings,
    pendingBookings: pendingBookings,
    rejectedBookings: rejectedBookings,
    negotiatingBookings: negotiatingBookings,
    confirmedBookings: confirmedBookings,
    conversionRate: conversionRate,
    profileViews: 0,
    averageRating: avgRating,
    totalReviews: reviews.length,
    monthLabels: labels,
    monthlyRevenue: revenues,
  );
});

class VendorReviewsNotifier extends Notifier<List<VendorReview>> {
  StreamSubscription? _sub;

  @override
  List<VendorReview> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('vendor_reviews')
          .where('vendorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        state = snapshot.docs.map((doc) => VendorReview.fromFirestore(doc.data(), doc.id)).toList();
      }, onError: (err) {
        print("Error listening to vendor_reviews: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> replyToReview(String id, String reply) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_reviews').doc(id).update({
        'reply': reply,
      });
    } catch (e) {
      print("Error replying to review: $e");
      state = state.map((r) => r.id == id ? r.copyWith(reply: reply) : r).toList();
    }
  }
}

final vendorReviewsProvider = NotifierProvider<VendorReviewsNotifier, List<VendorReview>>(VendorReviewsNotifier.new);

class VendorMessagesNotifier extends Notifier<List<VendorMessage>> {
  StreamSubscription? _sub;

  @override
  List<VendorMessage> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('vendor_messages')
          .where('vendorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        state = snapshot.docs.map((doc) => VendorMessage.fromFirestore(doc.data(), doc.id)).toList();
      }, onError: (err) {
        print("Error listening to vendor_messages: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> replyToMessage(String id, String reply) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_messages').doc(id).update({
        'vendorReply': reply,
        'unreadCount': 0, // Reset unread count for vendor when they reply
      });
    } catch (e) {
      print("Error replying to message: $e");
      state = state.map((m) => m.id == id ? m.copyWith(vendorReply: reply, unreadCount: 0) : m).toList();
    }
  }
}

final vendorMessagesProvider = NotifierProvider<VendorMessagesNotifier, List<VendorMessage>>(VendorMessagesNotifier.new);

class VendorBookingFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';
  set state(String value) => super.state = value;
}

final vendorBookingFilterProvider = NotifierProvider<VendorBookingFilterNotifier, String>(VendorBookingFilterNotifier.new);

class VendorBookingSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  set state(String value) => super.state = value;
}

final vendorBookingSearchProvider = NotifierProvider<VendorBookingSearchNotifier, String>(VendorBookingSearchNotifier.new);

// =====================================================================
// NEW: Promotions Provider
// =====================================================================

class VendorPromotionsNotifier extends Notifier<List<VendorPromotion>> {
  StreamSubscription? _sub;

  @override
  List<VendorPromotion> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance
          .collection('vendor_promotions')
          .where('vendorId', isEqualTo: userId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.docs.isEmpty) {
          state = const [];
        } else {
          state = snapshot.docs.map((doc) => VendorPromotion.fromFirestore(doc.data(), doc.id)).toList();
        }
      }, onError: (err) {
        print("Error listening to vendor_promotions: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> addPromotion({
    required String title,
    required String description,
    required int discountPercent,
    required String startDate,
    required String endDate,
    String? linkedPackageId,
  }) async {
    final userId = ref.read(authProvider).userId;
    final id = 'promo_${DateTime.now().millisecondsSinceEpoch}';
    final promo = VendorPromotion(
      id: id,
      title: title,
      description: description,
      discountPercent: discountPercent,
      startDate: startDate,
      endDate: endDate,
      isActive: true,
      linkedPackageId: linkedPackageId,
      vendorId: userId,
    );
    try {
      await FirebaseFirestore.instance.collection('vendor_promotions').doc(id).set(promo.toFirestore());
    } catch (e) {
      print("Error adding promotion: $e");
      state = [...state, promo];
    }
  }

  Future<void> togglePromotion(String id, bool isActive) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_promotions').doc(id).update({
        'isActive': isActive,
      });
    } catch (e) {
      print("Error toggling promotion: $e");
      state = state.map((p) => p.id == id ? p.copyWith(isActive: isActive) : p).toList();
    }
  }

  Future<void> deletePromotion(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendor_promotions').doc(id).delete();
    } catch (e) {
      print("Error deleting promotion: $e");
      state = state.where((p) => p.id != id).toList();
    }
  }

  Future<void> updatePromotion(String id, {
    String? title,
    String? description,
    int? discountPercent,
    String? startDate,
    String? endDate,
    String? linkedPackageId,
  }) async {
    final idx = state.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final updated = state[idx].copyWith(
      title: title,
      description: description,
      discountPercent: discountPercent,
      startDate: startDate,
      endDate: endDate,
      linkedPackageId: linkedPackageId,
    );
    try {
      await FirebaseFirestore.instance.collection('vendor_promotions').doc(id).update(updated.toFirestore());
    } catch (e) {
      print("Error updating promotion: $e");
      final newState = [...state];
      newState[idx] = updated;
      state = newState;
    }
  }
}

final vendorPromotionsProvider = NotifierProvider<VendorPromotionsNotifier, List<VendorPromotion>>(VendorPromotionsNotifier.new);

// =====================================================================
// NEW: Availability Provider
// =====================================================================

class VendorAvailabilityNotifier extends Notifier<List<VendorAvailabilityDay>> {
  StreamSubscription? _sub;

  @override
  List<VendorAvailabilityDay> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('vendor_availability').doc(userId).snapshots().listen((docSnapshot) {
        if (!docSnapshot.exists) {
          state = const [];
        } else {
          final data = docSnapshot.data() ?? {};
          final List<dynamic> list = data['days'] ?? [];
          state = list.map((e) => VendorAvailabilityDay.fromMap(e as Map<String, dynamic>)).toList();
        }
      }, onError: (err) {
        print("Error listening to vendor_availability: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> toggleDate(String date, {String note = ''}) async {
    final existing = state.where((d) => d.date == date).firstOrNull;
    List<VendorAvailabilityDay> updated;

    if (existing != null) {
      // Toggle: if blocked, unblock (remove); if unblocked, block
      if (existing.isBlocked) {
        updated = state.where((d) => d.date != date).toList();
      } else {
        updated = state.map((d) => d.date == date ? d.copyWith(isBlocked: true, note: note) : d).toList();
      }
    } else {
      updated = [...state, VendorAvailabilityDay(date: date, isBlocked: true, note: note)];
    }

    try {
      final userId = ref.read(authProvider).userId;
      await FirebaseFirestore.instance.collection('vendor_availability').doc(userId).set({
        'days': updated.map((d) => d.toMap()).toList(),
      });
    } catch (e) {
      print("Error updating availability: $e");
      state = updated;
    }
  }

  bool isDateBlocked(String date) {
    return state.any((d) => d.date == date && d.isBlocked);
  }
}

final vendorAvailabilityProvider = NotifierProvider<VendorAvailabilityNotifier, List<VendorAvailabilityDay>>(VendorAvailabilityNotifier.new);

// =====================================================================
// NEW: Performance Tips Provider (Computed)
// =====================================================================

class PerformanceTip {
  final String icon;
  final String title;
  final String description;
  final String priority; // 'high', 'medium', 'low'

  const PerformanceTip({
    required this.icon,
    required this.title,
    required this.description,
    required this.priority,
  });
}

final vendorPerformanceTipsProvider = Provider<List<PerformanceTip>>((ref) {
  final profile = ref.watch(vendorProfileProvider);
  final catalog = ref.watch(vendorCatalogProvider);
  final inquiries = ref.watch(vendorInquiriesProvider);
  final reviews = ref.watch(vendorReviewsProvider);
  final media = ref.watch(uploadedMediaProvider);
  final promos = ref.watch(vendorPromotionsProvider);

  final tips = <PerformanceTip>[];

  // Portfolio tips
  if (media.isEmpty) {
    tips.add(const PerformanceTip(
      icon: '📸',
      title: 'Add portfolio photos',
      description: 'Vendors with 5+ photos get 3x more inquiries. Upload your best work to attract clients.',
      priority: 'high',
    ));
  } else if (media.length < 5) {
    tips.add(PerformanceTip(
      icon: '📸',
      title: 'Add more portfolio photos',
      description: 'You have ${media.length} photo${media.length == 1 ? '' : 's'}. Aim for at least 5 to stand out from competition.',
      priority: 'medium',
    ));
  }

  // Bio tip
  if (profile.bio.isEmpty) {
    tips.add(const PerformanceTip(
      icon: '✍️',
      title: 'Write a business description',
      description: 'Profiles with descriptions get 2x more trust. Tell clients what makes you special.',
      priority: 'high',
    ));
  } else if (profile.bio.length < 100) {
    tips.add(const PerformanceTip(
      icon: '✍️',
      title: 'Expand your description',
      description: 'Your bio is quite short. Add details about your experience, specialties, and what clients can expect.',
      priority: 'low',
    ));
  }

  // Catalog tip
  if (catalog.isEmpty) {
    tips.add(const PerformanceTip(
      icon: '📦',
      title: 'Create your first package',
      description: 'Clients love clear pricing. Add at least one service package to your catalog.',
      priority: 'high',
    ));
  } else if (catalog.length < 3) {
    tips.add(const PerformanceTip(
      icon: '📦',
      title: 'Offer more package options',
      description: 'Vendors with 3+ packages get more bookings. Consider adding budget, standard, and premium tiers.',
      priority: 'medium',
    ));
  }

  // Pending bookings tip
  final pendingCount = inquiries.where((i) => i.status == 'Pending').length;
  if (pendingCount > 0) {
    tips.add(PerformanceTip(
      icon: '⏰',
      title: 'Respond to pending requests',
      description: 'You have $pendingCount pending booking${pendingCount == 1 ? '' : 's'}. Fast responses improve your ranking and conversion rate.',
      priority: 'high',
    ));
  }

  // Unreplied reviews tip
  final unrepliedReviews = reviews.where((r) => r.reply == null).length;
  if (unrepliedReviews > 0) {
    tips.add(PerformanceTip(
      icon: '💬',
      title: 'Reply to customer reviews',
      description: '$unrepliedReviews review${unrepliedReviews == 1 ? '' : 's'} without a reply. Responding shows professionalism and builds trust.',
      priority: 'medium',
    ));
  }

  // Contact info tips
  if (profile.phone.isEmpty) {
    tips.add(const PerformanceTip(
      icon: '📱',
      title: 'Add your phone number',
      description: 'Make it easy for clients to reach you. Add your business phone number in Settings.',
      priority: 'medium',
    ));
  }

  // Promotions tip
  final activePromos = promos.where((p) => p.isActive).length;
  if (activePromos == 0) {
    tips.add(const PerformanceTip(
      icon: '🎯',
      title: 'Create a promotion',
      description: 'Running a limited-time deal can boost your bookings by 40%. Go to Promotions to create one.',
      priority: 'medium',
    ));
  }

  // Sort by priority
  const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
  tips.sort((a, b) => (priorityOrder[a.priority] ?? 2).compareTo(priorityOrder[b.priority] ?? 2));

  return tips;
});

// =====================================================================
// NEW: Quick Reply Templates Provider
// =====================================================================

class QuickReplyTemplatesNotifier extends Notifier<List<QuickReplyTemplate>> {
  StreamSubscription? _sub;

  @override
  List<QuickReplyTemplate> build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    if (userId == null) return const [];

    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('vendor_quick_replies').doc(userId).snapshots().listen((docSnapshot) {
        if (!docSnapshot.exists) {
          state = const [
            QuickReplyTemplate(
              id: 'pricing',
              title: '💰 Pricing Info',
              body: 'Thank you for your interest! Our packages start from the prices listed in our catalog. I\'d love to discuss a custom quote based on your specific needs. Could you share more details about your event?',
            ),
            QuickReplyTemplate(
              id: 'availability',
              title: '📅 Availability Check',
              body: 'Thanks for reaching out! Let me check my calendar for your requested date. I\'ll get back to you within a few hours with confirmation. In the meantime, feel free to browse our packages!',
            ),
            QuickReplyTemplate(
              id: 'booking_confirm',
              title: '✅ Booking Confirmed',
              body: 'Great news! Your booking is confirmed. I\'ll send you a detailed plan shortly. Please feel free to reach out if you have any questions or special requests.',
            ),
            QuickReplyTemplate(
              id: 'thank_you',
              title: '🙏 Thank You',
              body: 'Thank you so much for choosing us! It was a pleasure working with you. We\'d really appreciate it if you could leave a review about your experience. Looking forward to serving you again!',
            ),
            QuickReplyTemplate(
              id: 'followup',
              title: '📋 Follow-up',
              body: 'Hi! Just following up on our recent conversation. Have you had a chance to review the details I shared? I\'m happy to answer any questions or make adjustments to better fit your needs.',
            ),
          ];
        } else {
          final data = docSnapshot.data() ?? {};
          final List<dynamic> list = data['templates'] ?? [];
          state = list.map((e) => QuickReplyTemplate.fromMap(e as Map<String, dynamic>)).toList();
        }
      }, onError: (err) {
        print("Error listening to vendor_quick_replies: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return const [];
  }

  Future<void> addTemplate(String title, String body) async {
    final id = 'reply_${DateTime.now().millisecondsSinceEpoch}';
    final newTemplate = QuickReplyTemplate(id: id, title: title, body: body);
    final updated = [...state, newTemplate];
    final userId = ref.read(authProvider).userId;
    
    try {
      await FirebaseFirestore.instance.collection('vendor_quick_replies').doc(userId).set({
        'templates': updated.map((t) => t.toMap()).toList(),
      });
    } catch (e) {
      print("Error adding template: $e");
      state = updated;
    }
  }

  Future<void> updateTemplate(String id, String title, String body) async {
    final updated = state.map((t) => t.id == id ? t.copyWith(title: title, body: body) : t).toList();
    final userId = ref.read(authProvider).userId;
    
    try {
      await FirebaseFirestore.instance.collection('vendor_quick_replies').doc(userId).set({
        'templates': updated.map((t) => t.toMap()).toList(),
      });
    } catch (e) {
      print("Error updating template: $e");
      state = updated;
    }
  }

  Future<void> deleteTemplate(String id) async {
    final updated = state.where((t) => t.id != id).toList();
    final userId = ref.read(authProvider).userId;
    
    try {
      await FirebaseFirestore.instance.collection('vendor_quick_replies').doc(userId).set({
        'templates': updated.map((t) => t.toMap()).toList(),
      });
    } catch (e) {
      print("Error deleting template: $e");
      state = updated;
    }
  }
}

final quickReplyTemplatesProvider = NotifierProvider<QuickReplyTemplatesNotifier, List<QuickReplyTemplate>>(QuickReplyTemplatesNotifier.new);
