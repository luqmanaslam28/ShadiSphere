import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../vendor_dashboard/presentation/vendor_providers.dart' show VendorMessage;
import '../../admin/presentation/admin_providers.dart';
import '../../../core/services/notification_service.dart';

// --- Models ---
class CityNotifier extends Notifier<String> {
  @override
  String build() => 'Lahore, Pakistan';

  void setCity(String newCity) {
    state = newCity;
  }
}

final cityProvider = NotifierProvider<CityNotifier, String>(CityNotifier.new);

class LanguageNotifier extends Notifier<String> {
  @override
  String build() => 'English';

  void setLanguage(String newLanguage) {
    state = newLanguage;
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, String>(LanguageNotifier.new);

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

// SRS §1.4: Full 7-vertical checklist
class ChecklistNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    final templateAsync = ref.watch(appChecklistTemplateProvider);
    final items = templateAsync.value;
    if (items != null && items.isNotEmpty) {
      return { for (var item in items) item.label: false };
    }
    // Hardcoded fallback while Firestore loads or if unavailable
    return {
      'Secure a dream venue': false,
      'Finalize catering menu': false,
      'Book decor staging': false,
      'Hire photographer': false,
      'Arrange pyrotechnics & effects': false,
      'Book luxury logistics': false,
      'Select apparel & grooming': false,
    };
  }

  void toggle(String key) {
    state = {
      ...state,
      key: !(state[key] ?? false),
    };
  }
}

final checklistProvider = NotifierProvider<ChecklistNotifier, Map<String, bool>>(ChecklistNotifier.new);

class VendorReview {
  final String reviewerName;
  final String comment;
  final double rating;
  final String date;

  const VendorReview({
    required this.reviewerName,
    required this.comment,
    required this.rating,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'reviewerName': reviewerName,
      'comment': comment,
      'rating': rating,
      'date': date,
    };
  }

  factory VendorReview.fromMap(Map<String, dynamic> map) {
    return VendorReview(
      reviewerName: map['reviewerName'] ?? 'Anonymous',
      comment: map['comment'] ?? '',
      rating: (map['rating'] ?? 5.0).toDouble(),
      date: map['date'] ?? 'Recently',
    );
  }
}

class Vendor {
  final String id;
  final String name;
  final String category;
  final String location;
  final String rating;
  final String imagePlaceholder;
  final List<String> images;
  final String description;
  final List<VendorReview> reviews;
  final String estimatedPrice;
  final String subscriptionTier;
  final String accountStatus;
  final bool hasAcceptedTerms;

  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    this.imagePlaceholder = '',
    this.images = const [],
    this.description = '',
    this.reviews = const [],
    this.estimatedPrice = '',
    this.subscriptionTier = 'free',
    this.accountStatus = 'active',
    this.hasAcceptedTerms = false,
  });

  factory Vendor.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Vendor.fromMap(data, doc.id);
  }

  factory Vendor.fromMap(Map<String, dynamic> data, String id) {
    final rawImages = data['images'] as List<dynamic>? ?? [];
    final outsidePics = data['outsidePictures'] as List<dynamic>? ?? [];
    final insidePics = data['insidePictures'] as List<dynamic>? ?? [];
    final rawReviews = data['reviews'] as List<dynamic>? ?? [];
    
    final combinedImages = [
      ...outsidePics.map((e) => e.toString()),
      ...insidePics.map((e) => e.toString()),
      ...rawImages.map((e) => e.toString()),
    ].where((e) => e.isNotEmpty).toSet().toList();
    
    return Vendor(
      id: id,
      name: data['name'] ?? data['businessName'] ?? 'Unknown Vendor',
      category: data['category'] ?? 'Uncategorized',
      location: data['location'] ?? 'Unknown Location',
      rating: data['rating']?.toString() ?? '0.0',
      imagePlaceholder: data['imagePlaceholder'] ?? '',
      images: combinedImages,
      description: data['description'] ?? data['bio'] ?? 'No description available.',
      reviews: rawReviews.map((e) => VendorReview.fromMap(Map<String, dynamic>.from(e as Map))).toList(),
      estimatedPrice: data['estimatedPrice']?.toString() ?? '',
      subscriptionTier: data['subscriptionTier'] ?? 'free',
      accountStatus: data['accountStatus']?.toString() ?? 'active',
      hasAcceptedTerms: data['hasAcceptedTerms'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'location': location,
      'rating': rating,
      'imagePlaceholder': imagePlaceholder,
      'images': images,
      'description': description,
      'reviews': reviews.map((r) => r.toMap()).toList(),
      'estimatedPrice': estimatedPrice,
      'subscriptionTier': subscriptionTier,
      'accountStatus': accountStatus,
      'hasAcceptedTerms': hasAcceptedTerms,
    };
  }
}

class VendorPackage {
  final String id;
  final String name;
  final String price;
  final String pricingUnit;
  final String description;
  final String imageUrl;
  final String? vendorId;

  const VendorPackage({
    required this.id,
    required this.name,
    required this.price,
    required this.pricingUnit,
    required this.description,
    this.imageUrl = '',
    this.vendorId,
  });

  factory VendorPackage.fromFirestore(Map<String, dynamic> data, String id) {
    return VendorPackage(
      id: id,
      name: data['name'] ?? 'Unnamed Package',
      price: data['price'] ?? '0',
      pricingUnit: data['pricingUnit'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      vendorId: data['vendorId'],
    );
  }
}

final vendorCatalogStreamProvider = StreamProvider.family<List<VendorPackage>, String>((ref, vendorId) {
  return FirebaseFirestore.instance
      .collection('vendor_catalog')
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => VendorPackage.fromFirestore(doc.data(), doc.id)).toList();
  });
});

class ConsumerVendorPromotion {
  final String id;
  final String title;
  final String description;
  final int discountPercent;
  final String startDate;
  final String endDate;
  final bool isActive;
  final String? linkedPackageId;
  final String? vendorId;

  const ConsumerVendorPromotion({
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

  factory ConsumerVendorPromotion.fromFirestore(Map<String, dynamic> data, String id) {
    return ConsumerVendorPromotion(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      discountPercent: data['discountPercent'] ?? 0,
      startDate: data['startDate'] ?? '',
      endDate: data['endDate'] ?? '',
      isActive: data['isActive'] ?? true,
      linkedPackageId: data['linkedPackageId'],
      vendorId: data['vendorId'],
    );
  }
}

final activePromotionsProvider = StreamProvider<List<ConsumerVendorPromotion>>((ref) {
  // First, get all active promotions from Firestore
  final stream = FirebaseFirestore.instance
      .collection('vendor_promotions')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => ConsumerVendorPromotion.fromFirestore(doc.data(), doc.id)).toList();
  });

  return stream;
});

final cityFilteredPromotionsProvider = Provider<AsyncValue<List<ConsumerVendorPromotion>>>((ref) {
  final promotionsAsync = ref.watch(activePromotionsProvider);
  final vendorsAsync = ref.watch(allVendorsProvider);
  final authState = ref.watch(authProvider);

  if (promotionsAsync.isLoading || vendorsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (promotionsAsync.hasError) {
    return AsyncValue.error(promotionsAsync.error!, promotionsAsync.stackTrace!);
  }

  final promotions = promotionsAsync.value ?? [];
  final vendors = vendorsAsync.value ?? [];

  List<ConsumerVendorPromotion> filtered = promotions;

  // Filter by user's city if they have one
  if (authState.city != null && authState.city!.isNotEmpty) {
    final userCityLower = authState.city!.split(',').first.trim().toLowerCase();
    
    filtered = promotions.where((promo) {
      final vendor = vendors.firstWhere(
        (v) => v.id == promo.vendorId,
        orElse: () => Vendor(id: '', name: '', category: '', location: '', rating: '', imagePlaceholder: '', images: [], description: '', reviews: [], estimatedPrice: ''),
      );
      // If vendor not found, we don't filter it out for now, or we can assume it doesn't match
      if (vendor.id.isEmpty) return false;
      return vendor.location.toLowerCase().contains(userCityLower);
    }).toList();
  }

  return AsyncValue.data(filtered);
});

class ChatMessage {
  final String id;
  final String text;
  final bool isAI;
  final bool isBreakdown;
  final bool isVendorRecommendation;
  final String? recommendedCategory;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isAI,
    this.isBreakdown = false,
    this.isVendorRecommendation = false,
    this.recommendedCategory,
    this.isLoading = false,
  });

  ChatMessage copyWith({String? text, bool? isLoading}) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      isAI: isAI,
      isBreakdown: isBreakdown,
      isVendorRecommendation: isVendorRecommendation,
      recommendedCategory: recommendedCategory,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final bool isRead;
  final String type; // 'booking', 'system', 'vendor', 'planning'

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
    this.type = 'system',
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      message: message,
      time: time,
      isRead: isRead ?? this.isRead,
      type: type,
    );
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? 'Notification',
      message: data['message'] ?? '',
      time: (data['time'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'system',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'message': message,
      'time': Timestamp.fromDate(time),
      'isRead': isRead,
      'type': type,
    };
  }
}

// SRS §3.2: Multi-channel notifications backed by Firestore
class NotificationsService {
  final String userId;
  NotificationsService(this.userId);

  Future<void> markAsRead(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final snapshot = await FirebaseFirestore.instance.collection('notifications').where('userId', isEqualTo: userId).where('isRead', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String id) async {
    await FirebaseFirestore.instance.collection('notifications').doc(id).delete();
  }
}

final notificationsServiceProvider = Provider<NotificationsService?>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return null;
  return NotificationsService(userId);
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .orderBy('time', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
});

class LedgerItem {
  final String id;
  final String category;
  final String vendorName;
  final double amount;
  final String status;
  final String addedBy; // UID of user who added this item
  final String addedByName; // Display name of user who added this item
  final DateTime? addedAt; // When the item was added
  final String? vendorId;
  final String? eventDate;
  final String? notes;
  final int? numberOfGuests;
  final String? vendorInquiryId;

  const LedgerItem({
    required this.id,
    required this.category,
    required this.vendorName,
    required this.amount,
    required this.status,
    this.addedBy = '',
    this.addedByName = '',
    this.addedAt,
    this.vendorId,
    this.eventDate,
    this.notes,
    this.numberOfGuests,
    this.vendorInquiryId,
  });

  factory LedgerItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LedgerItem(
      id: doc.id,
      category: data['category'] ?? 'Uncategorized',
      vendorName: data['vendorName'] ?? 'Unknown Vendor',
      amount: (data['amount'] ?? 0).toDouble(),
      status: data['status'] ?? 'Pending',
      addedBy: data['addedBy'] ?? '',
      addedByName: data['addedByName'] ?? '',
      addedAt: data['addedAt'] != null ? (data['addedAt'] as dynamic).toDate() : null,
      vendorId: data['vendorId'],
      eventDate: data['eventDate'],
      notes: data['notes'],
      numberOfGuests: data['numberOfGuests'] as int?,
      vendorInquiryId: data['vendorInquiryId'],
    );
  }
}

// Shared Ledger metadata model
class SharedLedger {
  final String code;
  final String ownerUid;
  final String ownerName;
  final List<LedgerMember> members;
  final DateTime? createdAt;

  const SharedLedger({
    required this.code,
    required this.ownerUid,
    required this.ownerName,
    this.members = const [],
    this.createdAt,
  });

  factory SharedLedger.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final membersList = (data['members'] as List<dynamic>?)
        ?.map((m) => LedgerMember(
              uid: m['uid'] ?? '',
              name: m['name'] ?? '',
            ))
        .toList() ?? [];
    return SharedLedger(
      code: doc.id,
      ownerUid: data['ownerUid'] ?? '',
      ownerName: data['ownerName'] ?? '',
      members: membersList,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as dynamic).toDate() : null,
    );
  }
}

class LedgerMember {
  final String uid;
  final String name;

  const LedgerMember({required this.uid, required this.name});
}

// --- Providers ---

// 1. Discover View State
class CategoryNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setCategory(String category) {
    state = category;
  }
}

final selectedCategoryProvider = NotifierProvider<CategoryNotifier, String>(CategoryNotifier.new);

class SavedVendorsNotifier extends Notifier<Set<String>> {
  static const _key = 'saved_vendors_list';

  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = prefs.getStringList(_key) ?? [];
      state = savedList.toSet();
    } catch (e) {
      print('Error loading saved vendors: $e');
    }
  }

  void toggleSaved(String vendorId) {
    if (state.contains(vendorId)) {
      state = {...state}..remove(vendorId);
    } else {
      state = {...state, vendorId};
    }
    _saveToPrefs(state);
  }

  Future<void> _saveToPrefs(Set<String> savedVendors) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, savedVendors.toList());
    } catch (e) {
      print('Error saving vendors: $e');
    }
  }
}

final savedVendorsProvider = NotifierProvider<SavedVendorsNotifier, Set<String>>(SavedVendorsNotifier.new);

// SRS §1.4: All 7 market verticals with vendor data
const localDummyVendors = [
  // --- Venues (2) ---
  Vendor(
    id: 'v1',
    name: 'Royal Palace Marquee',
    category: 'Venues',
    location: 'Lahore • 500-1000 Guests',
    rating: '4.9',
    images: [
      'https://images.unsplash.com/photo-1519225421980-715cb0215aed?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Royal Palace Marquee is the absolute pinnacle of luxury wedding celebrations in Lahore. Boasting state-of-the-art climate control, magnificent crystal chandeliers, and an expert culinary team, we make your dream wedding a stunning reality. Located in the heart of Gulberg, it features extensive parking space and valet services.',
    estimatedPrice: 'Rs. 450,000 (Base rent)',
    subscriptionTier: 'platinum',
    reviews: [
      VendorReview(reviewerName: 'Zainab Ali', comment: 'Absolutely stunning venue! The decor and space were perfect for our 800 guests.', rating: 5.0, date: '1 month ago'),
      VendorReview(reviewerName: 'Hamza Khan', comment: 'Very professional staff and premium arrangements. Valet parking was really helpful.', rating: 4.8, date: '2 weeks ago'),
    ],
  ),
  Vendor(
    id: 'v2',
    name: 'Mughal Gardens',
    category: 'Venues',
    location: 'Islamabad • Open Air',
    rating: '4.6',
    images: [
      'https://images.unsplash.com/photo-1464366400600-7168b8af9bc3?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1519225421980-715cb0215aed?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1511795409834-ef04bbd61622?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Mughal Gardens offers a breathtaking open-air wedding experience with historical architecture design elements, majestic green lawns, and custom evening lighting. Perfect for autumn and spring weddings, the venue provides a royal, scenic background that is ideal for photography.',
    estimatedPrice: 'Rs. 300,000 (Per evening)',
    subscriptionTier: 'premium',
    reviews: [
      VendorReview(reviewerName: 'Amna Shah', comment: 'Breathtaking open lawns and historical ambiance. The photos turned out amazing!', rating: 4.5, date: '3 months ago'),
    ],
  ),
  // --- Catering (2) ---
  Vendor(
    id: 'v3',
    name: 'Al-Fatah Caterers',
    category: 'Catering',
    location: 'Karachi • Multi-tier Menus',
    rating: '4.7',
    images: [
      'https://images.unsplash.com/photo-1555244162-803834f70033?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Al-Fatah Caterers has been serving exquisite culinary delights in Karachi for over two decades. Specializing in traditional Pakistani delicacies, including live BBQ, aromatic biryani, and delectable desserts, we promise a feast that your wedding guests will talk about for years.',
    estimatedPrice: 'Rs. 2,200 (Per guest)',
    reviews: [
      VendorReview(reviewerName: 'Faisal Karim', comment: 'The mutton biryani and seekh kebabs were outstanding. Best wedding catering in town.', rating: 4.9, date: '2 months ago'),
      VendorReview(reviewerName: 'Sana Fatima', comment: 'Great service and fresh food. Guests loved the dessert counter!', rating: 4.5, date: '3 weeks ago'),
    ],
  ),
  Vendor(
    id: 'v4',
    name: 'Gourmet Catering',
    category: 'Catering',
    location: 'Lahore • Traditional & Continental',
    rating: '4.8',
    images: [
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1555244162-803834f70033?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Gourmet Catering offers custom-curated menus for weddings, ranging from traditional subcontinental feasts to contemporary continental selections. Our professional hospitality team and top-tier presentation make every dish an experience of its own.',
    estimatedPrice: 'Rs. 2,800 (Per guest)',
    reviews: [
      VendorReview(reviewerName: 'Usman Ghani', comment: 'Superb food quality. The live Sajji station was the highlight of the event.', rating: 5.0, date: '1 month ago'),
    ],
  ),
  // --- Decor (2) ---
  Vendor(
    id: 'v5',
    name: 'Elite Sound & Lights',
    category: 'Decor',
    location: 'Islamabad • Stage & Ambience',
    rating: '4.8',
    images: [
      'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Elite Sound & Lights designs mesmerizing visual themes with expert staging, customized uplighting, floral drops, and premium audio setups. We transform standard marquees and lawns into breathtaking dreamscapes matching your personal style.',
    estimatedPrice: 'Rs. 350,000 (Full decor package)',
    reviews: [
      VendorReview(reviewerName: 'Mariam Raza', comment: 'They transformed the simple venue into a fairytale garden. Unbelievable lighting design!', rating: 4.8, date: '1 month ago'),
      VendorReview(reviewerName: 'Ahmed Bilal', comment: 'Excellent sound coordination. Highly recommend their fairy lights setup.', rating: 4.8, date: '1 week ago'),
    ],
  ),
  Vendor(
    id: 'v6',
    name: 'Opulent Events & Decor',
    category: 'Decor',
    location: 'Lahore • Royal Shehnai Themes',
    rating: '4.9',
    images: [
      'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1527529482837-4698179dc6ce?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Opulent Events specializes in luxury floral stage installations, custom wedding backdrops, walk-through entrance gates, and royal table settings. We focus on premium detailing and elegant themes like Rose Gold Blush and Royal Mughal Red.',
    estimatedPrice: 'Rs. 500,000 (Premium package)',
    reviews: [
      VendorReview(reviewerName: 'Zara Sheikh', comment: 'Breathtaking entrance and stage design. Extremely cooperative team.', rating: 5.0, date: '2 months ago'),
    ],
  ),
  // --- Photography / Media Production (2) ---
  Vendor(
    id: 'v7',
    name: 'Cinematic Studios',
    category: 'Photography',
    location: 'Lahore • Drone & Candid',
    rating: '4.9',
    images: [
      'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1453060113865-968ce1ad0570?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1520854221256-17451cc3599a?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Cinematic Studios is a team of passionate photographers and filmmakers specializing in high-definition candid wedding photography, cinematic wedding films, drone coverage, and pre-wedding shoots. We capture your emotional moments forever.',
    estimatedPrice: 'Rs. 250,000 (2-Day full coverage)',
    reviews: [
      VendorReview(reviewerName: 'Omer Farooq', comment: 'The highlights video made everyone cry. Truly professional drone shots and candid photos.', rating: 5.0, date: '1 month ago'),
      VendorReview(reviewerName: 'Mahnoor Ali', comment: 'Fantastic editing. They captured all the fun and emotions perfectly.', rating: 4.8, date: '3 weeks ago'),
    ],
  ),
  Vendor(
    id: 'v8',
    name: 'Artistic Clicks',
    category: 'Photography',
    location: 'Karachi • Portraits & Traditional',
    rating: '4.7',
    images: [
      'https://images.unsplash.com/photo-1453060113865-968ce1ad0570?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1520854221256-17451cc3599a?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Artistic Clicks delivers exceptional wedding portraits, traditional coverage, and premium photobooks. We focus on natural lighting and capturing detailed expressions to showcase the heritage and emotions of your shadi.',
    estimatedPrice: 'Rs. 180,000 (Standard package)',
    reviews: [
      VendorReview(reviewerName: 'Kamil Shah', comment: 'Excellent portraits and timely delivery of the album. Great value for money.', rating: 4.7, date: '2 months ago'),
    ],
  ),
  // --- SRS §1.4: Pyrotechnics & Effects (2) ---
  Vendor(
    id: 'v9',
    name: 'FireStar Pyrotechnics',
    category: 'Pyrotechnics',
    location: 'Lahore • Indoor & Outdoor FX',
    rating: '4.8',
    images: [
      'https://images.unsplash.com/photo-1498931299472-f7a63a5a1cfa?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1533230408708-8f9f91d1235a?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1467810563316-b5476525c0f9?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'FireStar Pyrotechnics specializes in safe indoor cold sparkler fountains, synchronized firework displays, fog machine effects, and LED sparkler exits. All effects are licensed and safety-certified for wedding venues.',
    estimatedPrice: 'Rs. 120,000 (Full show package)',
    reviews: [
      VendorReview(reviewerName: 'Ali Hassan', comment: 'The cold sparkler entrance was breathtaking! Guests were amazed. 100% safe.', rating: 5.0, date: '2 weeks ago'),
    ],
  ),
  Vendor(
    id: 'v10',
    name: 'Blaze Effects Co.',
    category: 'Pyrotechnics',
    location: 'Islamabad • Sparkler & Fog FX',
    rating: '4.6',
    images: [
      'https://images.unsplash.com/photo-1533230408708-8f9f91d1235a?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1498931299472-f7a63a5a1cfa?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1467810563316-b5476525c0f9?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Blaze Effects Co. brings the magic to your wedding with professional-grade fog machines, confetti cannons, CO2 jets, and choreographed sparkler displays. Licensed operators with safety certificates for every event.',
    estimatedPrice: 'Rs. 85,000 (Standard package)',
    reviews: [
      VendorReview(reviewerName: 'Fatima Noor', comment: 'Amazing fog effects and confetti cannons for the entrance! Great coordination with DJ.', rating: 4.6, date: '1 month ago'),
    ],
  ),
  // --- SRS §1.4: Luxury Logistics (2) ---
  Vendor(
    id: 'v11',
    name: 'Royal Rides Lahore',
    category: 'Logistics',
    location: 'Lahore • Luxury Fleet',
    rating: '4.9',
    images: [
      'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1503376780353-7e6692767b70?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Royal Rides provides premium wedding transport including decorated Mercedes S-Class, Rolls Royce Phantom, vintage classic cars, and luxury coach buses for baraat and guest transfers. All vehicles include professional chauffeurs and floral decorations.',
    estimatedPrice: 'Rs. 150,000 (Per day fleet)',
    reviews: [
      VendorReview(reviewerName: 'Bilal Ahmed', comment: 'The Rolls Royce for baraat was absolutely stunning. Professional driver and on-time service.', rating: 5.0, date: '3 weeks ago'),
    ],
  ),
  Vendor(
    id: 'v12',
    name: 'Premier Transport Services',
    category: 'Logistics',
    location: 'Karachi • Guest Shuttles & VIP',
    rating: '4.5',
    images: [
      'https://images.unsplash.com/photo-1503376780353-7e6692767b70?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1605559424843-9e4c228bf1c2?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Premier Transport specializes in wedding guest logistics including air-conditioned shuttle buses, VIP sedan services, and airport pickup for out-of-town guests. We handle complete transportation planning for multi-day wedding events.',
    estimatedPrice: 'Rs. 80,000 (Guest shuttle package)',
    reviews: [
      VendorReview(reviewerName: 'Saad Khan', comment: 'Organized shuttles for 200 guests across 3 events. Extremely reliable and punctual.', rating: 4.5, date: '1 month ago'),
    ],
  ),
  // --- SRS §1.4: Apparel & Grooming (2) ---
  Vendor(
    id: 'v13',
    name: 'Nomi Ansari Bridals',
    category: 'Apparel',
    location: 'Lahore • Designer Bridals',
    rating: '4.9',
    images: [
      'https://images.unsplash.com/photo-1594463750939-ebb28c3f7f75?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1583391733981-8b530523120e?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1610030469668-6bea81ef59d3?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Nomi Ansari Bridals is a premier bridal couture studio offering custom-designed lehengas, formal sherwanis, family matching outfits, and complete styling packages. We create bespoke pieces that blend tradition with contemporary elegance.',
    estimatedPrice: 'Rs. 350,000 (Bridal collection)',
    reviews: [
      VendorReview(reviewerName: 'Ayesha Malik', comment: 'The bridal lehenga was a dream come true. Perfect stitching and color match!', rating: 5.0, date: '2 months ago'),
    ],
  ),
  Vendor(
    id: 'v14',
    name: 'Glamour Salon & Spa',
    category: 'Apparel',
    location: 'Islamabad • Bridal Makeup & Grooming',
    rating: '4.7',
    images: [
      'https://images.unsplash.com/photo-1583391733981-8b530523120e?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1594463750939-ebb28c3f7f75?q=80&w=800&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1610030469668-6bea81ef59d3?q=80&w=800&auto=format&fit=crop',
    ],
    description: 'Glamour Salon offers premium bridal makeup, hairstyling, mehndi application, skincare pre-wedding treatments, and day-of-event grooming services for both bride and groom. Our makeup artists specialize in both traditional and western looks.',
    estimatedPrice: 'Rs. 85,000 (Full bridal package)',
    reviews: [
      VendorReview(reviewerName: 'Hira Batool', comment: 'Stunning bridal makeup. Lasted all day without touch-ups. Highly recommended!', rating: 4.7, date: '1 month ago'),
    ],
  ),
];

final allVendorsProvider = StreamProvider<List<Vendor>>((ref) {
  return FirebaseFirestore.instance.collection('vendors').snapshots().asyncMap((snapshot) async {
    if (snapshot.docs.isEmpty) {
      seedVendorsToFirestore();
      return localDummyVendors;
    }

    Map<String, Map<String, dynamic>> profileDataMap = {};
    try {
      final profilesSnap = await FirebaseFirestore.instance.collection('vendor_profile').get();
      for (var doc in profilesSnap.docs) {
        profileDataMap[doc.id] = doc.data();
      }
    } catch (e) {
      print("Error fetching vendor_profile map: $e");
    }

    return snapshot.docs.map((doc) {
      final vendorData = Map<String, dynamic>.from(doc.data());
      final profileData = profileDataMap[doc.id];
      if (profileData != null) {
        final profileOutside = profileData['outsidePictures'] as List<dynamic>? ?? [];
        final profileInside = profileData['insidePictures'] as List<dynamic>? ?? [];
        final profileImages = profileData['images'] as List<dynamic>? ?? [];

        final existingOutside = vendorData['outsidePictures'] as List<dynamic>? ?? [];
        final existingInside = vendorData['insidePictures'] as List<dynamic>? ?? [];
        final existingImages = vendorData['images'] as List<dynamic>? ?? [];

        final mergedOutside = [...existingOutside, ...profileOutside].map((e) => e.toString()).where((e) => e.isNotEmpty).toSet().toList();
        final mergedInside = [...existingInside, ...profileInside].map((e) => e.toString()).where((e) => e.isNotEmpty).toSet().toList();
        final mergedImages = [...existingImages, ...profileImages, ...mergedOutside, ...mergedInside].map((e) => e.toString()).where((e) => e.isNotEmpty).toSet().toList();

        vendorData['outsidePictures'] = mergedOutside;
        vendorData['insidePictures'] = mergedInside;
        vendorData['images'] = mergedImages;

        if ((vendorData['name'] == null || vendorData['name'] == '') && profileData['businessName'] != null) {
          vendorData['name'] = profileData['businessName'];
        }

        // Auto-sync back to vendors document in Firestore if missing image fields
        if ((existingOutside.isEmpty && mergedOutside.isNotEmpty) || 
            (existingInside.isEmpty && mergedInside.isNotEmpty) || 
            (existingImages.isEmpty && mergedImages.isNotEmpty)) {
          FirebaseFirestore.instance.collection('vendors').doc(doc.id).set({
            'outsidePictures': mergedOutside,
            'insidePictures': mergedInside,
            'images': mergedImages,
          }, SetOptions(merge: true)).catchError((e) => print("Error syncing vendor images to Firestore: $e"));
        }
      }

      return Vendor.fromMap(vendorData, doc.id);
    }).where((vendor) => vendor.accountStatus != 'suspended' && vendor.hasAcceptedTerms).toList();
  }).handleError((err) {
    print("Error listening to Firestore vendors, using local fallback: $err");
    return localDummyVendors;
  });
});

final filteredVendorsProvider = Provider<AsyncValue<List<Vendor>>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final vendorsAsync = ref.watch(allVendorsProvider);
  final authState = ref.watch(authProvider);
  
  final plans = ref.watch(subscriptionPlansProvider);
  
  return vendorsAsync.whenData((vendors) {
    var filtered = vendors;
    
    if (authState.city != null && authState.city!.isNotEmpty) {
      // Basic match on location string
      final userCityLower = authState.city!.split(',').first.trim().toLowerCase();
      filtered = filtered.where((v) => v.location.toLowerCase().contains(userCityLower)).toList();
    }
    
    if (category != 'All') {
      filtered = filtered.where((v) => v.category == category).toList();
    }
    
    // Sort by subscription tier price (highest to lowest)
    filtered.sort((a, b) {
      final planA = plans.firstWhere((p) => p.id == a.subscriptionTier, 
          orElse: () => const SubscriptionPlan(id: '', name: '', price: 0, colorHex: '000000', iconName: ''));
      final planB = plans.firstWhere((p) => p.id == b.subscriptionTier, 
          orElse: () => const SubscriptionPlan(id: '', name: '', price: 0, colorHex: '000000', iconName: ''));
      
      // Secondary sort by rating if prices are equal
      if (planA.price == planB.price) {
        final ratingA = double.tryParse(a.rating) ?? 0.0;
        final ratingB = double.tryParse(b.rating) ?? 0.0;
        return ratingB.compareTo(ratingA);
      }
      return planB.price.compareTo(planA.price);
    });
    
    return filtered;
  });
});


// 2. Smart Planner State — Pure RAG Chatbot (no external API keys)
enum _QueryIntent { greeting, budget, vendorSearch, weddingTips, offTopic }

class ChatNotifier extends Notifier<List<ChatMessage>> {

  @override
  List<ChatMessage> build() {
    return [
      ChatMessage(
        id: DateTime.now().toString(),
        text: 'Welcome to your ShadiSphere Assistant! ✨\n\nI can help you find top-rated vendors and create an optimized budget for your dream wedding.\n\nTry asking:\n• "Recommend catering services in Lahore"\n• "Suggest photographers in Karachi under Rs. 100,000"\n• "My budget is 20 Lakhs for 300 guests in Islamabad"\n• "Tips for mehndi planning"',
        isAI: true,
      )
    ];
  }

  double budget = 0;
  bool isWaitingForGuestCount = false;
  double pendingBudget = 0;
  int pendingGuestCount = 0;
  bool isAskingCategories = false;
  int currentCategoryIndex = 0;
  List<BudgetAllocation> allCategories = [];
  List<BudgetAllocation> selectedCategories = [];

  void clearChatState() {
    isWaitingForGuestCount = false;
    pendingBudget = 0;
    pendingGuestCount = 0;
    isAskingCategories = false;
    currentCategoryIndex = 0;
    allCategories = [];
    selectedCategories = [];
  }

  void clearChat() {
    budget = 0;
    clearChatState();
    state = [
      ChatMessage(
        id: DateTime.now().toString(),
        text: 'Welcome to your ShadiSphere Assistant! ✨\n\nI can help you find top-rated vendors and create an optimized budget for your dream wedding.\n\nTry asking:\n• "Recommend catering services in Lahore"\n• "Suggest photographers in Karachi under Rs. 100,000"\n• "My budget is 20 Lakhs for 300 guests in Islamabad"\n• "Tips for mehndi planning"',
        isAI: true,
      )
    ];
  }

  void editMessage(int index, String newText) {
    if (index <= 0 || index >= state.length) return;
    
    // Truncate state to just before this message
    state = state.sublist(0, index);
    budget = 0;
    
    // Send the new edited message
    sendMessage(newText);
  }

  // --- RAG Retrieval ---
  List<Vendor> _retrieveRelevantVendors(String query) {
    final lowerQuery = query.toLowerCase();
    
    // Get all vendors (fall back to localDummyVendors if async value is not loaded yet)
    List<Vendor> allVendors = [];
    try {
      final asyncVendors = ref.read(allVendorsProvider);
      allVendors = asyncVendors.value ?? localDummyVendors;
    } catch (_) {
      allVendors = localDummyVendors;
    }
    
    // Match based on category keywords
    List<String> matchedCategories = [];
    if (lowerQuery.contains('venue') || lowerQuery.contains('hall') || lowerQuery.contains('marquee')) {
      matchedCategories.add('Venues');
    }
    if (lowerQuery.contains('cater') || lowerQuery.contains('food') || lowerQuery.contains('menu')) {
      matchedCategories.add('Catering');
    }
    if (lowerQuery.contains('decor') || lowerQuery.contains('stage') || lowerQuery.contains('flower') || lowerQuery.contains('light')) {
      matchedCategories.add('Decor');
    }
    if (lowerQuery.contains('photo') || lowerQuery.contains('video') || lowerQuery.contains('shoot') || lowerQuery.contains('camera') || lowerQuery.contains('media') || lowerQuery.contains('pic')) {
      matchedCategories.add('Photography');
    }
    if (lowerQuery.contains('pyro') || lowerQuery.contains('firework') || lowerQuery.contains('spark') || lowerQuery.contains('effect')) {
      matchedCategories.add('Pyrotechnics');
    }
    if (lowerQuery.contains('logist') || lowerQuery.contains('car') || lowerQuery.contains('ride') || lowerQuery.contains('transport')) {
      matchedCategories.add('Logistics');
    }
    if (lowerQuery.contains('apparel') || lowerQuery.contains('dress') || lowerQuery.contains('groom') || lowerQuery.contains('bride') || lowerQuery.contains('makeup') || lowerQuery.contains('salon')) {
      matchedCategories.add('Apparel');
    }
    
    // Match based on city keywords
    String? matchedCity;
    if (lowerQuery.contains('lahore')) {
      matchedCity = 'lahore';
    } else if (lowerQuery.contains('karachi')) {
      matchedCity = 'karachi';
    } else if (lowerQuery.contains('islamabad')) {
      matchedCity = 'islamabad';
    } else if (lowerQuery.contains('faisalabad')) {
      matchedCity = 'faisalabad';
    } else {
      try {
        final authState = ref.read(authProvider);
        if (authState.city != null && authState.city!.isNotEmpty) {
           matchedCity = authState.city!.split(',').first.trim().toLowerCase();
        }
      } catch (_) {}
    }

    // Filter vendors
    return allVendors.where((v) {
      bool categoryMatch = matchedCategories.isEmpty || matchedCategories.contains(v.category);
      bool cityMatch = matchedCity == null || v.location.toLowerCase().contains(matchedCity);
      bool nameMatch = lowerQuery.contains(v.name.toLowerCase());
      
      return (categoryMatch && cityMatch) || nameMatch;
    }).toList();
  }

  // --- Intent Detection ---
  _QueryIntent _detectIntent(String query) {
    final lower = query.toLowerCase().trim();

    // Greeting
    if (RegExp(r'^(hi|hello|hey|assalam|salam|aoa|greetings|good morning|good evening)\b').hasMatch(lower)) {
      return _QueryIntent.greeting;
    }

    // Budget query
    if (lower.contains('budget') || lower.contains('lakh') || lower.contains('lac') ||
        lower.contains('how much') || lower.contains('cost') || lower.contains('price') ||
        lower.contains('afford') || lower.contains('expense') || lower.contains('allocat')) {
      return _QueryIntent.budget;
    }
    // Vendor search
    final vendorKeywords = [
      'venue', 'hall', 'marquee', 'cater', 'food', 'menu',
      'decor', 'stage', 'flower', 'light', 'photo', 'video',
      'shoot', 'camera', 'media', 'pyro', 'firework', 'spark',
      'logist', 'car', 'ride', 'transport', 'apparel', 'dress',
      'groom', 'bride', 'makeup', 'salon', 'recommend', 'suggest',
      'find', 'show', 'best', 'top', 'vendor',
    ];
    if (vendorKeywords.any((kw) => lower.contains(kw))) {
      return _QueryIntent.vendorSearch;
    }

    // Also detect budget if there's a large number (Moved here so it doesn't override vendor search)
    final numStr = query.replaceAll(RegExp(r'[^0-9]'), '');
    if (numStr.isNotEmpty) {
      final parsed = double.tryParse(numStr);
      if (parsed != null && parsed > 10000) {
        return _QueryIntent.budget;
      }
    }

    // Wedding tips
    final weddingKeywords = [
      'wedding', 'shadi', 'nikah', 'mehndi', 'baraat', 'walima',
      'rukhsati', 'tips', 'checklist', 'plan', 'advice', 'idea',
      'tradition', 'custom', 'guest', 'invitation', 'card',
    ];
    if (weddingKeywords.any((kw) => lower.contains(kw))) {
      return _QueryIntent.weddingTips;
    }

    return _QueryIntent.offTopic;
  }

  // --- Response Generation ---
  String _generateRAGResponse(String userText, List<Vendor> retrievedVendors) {
    final intent = _detectIntent(userText);
    final lower = userText.toLowerCase();

    switch (intent) {
      case _QueryIntent.greeting:
        return _greetingResponse();
      case _QueryIntent.budget:
        return _budgetResponse(userText, retrievedVendors);
      case _QueryIntent.vendorSearch:
        return _vendorSearchResponse(userText, retrievedVendors);
      case _QueryIntent.weddingTips:
        return _weddingTipsResponse(lower);
      case _QueryIntent.offTopic:
        return _offTopicResponse();
    }
  }

  String _greetingResponse() {
    return '✨ Assalam-o-Alaikum! Welcome to ShadiSphere!\n\n'
        'I\'m your dedicated wedding planning assistant. I can help you with:\n\n'
        '💍 **Vendor Recommendations** — Find top-rated vendors by category & city\n'
        '💰 **Budget Planning** — Get optimized budget breakdowns using our SRS formula\n'
        '📋 **Wedding Tips** — Expert advice for mehndi, baraat, walima & more\n\n'
        'How can I assist you today?';
  }

  String _budgetResponse(String userText, List<Vendor> vendors) {
    // Extract budget number
    final numStr = userText.replaceAll(RegExp(r'[^0-9]'), '');
    double parsedBudget = 0;
    if (numStr.isNotEmpty) {
      parsedBudget = double.tryParse(numStr) ?? 0;
    }

    // Handle "lakh" multiplier
    if (userText.toLowerCase().contains('lakh') || userText.toLowerCase().contains('lac')) {
      if (parsedBudget > 0 && parsedBudget < 1000) {
        parsedBudget *= 100000;
      }
    }

    if (parsedBudget <= 0) {
      final allocations = ref.read(budgetConfigProvider).value ?? defaultBudgetAllocations;
      final allocStr = allocations.map((a) => '• ${a.category}: ${a.percentage}%').join('\n');
      return '💰 I\'d love to help you plan your budget!\n\n'
          'Please share your total wedding budget amount (e.g., "My budget is 20 Lakhs") '
          'and I\'ll generate an optimized allocation breakdown across all 7 wedding categories.\n\n'
          '**Our allocation formula:**\n$allocStr';
    }

    // Extract guest count if mentioned
    int guestCount = 0;
    final guestMatch = RegExp(r'(\d+)\s*(guests?|log|mehman)').firstMatch(userText.toLowerCase());
    if (guestMatch != null) {
      guestCount = int.tryParse(guestMatch.group(1)!) ?? 0;
    }

    String formatAmt(double amt) => 'Rs. ${amt.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    if (guestCount <= 0 && isWaitingForGuestCount == false) {
      // We have a budget but no guest count. Prompt the user!
      pendingBudget = parsedBudget;
      isWaitingForGuestCount = true;
      return 'Great! A budget of ${formatAmt(parsedBudget)} is a fantastic start.\n\nTo give you the most accurate breakdown (especially for catering and venue sizing), **how many guests are you expecting?**\n*(e.g., "300 guests")*';
    }

    budget = parsedBudget;

    final buf = StringBuffer();
    buf.writeln('💰 **Budget Breakdown — ${formatAmt(parsedBudget)}**');
    if (guestCount > 0) {
      buf.writeln('👥 Guest Count: $guestCount');
    }
    buf.writeln('');
    buf.writeln('| Category | Allocation | Amount |');
    buf.writeln('|---|---|---|');
    
    final allocations = ref.read(budgetConfigProvider).value ?? defaultBudgetAllocations;
    for (var a in allocations) {
      buf.writeln('| ${a.emoji} ${a.category} | ${a.percentage}% | ${formatAmt(parsedBudget * (a.percentage / 100))} |');
    }
    buf.writeln('');

    if (guestCount > 0) {
      final cateringAlloc = allocations.firstWhere((a) => a.category.toLowerCase().contains('cater'), orElse: () => const BudgetAllocation(category: 'Catering', percentage: 40));
      final perHead = (parsedBudget * (cateringAlloc.percentage / 100)) / guestCount;
      buf.writeln('📊 **Per-head catering budget:** ${formatAmt(perHead)}');
      buf.writeln('');
    }

    // Add vendor suggestions from retrieved data
    if (vendors.isNotEmpty) {
      buf.writeln('🏆 **Matching Vendors from Our Database:**');
      for (var v in vendors.take(3)) {
        final priceStr = v.estimatedPrice.isNotEmpty ? ' — ${v.estimatedPrice}' : '';
        buf.writeln('• **${v.name}** (${v.category}) — ${v.location} — ⭐ ${v.rating}$priceStr');
      }
      buf.writeln('');
    }

    buf.writeln('💡 *Ask me about specific vendor categories for detailed recommendations!*');
    return buf.toString();
  }

  String _vendorSearchResponse(String userText, List<Vendor> vendors) {
    if (vendors.isEmpty) {
      // Determine what was being searched
      String searchTerm = 'vendors';
      final categories = {
        'venue': 'Venues', 'hall': 'Venues', 'marquee': 'Venues',
        'cater': 'Catering', 'food': 'Catering',
        'decor': 'Decor', 'photo': 'Photography', 'video': 'Photography',
        'pyro': 'Pyrotechnics', 'logist': 'Logistics', 'transport': 'Logistics',
        'apparel': 'Apparel', 'dress': 'Apparel', 'makeup': 'Apparel', 'salon': 'Apparel',
      };
      for (var entry in categories.entries) {
        if (userText.toLowerCase().contains(entry.key)) {
          searchTerm = entry.value;
          break;
        }
      }

      return '🔍 I searched our database but couldn\'t find **$searchTerm** matching your specific criteria.\n\n'
          'Try broadening your search:\n'
          '• Remove the city filter (e.g., "Recommend catering services")\n'
          '• Check a different category\n'
          '• Browse all vendors in the Discover tab\n\n'
          '**Available categories:** Venues, Catering, Decor, Photography, Pyrotechnics, Logistics, Apparel & Grooming';
    }

    final buf = StringBuffer();
    buf.writeln('✅ **Found ${vendors.length} matching vendor${vendors.length > 1 ? 's' : ''} in our database:**\n');

    for (var i = 0; i < vendors.length; i++) {
      final v = vendors[i];
      buf.writeln('**${i + 1}. ${v.name}** ⭐ ${v.rating}/5.0');
      buf.writeln('   📍 ${v.location}');
      if (v.estimatedPrice.isNotEmpty) {
        buf.writeln('   💰 ${v.estimatedPrice}');
      }
      buf.writeln('   📝 ${v.description.length > 120 ? '${v.description.substring(0, 120)}...' : v.description}');
      if (v.reviews.isNotEmpty) {
        buf.writeln('   💬 "${v.reviews.first.comment}" — ${v.reviews.first.reviewerName}');
      }
      buf.writeln('');
    }

    buf.writeln('💡 *You can book any of these vendors from the Discover tab or ask me for budget planning!*');
    return buf.toString();
  }

  String _weddingTipsResponse(String query) {
    if (query.contains('mehndi')) {
      return '🌿 **Mehndi Night Tips:**\n\n'
          '1. **Book a mehndi artist** 2-3 months in advance — top artists get booked fast!\n'
          '2. **Decor theme:** Yellow, green & orange marigold themes are timeless\n'
          '3. **Music:** Hire a dholki or DJ for the sangeet — it sets the mood!\n'
          '4. **Food:** Light chaat, gol gappay, and BBQ stations work perfectly\n'
          '5. **Activities:** Mehndi games, couple dance, family performances\n\n'
          '💰 **Typical budget:** Rs. 150,000 – Rs. 500,000\n'
          '🔍 *Ask me to recommend Decor or Catering vendors for your mehndi!*';
    } else if (query.contains('baraat')) {
      return '🎊 **Baraat Day Tips:**\n\n'
          '1. **Groom\'s entry:** Plan a grand entrance — decorated car, dholki, fireworks\n'
          '2. **Venue:** Ensure adequate parking and VIP seating\n'
          '3. **Catering:** Multi-tier menu with BBQ, biryani & dessert counters\n'
          '4. **Photography:** Book candid + drone photography for cinematic coverage\n'
          '5. **Timeline:** Start ceremonies early to avoid delays\n\n'
          '💰 **Typical budget:** Rs. 800,000 – Rs. 2,500,000\n'
          '🔍 *Ask me to find venues, caterers, or photographers for your baraat!*';
    } else if (query.contains('walima') || query.contains('rukhsati')) {
      return '🌹 **Walima Reception Tips:**\n\n'
          '1. **Keep it elegant:** More formal and sophisticated than the baraat\n'
          '2. **Decor:** White, ivory & gold themes with floral centerpieces\n'
          '3. **Guest count:** Usually smaller, more intimate — 200-400 guests\n'
          '4. **Menu:** Fine dining style with appetizers, main course & dessert\n'
          '5. **Photo booth:** Set up a themed photo corner for guests\n\n'
          '💰 **Typical budget:** Rs. 400,000 – Rs. 1,200,000\n'
          '🔍 *Need vendor recommendations for your walima? Just ask!*';
    } else if (query.contains('nikah')) {
      return '📿 **Nikah Ceremony Tips:**\n\n'
          '1. **Venue:** Mosque or home setting — intimate and spiritual\n'
          '2. **Documentation:** Ensure Nikah nama is properly filled with witnesses\n'
          '3. **Haq Mehr:** Discuss and agree upon before the ceremony\n'
          '4. **Refreshments:** Traditional chai, mithai & light snacks\n'
          '5. **Photography:** Tasteful, modest coverage of the ceremony\n\n'
          '💡 *The nikah is the most blessed part — keep it simple and meaningful.*';
    } else if (query.contains('checklist') || query.contains('plan')) {
      return '📋 **Complete Wedding Planning Checklist:**\n\n'
          '**6-12 Months Before:**\n'
          '• Set overall budget\n'
          '• Book venue & caterer\n'
          '• Start outfit shopping\n\n'
          '**3-6 Months Before:**\n'
          '• Book photographer & videographer\n'
          '• Finalize decor theme\n'
          '• Send invitations / save-the-dates\n\n'
          '**1-3 Months Before:**\n'
          '• Book logistics (transport, pyrotechnics)\n'
          '• Bridal makeup trial\n'
          '• Finalize mehndi artist\n\n'
          '**1 Week Before:**\n'
          '• Confirm all vendor bookings\n'
          '• Final dress fittings\n'
          '• Prepare emergency kit (safety pins, tissues, etc.)\n\n'
          '💡 *Check your progress in the Checklist on the Home tab!*';
    } else if (query.contains('guest') || query.contains('invitation')) {
      return '👥 **Guest Management Tips:**\n\n'
          '1. **Create a master list** organized by family groups (bride\'s side, groom\'s side)\n'
          '2. **Set guest limits** per event — mehndi (100-300), baraat (300-800), walima (200-500)\n'
          '3. **Invitation timeline:** Send 6-8 weeks before for local, 3 months for abroad\n'
          '4. **RSVP tracking:** Use a spreadsheet to track confirmations\n'
          '5. **Seating plan:** Arrange tables by family groups, keep VIPs near stage\n\n'
          '💰 **Budget impact:** Catering = per_head_cost × guest_count (40% of total budget)\n'
          '🔍 *Tell me your budget and guest count for a personalized breakdown!*';
    } else {
      return '💒 **Pakistani Wedding Planning Guide:**\n\n'
          'A traditional Pakistani wedding typically includes:\n\n'
          '1. **Dholki / Sangeet** — Pre-wedding musical gatherings\n'
          '2. **Mehndi** — Henna night with dholak, dancing & fun\n'
          '3. **Baraat** — The groom\'s wedding procession & main event\n'
          '4. **Nikah** — The Islamic marriage ceremony\n'
          '5. **Rukhsati** — The bride\'s farewell from her family\n'
          '6. **Walima** — Reception hosted by the groom\'s family\n\n'
          '**Key vendor categories:** Venues, Catering, Decor, Photography, Pyrotechnics, Logistics, Apparel\n\n'
          '💡 *Ask me about any specific event (e.g., "mehndi tips") or say "My budget is X lakhs" for a custom plan!*';
    }
  }

  String _offTopicResponse() {
    return '🙏 I appreciate your query, but I\'m specifically designed to assist with **Pakistani wedding planning** only.\n\n'
        'I can help you with:\n'
        '• 💍 Vendor recommendations (Venues, Catering, Decor, etc.)\n'
        '• 💰 Budget planning and allocation\n'
        '• 📋 Wedding event tips (Mehndi, Baraat, Walima, Nikah)\n'
        '• 👥 Guest management advice\n\n'
        'Please ask a wedding-related question and I\'ll do my best to help! ✨';
  }

  // --- Main send flow ---
  void sendMessage(String text) {
    // Add user message
    state = [...state, ChatMessage(id: DateTime.now().toString(), text: text, isAI: false)];
    
    final lowerText = text.toLowerCase();

    // Check if we are in the middle of a budget conversation
    if (isWaitingForGuestCount) {
      if (lowerText.contains('cancel') || lowerText.contains('stop')) {
        clearChatState();
        _addAIMessageWithText('Budget planning cancelled. How else can I help you?');
        return;
      }
      
      final numStr = text.replaceAll(RegExp(r'[^0-9]'), '');
      if (numStr.isNotEmpty) {
        final parsedGuests = int.tryParse(numStr) ?? 0;
        if (parsedGuests > 0) {
           isWaitingForGuestCount = false;
           pendingGuestCount = parsedGuests;
           
           allCategories = ref.read(budgetConfigProvider).value ?? defaultBudgetAllocations;
           selectedCategories = [];
           currentCategoryIndex = 0;
           isAskingCategories = true;

           if (allCategories.isNotEmpty) {
             _addAIMessageWithText('Got it! $parsedGuests guests.\n\nNow, let\'s personalize your breakdown. I will ask you about a few services. Reply "yes" or "no" for each.\n\nDo you need **${allCategories[0].category}** services?');
           } else {
             _finalizeBudget();
           }
           return;
        }
      }
      
      _addAIMessageWithText('I didn\'t quite catch the guest count. Please reply with a number (e.g., "300"), or type "cancel" to stop.');
      return;
    }

    if (isAskingCategories) {
      if (lowerText.contains('cancel') || lowerText.contains('stop')) {
        clearChatState();
        _addAIMessageWithText('Budget planning cancelled. How else can I help you?');
        return;
      }

      final isYes = lowerText.contains('yes') || lowerText.contains('yeah') || lowerText.contains('yep') || lowerText.contains('sure') || lowerText.contains('ok') || lowerText.contains('do');
      final isNo = lowerText.contains('no') || lowerText.contains('nah') || lowerText.contains('nope') || lowerText.contains('don\'t');

      if (!isYes && !isNo) {
        _addAIMessageWithText('Please answer "yes" or "no" for **${allCategories[currentCategoryIndex].category}** services. Type "cancel" to stop.');
        return;
      }

      if (isYes) {
        selectedCategories.add(allCategories[currentCategoryIndex]);
      }

      currentCategoryIndex++;

      if (currentCategoryIndex < allCategories.length) {
        _addAIMessageWithText('Do you need **${allCategories[currentCategoryIndex].category}** services?');
      } else {
        isAskingCategories = false;
        _finalizeBudget();
      }
      return;
    }

    // Check for vendor-specific requests for inline cards (existing "show X" flow)
    if (lowerText.contains('show') && lowerText.contains('venue')) {
      _addAIMessageWithVendor('Here are some top-rated Wedding Venues from our platform:', 'Venues');
      return;
    } else if (lowerText.contains('show') && lowerText.contains('cater')) {
      _addAIMessageWithVendor('Here are some of the best Catering services available:', 'Catering');
      return;
    } else if (lowerText.contains('show') && lowerText.contains('decor')) {
      _addAIMessageWithVendor('Here are some stunning Decor options for your event:', 'Decor');
      return;
    } else if (lowerText.contains('show') && (lowerText.contains('photo') || lowerText.contains('media'))) {
      _addAIMessageWithVendor('Here are professional Photography teams you can book:', 'Photography');
      return;
    } else if (lowerText.contains('show') && lowerText.contains('pyro')) {
      _addAIMessageWithVendor('Here are our Pyrotechnics & Effects vendors:', 'Pyrotechnics');
      return;
    } else if (lowerText.contains('show') && lowerText.contains('logist')) {
      _addAIMessageWithVendor('Here are our Luxury Logistics providers:', 'Logistics');
      return;
    } else if (lowerText.contains('show') && lowerText.contains('apparel')) {
      _addAIMessageWithVendor('Here are our Apparel & Grooming vendors:', 'Apparel');
      return;
    }

    // RAG: Retrieve relevant vendors
    final retrievedVendors = _retrieveRelevantVendors(text);

    // Generate response using RAG
    _processRAGResponse(text, retrievedVendors);
  }

  void _processRAGResponse(String userText, List<Vendor> retrievedVendors) {
    // Add loading indicator
    final loadingId = DateTime.now().millisecondsSinceEpoch.toString();
    state = [...state, ChatMessage(id: loadingId, text: '...', isAI: true, isLoading: true)];

    // Simulate a brief processing delay for natural feel
    Future.delayed(const Duration(milliseconds: 600), () {
      final responseText = _generateRAGResponse(userText, retrievedVendors);

      // Remove loading indicator and add real response
      state = state.where((m) => m.id != loadingId).toList();
      state = [...state, ChatMessage(id: DateTime.now().toString(), text: responseText, isAI: true)];

      // If budget was parsed, also show the breakdown card
      if (budget > 0 && (userText.toLowerCase().contains('budget') || userText.toLowerCase().contains('guest') || userText.toLowerCase().contains('lakh') || userText.toLowerCase().contains('lac'))) {
        Future.delayed(const Duration(milliseconds: 500), () {
          state = [...state, ChatMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), text: '', isAI: true, isBreakdown: true)];
        });
      }
    });
  }

  void _addAIMessageWithVendor(String text, String category) {
    Future.delayed(const Duration(milliseconds: 400), () {
      state = [...state, ChatMessage(id: DateTime.now().toString(), text: text, isAI: true, isVendorRecommendation: true, recommendedCategory: category)];
    });
  }

  void _addAIMessageWithText(String text) {
    Future.delayed(const Duration(milliseconds: 400), () {
      state = [...state, ChatMessage(id: DateTime.now().toString(), text: text, isAI: true)];
    });
  }

  void _finalizeBudget() {
    budget = pendingBudget;
    String formatAmt(double amt) => 'Rs. ${amt.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    final buf = StringBuffer();
    buf.writeln('💰 **Customized Budget Breakdown — ${formatAmt(budget)}**');
    if (pendingGuestCount > 0) {
      buf.writeln('👥 Guest Count: $pendingGuestCount');
    }
    buf.writeln('');

    if (selectedCategories.isEmpty) {
      buf.writeln('You didn\'t select any services! I guess you\'re saving 100% of your budget! 😉');
    } else {
      buf.writeln('| Category | Allocation | Amount |');
      buf.writeln('|---|---|---|');

      double totalPercentage = selectedCategories.fold(0.0, (sum, item) => sum + item.percentage);
      
      for (var a in selectedCategories) {
        final normalizedPercentage = (a.percentage / totalPercentage) * 100;
        final amount = budget * (normalizedPercentage / 100);
        buf.writeln('| ${a.emoji} ${a.category} | ${normalizedPercentage.toStringAsFixed(1)}% | ${formatAmt(amount)} |');
      }
      buf.writeln('');
      
      try {
        final cateringAlloc = selectedCategories.firstWhere((a) => a.category.toLowerCase().contains('cater'));
        if (pendingGuestCount > 0) {
          final normalizedPercentage = (cateringAlloc.percentage / totalPercentage) * 100;
          final perHead = (budget * (normalizedPercentage / 100)) / pendingGuestCount;
          buf.writeln('📊 **Per-head catering budget:** ${formatAmt(perHead)}');
          buf.writeln('');
        }
      } catch (_) {}
      
      buf.writeln('💡 *Ask me to find vendors for any of these categories!*');
    }

    _addAIMessageWithText(buf.toString());

    // Do NOT render the static UI Breakdown card, because this one is highly customized and the markdown table is perfect!
    clearChatState();
  }
}


final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(ChatNotifier.new);

// 3. Shared Ledger State

// Generate unique ledger code: SS-XXX-XXX
// Uses timestamp-seeded Random + 6 random chars for collision resistance.
String _generateLedgerCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Removed ambiguous chars (I,O,0,1)
  final rng = Random(DateTime.now().microsecondsSinceEpoch);
  String part1 = List.generate(3, (_) => chars[rng.nextInt(chars.length)]).join();
  String part2 = List.generate(3, (_) => chars[rng.nextInt(chars.length)]).join();
  return 'SS-$part1-$part2';
}

// Provider for the user's own ledger code (stored in Firestore under user_ledgers/{uid})
// This is keyed by uid AND auto-invalidates when the auth state changes,
// ensuring no stale cross-user cache hits.
final userLedgerCodeProvider = FutureProvider.family<String?, String>((ref, uid) async {
  // Watch auth state so this provider auto-refreshes on login/logout
  ref.watch(authProvider.select((s) => s.userId));
  if (uid.isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance.collection('user_ledgers').doc(uid).get();
    if (doc.exists) {
      return doc.data()?['ledgerCode'] as String?;
    }
  } catch (e) {
    // Firestore not available
  }
  return null;
});

// Create a new ledger for a user
Future<String> createLedgerForUser(String uid, String displayName) async {
  // Check if user already has a ledger
  try {
    final existingDoc = await FirebaseFirestore.instance.collection('user_ledgers').doc(uid).get();
    if (existingDoc.exists && existingDoc.data()?['ledgerCode'] != null) {
      return existingDoc.data()!['ledgerCode'] as String;
    }
  } catch (_) {}

  // Generate unique code (retry if collision)
  String code = _generateLedgerCode();
  bool codeExists = true;
  int attempts = 0;
  while (codeExists && attempts < 10) {
    try {
      final codeDoc = await FirebaseFirestore.instance.collection('shared_ledgers').doc(code).get();
      codeExists = codeDoc.exists;
      if (codeExists) {
        code = _generateLedgerCode();
      }
    } catch (_) {
      codeExists = false;
    }
    attempts++;
  }

  // Create the shared ledger document
  try {
    await FirebaseFirestore.instance.collection('shared_ledgers').doc(code).set({
      'ownerUid': uid,
      'ownerName': displayName,
      'members': [
        {'uid': uid, 'name': displayName},
      ],
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Store mapping from user to their ledger code
    await FirebaseFirestore.instance.collection('user_ledgers').doc(uid).set({
      'ledgerCode': code,
    });
  } catch (_) {}

  return code;
}

// Join an existing shared ledger by code
Future<bool> joinSharedLedger(String code, String uid, String displayName) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('shared_ledgers').doc(code).get();
    if (!doc.exists) return false;

    // Don't allow joining your own ledger
    final data = doc.data() ?? {};
    if (data['ownerUid'] == uid) return false;

    // Add user to members list (avoid duplicates)
    final members = (data['members'] as List<dynamic>?) ?? [];
    final alreadyMember = members.any((m) => m['uid'] == uid);
    if (!alreadyMember) {
      await FirebaseFirestore.instance.collection('shared_ledgers').doc(code).update({
        'members': FieldValue.arrayUnion([
          {'uid': uid, 'name': displayName},
        ]),
      });
    }

    // Persist the joined ledger code in user_ledgers/{uid}
    // so it survives app restarts and re-logins
    await FirebaseFirestore.instance.collection('user_ledgers').doc(uid).set({
      'joinedLedgerCode': code,
    }, SetOptions(merge: true));

    return true;
  } catch (_) {
    return false;
  }
}

// Provider: Stream items for a given ledger code
final ledgerItemsProvider = StreamProvider.family<List<LedgerItem>, String>((ref, code) {
  if (code.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('shared_ledgers')
      .doc(code)
      .collection('items')
      .orderBy('addedAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => LedgerItem.fromFirestore(doc)).toList();
  }).handleError((_) {
    return <LedgerItem>[];
  });
});

// Provider: Stream the shared ledger metadata (members, owner, etc.)
final sharedLedgerMetaProvider = StreamProvider.family<SharedLedger?, String>((ref, code) {
  if (code.isEmpty) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection('shared_ledgers')
      .doc(code)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return SharedLedger.fromFirestore(doc);
  }).handleError((_) {
    return null;
  });
});

// Keep the old ledgerProvider for backward compatibility (reads from legacy collection)
final ledgerProvider = StreamProvider<List<LedgerItem>>((ref) {
  final uid = ref.watch(authProvider).userId;
  if (uid == null || uid.isEmpty) return Stream.value([]);
  
  return FirebaseFirestore.instance.collection('ledger')
      .where('addedBy', isEqualTo: uid)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => LedgerItem.fromFirestore(doc)).toList();
  });
});

Future<void> notifyLedgerMembers({
  required String ledgerCode,
  required String actorUid,
  required String title,
  required String message,
}) async {
  if (ledgerCode.isEmpty) return;
  final doc = await FirebaseFirestore.instance.collection('shared_ledgers').doc(ledgerCode).get();
  if (!doc.exists) return;
  
  final data = doc.data() as Map<String, dynamic>;
  final membersData = data['members'] as List<dynamic>? ?? [];
  final now = Timestamp.now();
  final batch = FirebaseFirestore.instance.batch();
  
  for (final m in membersData) {
    if (m['uid'] != actorUid) {
      final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notifRef, {
        'userId': m['uid'],
        'title': title,
        'message': message,
        'time': now,
        'isRead': false,
        'type': 'ledger',
      });
    }
  }
  await batch.commit();
}

// Add item to a shared ledger
Future<void> addLedgerItem(
  String category,
  String vendorName,
  double amount, {
  String ledgerCode = '',
  String addedBy = '',
  String addedByName = '',
  String? vendorId,
  String? eventDate,
  String? notes,
  int? numberOfGuests,
}) async {
  DocumentReference? ledgerRef;
  
  String targetLedgerCode = ledgerCode;
  if (targetLedgerCode.isEmpty && addedBy.isNotEmpty) {
    try {
      final userLedgerDoc = await FirebaseFirestore.instance.collection('user_ledgers').doc(addedBy).get();
      if (userLedgerDoc.exists) {
        targetLedgerCode = userLedgerDoc.data()?['ledgerCode'] ?? userLedgerDoc.data()?['joinedLedgerCode'] ?? '';
      }
      if (targetLedgerCode.isEmpty) {
        targetLedgerCode = await createLedgerForUser(addedBy, addedByName.isNotEmpty ? addedByName : 'User');
      }
    } catch (_) {}
  }

  if (targetLedgerCode.isEmpty) {
    try {
      final sharedSnap = await FirebaseFirestore.instance.collection('shared_ledgers').limit(1).get();
      if (sharedSnap.docs.isNotEmpty) {
        targetLedgerCode = sharedSnap.docs.first.id;
      }
    } catch (_) {}
  }

  if (targetLedgerCode.isNotEmpty) {
    ledgerRef = await FirebaseFirestore.instance
        .collection('shared_ledgers')
        .doc(targetLedgerCode)
        .collection('items')
        .add({
      'category': category,
      'vendorName': vendorName,
      'amount': amount,
      'status': 'Needs Action',
      'addedBy': addedBy,
      'addedByName': addedByName,
      'addedAt': FieldValue.serverTimestamp(),
      'vendorId': vendorId,
      'eventDate': eventDate,
      'notes': notes,
      'numberOfGuests': numberOfGuests,
    });
    
    // Notify other members
    if (addedBy.isNotEmpty) {
      await notifyLedgerMembers(
        ledgerCode: targetLedgerCode,
        actorUid: addedBy,
        title: 'Ledger Updated',
        message: '$addedByName added $vendorName to the shared ledger.',
      );
    }
  }

  // Also write to legacy ledger collection for fallback backward compatibility
  try {
    final legacyRef = await FirebaseFirestore.instance.collection('ledger').add({
      'category': category,
      'vendorName': vendorName,
      'amount': amount,
      'status': 'Needs Action',
      'addedBy': addedBy,
      'addedByName': addedByName,
      'addedAt': FieldValue.serverTimestamp(),
      'vendorId': vendorId,
      'eventDate': eventDate,
      'notes': notes,
      'numberOfGuests': numberOfGuests,
    });
    ledgerRef ??= legacyRef;
  } catch (_) {}

  // Also create a vendor inquiry if vendorId is present
  if (vendorId != null && vendorId.isNotEmpty && ledgerRef != null) {
    final formattedDate = '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}';
    final eventDateString = eventDate != null && eventDate.isNotEmpty ? ' Event Date: $eventDate' : '';
    final guestString = numberOfGuests != null ? ' - $numberOfGuests Guests' : '';
    
    final inquiryRef = await FirebaseFirestore.instance.collection('vendor_inquiries').add({
      'clientName': addedByName.isNotEmpty ? addedByName : 'A User',
      'date': formattedDate,
      'detail': '$category$eventDateString$guestString',
      'amount': 'Rs. ${amount.toStringAsFixed(0)}',
      'status': 'Pending',
      'vendorId': vendorId,
      'consumerId': addedBy,
      'ledgerItemId': ledgerRef.id,
      'ledgerCode': ledgerCode,
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    // Update the ledger item with the inquiry ID
    await ledgerRef.update({'vendorInquiryId': inquiryRef.id});

    // Send push notification to the vendor
    await NotificationService.sendNotification(
      recipientUid: vendorId,
      title: 'New Booking Request',
      body: '${addedByName.isNotEmpty ? addedByName : "A User"} sent you a booking request for $category.',
      type: 'new_inquiry',
      data: {'inquiryId': inquiryRef.id},
    );
  }
}

// Delete item from a shared ledger
Future<void> deleteLedgerItem(String id, {String ledgerCode = '', String actorUid = '', String actorName = '', String vendorName = 'an item', String? vendorInquiryId}) async {
  if (vendorInquiryId != null && vendorInquiryId.isNotEmpty) {
    try {
      await FirebaseFirestore.instance.collection('vendor_inquiries').doc(vendorInquiryId).delete();
    } catch (_) {}
  }

  if (ledgerCode.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('shared_ledgers')
        .doc(ledgerCode)
        .collection('items')
        .doc(id)
        .delete();

    if (actorUid.isNotEmpty) {
      await notifyLedgerMembers(
        ledgerCode: ledgerCode,
        actorUid: actorUid,
        title: 'Item Removed',
        message: '$actorName removed $vendorName from the shared ledger.',
      );
    }
  } else {
    await FirebaseFirestore.instance.collection('ledger').doc(id).delete();
  }
}

// ======================================================================
// SAVED CARDS & INSTANT UNIFIED CHECKOUT PAYMENT
// ======================================================================

class SavedCard {
  final String id;
  final String cardholderName;
  final String maskedNumber; // e.g. "•••• •••• •••• 4242"
  final String expiryDate; // e.g. "08/28"
  final String brand; // "Visa", "Mastercard", "Amex"
  final DateTime savedAt;

  SavedCard({
    required this.id,
    required this.cardholderName,
    required this.maskedNumber,
    required this.expiryDate,
    required this.brand,
    required this.savedAt,
  });

  factory SavedCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SavedCard(
      id: doc.id,
      cardholderName: data['cardholderName'] ?? 'Cardholder',
      maskedNumber: data['maskedNumber'] ?? '•••• •••• •••• 4242',
      expiryDate: data['expiryDate'] ?? '12/28',
      brand: data['brand'] ?? 'Visa',
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final savedCardsProvider = StreamProvider.family<List<SavedCard>, String>((ref, uid) {
  if (uid.isEmpty) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('user_saved_cards')
      .doc(uid)
      .collection('cards')
      .orderBy('savedAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => SavedCard.fromFirestore(doc)).toList())
      .handleError((_) => <SavedCard>[]);
});

Future<void> deleteSavedCard(String uid, String cardId) async {
  try {
    await FirebaseFirestore.instance
        .collection('user_saved_cards')
        .doc(uid)
        .collection('cards')
        .doc(cardId)
        .delete();
  } catch (_) {}
}

Future<String> processLedgerCheckoutPayment({
  required String ledgerCode,
  required String uid,
  required String userName,
  required String userEmail,
  required List<LedgerItem> items,
  required String cardholderName,
  required String cardNumber,
  required String expiryDate,
  required String cvv,
  required bool saveCard,
}) async {
  final transactionId = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
  final batch = FirebaseFirestore.instance.batch();

  final cleanNum = cardNumber.replaceAll(' ', '');
  final last4 = cleanNum.length >= 4 ? cleanNum.substring(cleanNum.length - 4) : '4242';
  final maskedNumber = '•••• •••• •••• $last4';

  String brand = 'Visa';
  if (cleanNum.startsWith('5') || cleanNum.startsWith('2')) {
    brand = 'Mastercard';
  } else if (cleanNum.startsWith('3')) {
    brand = 'Amex';
  }

  // 1. Save Card if requested
  if (saveCard && uid.isNotEmpty) {
    final cardRef = FirebaseFirestore.instance
        .collection('user_saved_cards')
        .doc(uid)
        .collection('cards')
        .doc();
    batch.set(cardRef, {
      'cardholderName': cardholderName,
      'maskedNumber': maskedNumber,
      'expiryDate': expiryDate,
      'brand': brand,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  // 2. Create Confirmed Bookings in 'bookings' collection
  for (final item in items) {
    final bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
    batch.set(bookingRef, {
      'bookingId': bookingRef.id,
      'transactionId': transactionId,
      'consumerId': uid,
      'consumerName': userName,
      'consumerEmail': userEmail,
      'vendorId': item.vendorId ?? '',
      'vendorName': item.vendorName,
      'category': item.category,
      'amount': item.amount,
      'eventDate': item.eventDate,
      'notes': item.notes,
      'numberOfGuests': item.numberOfGuests,
      'status': 'Confirmed',
      'paymentStatus': 'Paid',
      'paymentMethod': '$brand ($maskedNumber)',
      'bookedAt': FieldValue.serverTimestamp(),
    });

    if (item.vendorInquiryId != null && item.vendorInquiryId!.isNotEmpty) {
      final inqRef = FirebaseFirestore.instance.collection('vendor_inquiries').doc(item.vendorInquiryId);
      batch.update(inqRef, {
        'status': 'Confirmed',
        'paymentStatus': 'Paid',
        'transactionId': transactionId,
      });
    }
  }

  // 3. Clear items from shared_ledgers/{ledgerCode}/items
  if (ledgerCode.isNotEmpty) {
    final itemsSnap = await FirebaseFirestore.instance
        .collection('shared_ledgers')
        .doc(ledgerCode)
        .collection('items')
        .get();
    for (final doc in itemsSnap.docs) {
      batch.delete(doc.reference);
    }
  }

  await batch.commit();

  // 4. Auto-block booked dates in vendor_availability
  for (final item in items) {
    if (item.vendorId != null && item.vendorId!.isNotEmpty && item.eventDate != null && item.eventDate!.isNotEmpty) {
      final normDate = normalizeSingleDate(item.eventDate!);
      if (normDate != null) {
        try {
          final availRef = FirebaseFirestore.instance.collection('vendor_availability').doc(item.vendorId);
          await availRef.set({
            'days': FieldValue.arrayUnion([
              {
                'date': normDate,
                'isBlocked': true,
                'note': 'Booked by $userName ($transactionId)',
              }
            ]),
          }, SetOptions(merge: true));
        } catch (e) {
          print("Error auto-blocking vendor availability: $e");
        }
      }
    }
  }

  return transactionId;
}

String? normalizeSingleDate(String rawDateStr) {
  if (rawDateStr.trim().isEmpty) return null;

  final ymdMatch = RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b').firstMatch(rawDateStr);
  if (ymdMatch != null) {
    final y = int.parse(ymdMatch.group(1)!);
    final m = int.parse(ymdMatch.group(2)!);
    final d = int.parse(ymdMatch.group(3)!);
    return DateFormat('yyyy-MM-dd').format(DateTime(y, m, d));
  }

  final mdyMatch = RegExp(r'\b(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})\b').firstMatch(rawDateStr);
  if (mdyMatch != null) {
    final m = int.parse(mdyMatch.group(1)!);
    final d = int.parse(mdyMatch.group(2)!);
    final y = int.parse(mdyMatch.group(3)!);
    return DateFormat('yyyy-MM-dd').format(DateTime(y, m, d));
  }

  for (final fmt in [
    'yyyy-MM-dd',
    'M/d/yyyy',
    'MMM d, yyyy',
    'EEEE, MMMM d, yyyy',
  ]) {
    try {
      final dt = DateFormat(fmt).parseLoose(rawDateStr.trim());
      return DateFormat('yyyy-MM-dd').format(dt);
    } catch (_) {}
  }
  return null;
}

final venueBookedDatesProvider = StreamProvider.family<Set<String>, String>((ref, vendorId) async* {
  if (vendorId.isEmpty) {
    yield {};
    return;
  }

  final availabilityStream = FirebaseFirestore.instance
      .collection('vendor_availability')
      .doc(vendorId)
      .snapshots();

  final bookingsStream = FirebaseFirestore.instance
      .collection('bookings')
      .where('vendorId', isEqualTo: vendorId)
      .snapshots();

  final inquiriesStream = FirebaseFirestore.instance
      .collection('vendor_inquiries')
      .where('vendorId', isEqualTo: vendorId)
      .snapshots();

  final controller = StreamController<Set<String>>();

  DocumentSnapshot? lastAvail;
  QuerySnapshot? lastBookings;
  QuerySnapshot? lastInquiries;

  void emitLatest() {
    final Set<String> blockedDates = {};
    final Set<String> activeConfirmedDates = {};
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // 1. Active Confirmed Bookings in 'bookings' collection (Future dates only)
    if (lastBookings != null) {
      for (final doc in lastBookings!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? '';
        final isConfirmed = status == 'Confirmed' || status == 'Accepted' || status == 'User Accepted';
        if (isConfirmed) {
          final eventDate = data['eventDate']?.toString();
          if (eventDate != null) {
            final norm = normalizeSingleDate(eventDate);
            if (norm != null && norm.compareTo(todayStr) >= 0) {
              blockedDates.add(norm);
              activeConfirmedDates.add(norm);
            }
          }
        }
      }
    }

    // 2. Active Confirmed Bookings in 'vendor_inquiries' collection (Future dates only)
    if (lastInquiries != null) {
      for (final doc in lastInquiries!.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status']?.toString() ?? '';
        final isConfirmed = status == 'Confirmed' || status == 'Accepted' || status == 'User Accepted';
        if (isConfirmed) {
          final eventDate = data['eventDate']?.toString() ?? data['detail']?.toString();
          if (eventDate != null) {
            final norm = normalizeSingleDate(eventDate);
            if (norm != null && norm.compareTo(todayStr) >= 0) {
              blockedDates.add(norm);
              activeConfirmedDates.add(norm);
            }
          }
        }
      }
    }

    // 3. Manual Vendor Blockouts in 'vendor_availability' (Future dates only)
    if (lastAvail != null && lastAvail!.exists && lastAvail!.data() != null) {
      final days = (lastAvail!.data() as Map<String, dynamic>)['days'] as List<dynamic>? ?? [];
      for (final d in days) {
        if (d is Map && d['isBlocked'] == true && d['date'] != null) {
          final norm = normalizeSingleDate(d['date'].toString());
          final note = d['note']?.toString().toLowerCase() ?? '';
          final isBookingAutoBlock = note.contains('booked');
          if (isBookingAutoBlock) {
            if (norm != null && activeConfirmedDates.contains(norm)) {
              blockedDates.add(norm);
            }
          } else {
            if (norm != null && norm.compareTo(todayStr) >= 0) {
              blockedDates.add(norm);
            }
          }
        }
      }
    }

    if (!controller.isClosed) {
      controller.add(blockedDates);
    }
  }

  final sub1 = availabilityStream.listen((snap) {
    lastAvail = snap;
    emitLatest();
  }, onError: (_) {});

  final sub2 = bookingsStream.listen((snap) {
    lastBookings = snap;
    emitLatest();
  }, onError: (_) {});

  final sub3 = inquiriesStream.listen((snap) {
    lastInquiries = snap;
    emitLatest();
  }, onError: (_) {});

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    controller.close();
  });

  yield* controller.stream;
});

Future<void> clearLedger() async {
  final snapshot = await FirebaseFirestore.instance.collection('ledger').get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}

Future<void> toggleLedgerStatus(String id, String currentStatus, {String ledgerCode = '', String actorUid = '', String actorName = '', String vendorName = 'an item'}) async {
  String nextStatus = 'Needs Action';
  if (currentStatus == 'Needs Action') {
    nextStatus = 'Pending Inquiry';
  } else if (currentStatus == 'Pending Inquiry') {
    nextStatus = 'Booked';
  }
  
  if (ledgerCode.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('shared_ledgers')
        .doc(ledgerCode)
        .collection('items')
        .doc(id)
        .update({'status': nextStatus});
  } else {
    await FirebaseFirestore.instance.collection('ledger').doc(id).update({
      'status': nextStatus,
    });
  }
}

Future<void> acceptVendorOffer(String ledgerItemId, String vendorInquiryId, {String ledgerCode = ''}) async {
  // Update Ledger Item
  if (ledgerCode.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('shared_ledgers')
        .doc(ledgerCode)
        .collection('items')
        .doc(ledgerItemId)
        .update({'status': 'Accepted'});
  } else {
    await FirebaseFirestore.instance.collection('ledger').doc(ledgerItemId).update({
      'status': 'Accepted',
    });
  }

  // Update Vendor Inquiry
  if (vendorInquiryId.isNotEmpty) {
    await FirebaseFirestore.instance.collection('vendor_inquiries').doc(vendorInquiryId).update({
      'status': 'User Accepted',
    });
  }
}

Future<void> setLedgerStatus(String id, String status, {String ledgerCode = '', String actorUid = '', String actorName = '', String vendorName = 'an item'}) async {
  if (ledgerCode.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('shared_ledgers')
        .doc(ledgerCode)
        .collection('items')
        .doc(id)
        .update({'status': status});
        
    if (actorUid.isNotEmpty) {
      await notifyLedgerMembers(
        ledgerCode: ledgerCode,
        actorUid: actorUid,
        title: 'Ledger Status Updated',
        message: '$actorName updated the status of $vendorName to $status.',
      );
    }
  } else {
    await FirebaseFirestore.instance.collection('ledger').doc(id).update({
      'status': status,
    });
  }
}

// State provider for the currently active/viewed ledger code.
// Resets to '' whenever the authenticated user changes.
class ActiveLedgerCodeNotifier extends Notifier<String> {
  @override
  String build() {
    // Subscribe to the full userId — when it changes (login/logout), this
    // notifier rebuilds and state resets to ''.
    final userId = ref.watch(authProvider.select((s) => s.userId));
    // Also eagerly invalidate the user ledger cache for the previous user.
    // (Riverpod will discard the old family key automatically, but
    //  invalidation ensures no stale reads if the same uid is re-used.)
    if (userId != null && userId.isNotEmpty) {
      ref.invalidate(userLedgerCodeProvider(userId));
    }
    return '';
  }
  void update(String val) => state = val;
}
final activeLedgerCodeProvider = NotifierProvider<ActiveLedgerCodeNotifier, String>(ActiveLedgerCodeNotifier.new);

// State provider for the joined (external) ledger code.
// Loads persisted value from Firestore on build, resets on auth change.
class JoinedLedgerCodeNotifier extends Notifier<String> {
  @override
  String build() {
    final userId = ref.watch(authProvider.select((s) => s.userId));
    // Auto-load persisted joined code from Firestore
    if (userId != null && userId.isNotEmpty) {
      _loadPersistedJoinedCode(userId);
    }
    return '';
  }

  Future<void> _loadPersistedJoinedCode(String uid) async {
    try {
      final userDocRef = FirebaseFirestore.instance.collection('user_ledgers').doc(uid);
      final doc = await userDocRef.get();
      if (doc.exists) {
        final joinedCode = doc.data()?['joinedLedgerCode'] as String?;
        if (joinedCode != null && joinedCode.isNotEmpty) {
          state = joinedCode;
          return;
        }
      }

      // Fallback: Recover legacy joined ledgers where the user is in the members list
      // but the joinedLedgerCode wasn't persisted in their user_ledgers document.
      final snap = await FirebaseFirestore.instance.collection('shared_ledgers').get();
      for (var ledgerDoc in snap.docs) {
        final data = ledgerDoc.data();
        final ownerUid = data['ownerUid'] as String?;
        if (ownerUid == uid) continue; // Skip own ledger

        final members = data['members'] as List<dynamic>? ?? [];
        if (members.any((m) => m is Map && m['uid'] == uid)) {
          // Found a ledger this user belongs to! Recover it.
          final code = ledgerDoc.id;
          await userDocRef.set({'joinedLedgerCode': code}, SetOptions(merge: true));
          state = code;
          return;
        }
      }
    } catch (_) {
      // Firestore not available — leave empty
    }
  }

  void update(String val) => state = val;
}
final joinedLedgerCodeProvider = NotifierProvider<JoinedLedgerCodeNotifier, String>(JoinedLedgerCodeNotifier.new);

// Whether user is viewing their own or a joined ledger.
// Resets to false on auth change.
class ViewingJoinedLedgerNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(authProvider.select((s) => s.userId));
    return false;
  }
  void update(bool val) => state = val;
}
final viewingJoinedLedgerProvider = NotifierProvider<ViewingJoinedLedgerNotifier, bool>(ViewingJoinedLedgerNotifier.new);

// Helper: Remove joined ledger code from Firestore for a user
Future<void> leaveJoinedLedger(String uid, String code) async {
  try {
    // Remove from the shared ledger's members list
    final doc = await FirebaseFirestore.instance.collection('shared_ledgers').doc(code).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      final members = (data['members'] as List<dynamic>?) ?? [];
      final updatedMembers = members.where((m) => m['uid'] != uid).toList();
      await FirebaseFirestore.instance.collection('shared_ledgers').doc(code).update({
        'members': updatedMembers,
      });
    }
    // Remove the joined code from user_ledgers
    await FirebaseFirestore.instance.collection('user_ledgers').doc(uid).update({
      'joinedLedgerCode': FieldValue.delete(),
    });
  } catch (_) {
    // Best-effort cleanup
  }
}

/// Submit a review for a vendor. Writes to:
/// 1. `vendor_reviews` collection (for the vendor dashboard)
/// 2. `vendors` document reviews array + recalculated rating (for consumer display)
Future<void> submitVendorReview({
  required String vendorId,
  required String reviewerName,
  required String comment,
  required double rating,
}) async {
  final now = DateTime.now();
  final dateStr = '${now.day}/${now.month}/${now.year}';
  final reviewId = 'rev_${now.millisecondsSinceEpoch}';

  try {
    // 1. Add to vendor_reviews collection (vendor dashboard sees this)
    await FirebaseFirestore.instance.collection('vendor_reviews').doc(reviewId).set({
      'vendorId': vendorId,
      'clientName': reviewerName,
      'comment': comment,
      'rating': rating,
      'date': dateStr,
    });

    // 2. Update the vendors document reviews array + recalculate rating
    final vendorDoc = FirebaseFirestore.instance.collection('vendors').doc(vendorId);
    final snap = await vendorDoc.get();
    if (snap.exists) {
      final data = snap.data() ?? {};
      final existingReviews = (data['reviews'] as List<dynamic>?) ?? [];

      // Build the new review map (matches consumer VendorReview.fromMap)
      final newReview = {
        'reviewerName': reviewerName,
        'comment': comment,
        'rating': rating,
        'date': dateStr,
      };
      final updatedReviews = [...existingReviews, newReview];

      // Recalculate average rating
      double totalRating = 0;
      for (var r in updatedReviews) {
        totalRating += (r['rating'] as num?)?.toDouble() ?? 0.0;
      }
      final avgRating = updatedReviews.isNotEmpty ? (totalRating / updatedReviews.length) : 0.0;

      await vendorDoc.update({
        'reviews': updatedReviews,
        'rating': avgRating.toStringAsFixed(1),
      });
    }
  } catch (e) {
    print('Error submitting vendor review: $e');
    rethrow;
  }
}

Future<void> seedVendorsToFirestore() async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection('vendors').limit(1).get();
    if (snapshot.docs.isNotEmpty) {
      return;
    }
    
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('vendors');

    for (var v in localDummyVendors) {
      final doc = collection.doc(v.id);
      batch.set(doc, v.toFirestore());
    }

    await batch.commit();
    print("Firestore successfully seeded with detailed vendors!");
  } catch (e) {
    print("Error seeding vendors: $e");
  }
}

class FeatureTeaser {
  final String id;
  final String text;
  final String imageUrl;
  final DateTime expiresAt;

  const FeatureTeaser({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.expiresAt,
  });

  factory FeatureTeaser.fromMap(String id, Map<String, dynamic> map) {
    return FeatureTeaser(
      id: id,
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      expiresAt: (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class FeatureTeasersService {
  final _db = FirebaseFirestore.instance.collection('feature_teasers');

  Stream<List<FeatureTeaser>> get activeTeasers {
    return _db
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FeatureTeaser.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<void> addTeaser(String text, String imageUrl, Duration duration) async {
    await _db.add({
      'text': text,
      'imageUrl': imageUrl,
      'expiresAt': Timestamp.fromDate(DateTime.now().add(duration)),
    });
  }

  Future<void> removeTeaser(String id) async {
    await _db.doc(id).delete();
  }
}

final featureTeasersServiceProvider = Provider((ref) => FeatureTeasersService());

final featureTeasersProvider = StreamProvider<List<FeatureTeaser>>((ref) {
  return ref.watch(featureTeasersServiceProvider).activeTeasers;
});

// ============================================================
// Dynamic Consumer Dashboard Content — Admin-Managed via Firestore
// ============================================================

// --- AppCategory Model ---
class AppCategory {
  final String id;
  final String name;
  final String iconName;
  final String tagline;
  final String description;
  final int sortOrder;
  final bool isActive;

  const AppCategory({
    required this.id,
    required this.name,
    required this.iconName,
    this.tagline = '',
    this.description = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AppCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppCategory(
      id: doc.id,
      name: data['name'] ?? '',
      iconName: data['iconName'] ?? 'category',
      tagline: data['tagline'] ?? '',
      description: data['description'] ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'iconName': iconName,
      'tagline': tagline,
      'description': description,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}

const defaultAppCategories = [
  AppCategory(id: 'venues', name: 'Venues', iconName: 'account_balance', tagline: 'Marquees, Banquets & Lawns', description: 'Find and book premier spaces matching your guest count and theme, featuring state-of-the-art layouts.', sortOrder: 0),
  AppCategory(id: 'catering', name: 'Catering', iconName: 'restaurant_menu', tagline: 'Traditional, Continental & Live BBQ', description: 'Indulge your guests in aromatic biryanis, live grilling counters, and premium subcontinental desserts.', sortOrder: 1),
  AppCategory(id: 'decor', name: 'Decor', iconName: 'celebration', tagline: 'Floral Stages & Ambient Lighting', description: 'Mesmerizing stage setups, walkway entrance arches, and fairy lights customized to your color palette.', sortOrder: 2),
  AppCategory(id: 'photography', name: 'Photography', iconName: 'camera_alt', tagline: 'Cinematic Films & Candid Portraits', description: 'Professional filmmakers, drone coverage, and high-definition candid wedding photographers.', sortOrder: 3),
  AppCategory(id: 'pyrotechnics', name: 'Pyrotechnics', iconName: 'local_fire_department', tagline: 'Sparklers, Fireworks & Fog Effects', description: 'Safe indoor cold sparkler fountains, synchronized firework displays, confetti cannons, and fog machines for dramatic entries.', sortOrder: 4),
  AppCategory(id: 'logistics', name: 'Logistics', iconName: 'directions_car', tagline: 'Luxury Fleet & Guest Shuttles', description: 'Premium baraat vehicles, decorated luxury sedans, vintage cars, and guest shuttle coordination for multi-day events.', sortOrder: 5),
  AppCategory(id: 'apparel', name: 'Apparel', iconName: 'checkroom', tagline: 'Bridal Couture & Grooming', description: 'Designer bridal lehengas, sherwanis, family matching outfits, makeup artistry, and complete grooming packages.', sortOrder: 6),
];

Future<void> _seedAppCategories() async {
  try {
    final collection = FirebaseFirestore.instance.collection('app_categories');
    final batch = FirebaseFirestore.instance.batch();
    for (final cat in defaultAppCategories) {
      batch.set(collection.doc(cat.id), cat.toFirestore());
    }
    await batch.commit();
  } catch (e) {
    print("Error seeding app_categories: $e");
  }
}

final appCategoriesProvider = StreamProvider<List<AppCategory>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_categories')
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      _seedAppCategories();
      return defaultAppCategories.toList();
    }
    return snapshot.docs
        .map((doc) => AppCategory.fromFirestore(doc))
        .where((c) => c.isActive)
        .toList();
  }).handleError((err) {
    print("Error loading app_categories: $err");
    return defaultAppCategories.toList();
  });
});

// --- AppBanner Model (Featured Carousel) ---
class AppBanner {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final String imageUrl;
  final String linkCategory;
  final int sortOrder;
  final bool isActive;

  const AppBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.imageUrl,
    required this.linkCategory,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AppBanner.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppBanner(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      tag: data['tag'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      linkCategory: data['linkCategory'] ?? 'All',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subtitle': subtitle,
      'tag': tag,
      'imageUrl': imageUrl,
      'linkCategory': linkCategory,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}

const defaultAppBanners = [
  AppBanner(
    id: 'banner_venues',
    title: 'Book Premium Venues',
    subtitle: 'Get up to 15% off on top Lahore marquees',
    tag: 'LIMITED OFFER',
    imageUrl: 'https://images.unsplash.com/photo-1519225421980-715cb0215aed?q=80&w=800&auto=format&fit=crop',
    linkCategory: 'Venues',
    sortOrder: 0,
  ),
  AppBanner(
    id: 'banner_catering',
    title: 'Exquisite Catering Feasts',
    subtitle: 'Customize multi-tier traditional & continental menus',
    tag: 'TOP CHEFS',
    imageUrl: 'https://images.unsplash.com/photo-1555244162-803834f70033?q=80&auto=format&fit=crop',
    linkCategory: 'Catering',
    sortOrder: 1,
  ),
  AppBanner(
    id: 'banner_decor',
    title: 'Stunning Stage & Floral Decor',
    subtitle: 'Turn your wedding venue into a fairytale garden',
    tag: 'TRENDING DECOR',
    imageUrl: 'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?q=80&w=800&auto=format&fit=crop',
    linkCategory: 'Decor',
    sortOrder: 2,
  ),
  AppBanner(
    id: 'banner_photography',
    title: 'Cinematic Memories',
    subtitle: 'Book premium packages with drone & candid shoots',
    tag: 'EXPERT TEAM',
    imageUrl: 'https://images.unsplash.com/photo-1583939003579-730e3918a45a?q=80&w=800&auto=format&fit=crop',
    linkCategory: 'Photography',
    sortOrder: 3,
  ),
];

Future<void> _seedAppBanners() async {
  try {
    final collection = FirebaseFirestore.instance.collection('app_banners');
    final batch = FirebaseFirestore.instance.batch();
    for (final b in defaultAppBanners) {
      batch.set(collection.doc(b.id), b.toFirestore());
    }
    await batch.commit();
  } catch (e) {
    print("Error seeding app_banners: $e");
  }
}

final appBannersProvider = StreamProvider<List<AppBanner>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_banners')
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      _seedAppBanners();
      return defaultAppBanners.toList();
    }
    return snapshot.docs
        .map((doc) => AppBanner.fromFirestore(doc))
        .where((b) => b.isActive)
        .toList();
  }).handleError((err) {
    print("Error loading app_banners: $err");
    return defaultAppBanners.toList();
  });
});

// --- AppGuide Model (Trending Guides & Ideas) ---
class AppGuide {
  final String id;
  final String title;
  final String tag;
  final String readTime;
  final String imageUrl;
  final String content;
  final int sortOrder;
  final bool isActive;

  const AppGuide({
    required this.id,
    required this.title,
    required this.tag,
    required this.readTime,
    required this.imageUrl,
    required this.content,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AppGuide.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppGuide(
      id: doc.id,
      title: data['title'] ?? '',
      tag: data['tag'] ?? '',
      readTime: data['readTime'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      content: data['content'] ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'tag': tag,
      'readTime': readTime,
      'imageUrl': imageUrl,
      'content': content,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}

const defaultAppGuides = [
  AppGuide(
    id: 'guide_marquee',
    title: 'Top 5 Marquee Trends for 2026',
    tag: 'Decor',
    readTime: '4 min read',
    imageUrl: 'https://images.unsplash.com/photo-1519741497674-611481863552?q=80&w=800&auto=format&fit=crop',
    content: 'When planning a wedding marquee in Pakistan, the trends for 2026 are shifting towards immersive and personalized experiences.\n\n'
        '1. Glass Pavilions: Open-concept glass marquees that seamlessly blend indoor luxury with beautiful outdoor gardens.\n\n'
        '2. Hanging Foliage & Wisteria: Lush greenery installations suspended from the ceilings to create a botanical fairytale look.\n\n'
        '3. Pastel Color Palettes: Moving away from heavy reds and golds to delicate blush pinks, sages, and ivory.\n\n'
        '4. Ambient Projection Mapping: Using dynamic digital displays to transform marquee walls into starry skies or custom animations.\n\n'
        '5. Custom Lounges: Cozy seating clusters with velvet sofas and brass accents for guest comfort and aesthetic appeal.',
    sortOrder: 0,
  ),
  AppGuide(
    id: 'guide_catering',
    title: 'How to Negotiate with Caterers',
    tag: 'Catering',
    readTime: '6 min read',
    imageUrl: 'https://images.unsplash.com/photo-1555244162-803834f70033?q=80&w=800&auto=format&fit=crop',
    content: 'Negotiating with caterers is one of the most effective ways to optimize your wedding budget. Here is a step-by-step negotiation playbook:\n\n'
        '1. Request Per-Head Customization: Instead of accepting rigid standard menus, customize dishes.\n\n'
        '2. Negotiate Live Stations: Live BBQ stations are highly engaging and often more cost-effective.\n\n'
        '3. Ask About Minimum Guests Count: Caterers offer substantial discounts if you guarantee a minimum number of guests.\n\n'
        '4. BYOD (Bring Your Own Desserts/Drinks): Ask if they allow you to supply soft drinks or specific desserts yourself.\n\n'
        '5. Service Staff Ratio: Ensure the ratio of waiters to guests is at least 1:15 for smooth service.',
    sortOrder: 1,
  ),
  AppGuide(
    id: 'guide_music',
    title: 'Ultimate Wedding Music Playlists',
    tag: 'Entertainment',
    readTime: '5 min read',
    imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=800&auto=format&fit=crop',
    content: 'Music sets the soul of any Pakistani wedding, from emotional entrances to high-energy mehndi dances.\n\n'
        '1. The Bride\'s Entry: Slow, acoustic, or classic instrumental tracks that evoke emotion and sentiment.\n\n'
        '2. The Groom\'s Entry: High-tempo dhol beats or energetic modern entry songs.\n\n'
        '3. Mehndi / Sangeet Dances: A mix of classic Bollywood numbers, Punjabi hits, and trending folk tracks.\n\n'
        '4. Background Dinner Music: Soft instrumentals or classic ghazals.\n\n'
        '5. Sound Setup: Ensure the DJ has professional active monitors and cordless mics.',
    sortOrder: 2,
  ),
  AppGuide(
    id: 'guide_photography',
    title: 'A Bride\'s Guide to Photography Packages',
    tag: 'Photography',
    readTime: '5 min read',
    imageUrl: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?q=80&w=800&auto=format&fit=crop',
    content: 'Photography packages can be overwhelming. Here is how to select the right package:\n\n'
        '1. Understand Candid vs Traditional: A good package mixes both styles.\n\n'
        '2. Check for Second Shooters: For events with over 300 guests, ensure at least two main shooters.\n\n'
        '3. Review Album Deliverables: Clarify how many printed albums are included and if raw files are provided.\n\n'
        '4. Engagement / Pre-wedding Shoots: Great to get comfortable in front of the lens before the big day.',
    sortOrder: 3,
  ),
];

Future<void> _seedAppGuides() async {
  try {
    final collection = FirebaseFirestore.instance.collection('app_guides');
    final batch = FirebaseFirestore.instance.batch();
    for (final g in defaultAppGuides) {
      batch.set(collection.doc(g.id), g.toFirestore());
    }
    await batch.commit();
  } catch (e) {
    print("Error seeding app_guides: $e");
  }
}

final appGuidesProvider = StreamProvider<List<AppGuide>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_guides')
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      _seedAppGuides();
      return defaultAppGuides.toList();
    }
    return snapshot.docs
        .map((doc) => AppGuide.fromFirestore(doc))
        .where((g) => g.isActive)
        .toList();
  }).handleError((err) {
    print("Error loading app_guides: $err");
    return defaultAppGuides.toList();
  });
});

// --- AppCity Model ---
class AppCity {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const AppCity({
    required this.id,
    required this.name,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory AppCity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppCity(
      id: doc.id,
      name: data['name'] ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}

const defaultAppCities = [
  AppCity(id: 'lahore', name: 'Lahore, Pakistan', sortOrder: 0),
  AppCity(id: 'karachi', name: 'Karachi, Pakistan', sortOrder: 1),
  AppCity(id: 'islamabad', name: 'Islamabad, Pakistan', sortOrder: 2),
  AppCity(id: 'rawalpindi', name: 'Rawalpindi, Pakistan', sortOrder: 3),
  AppCity(id: 'faisalabad', name: 'Faisalabad, Pakistan', sortOrder: 4),
  AppCity(id: 'multan', name: 'Multan, Pakistan', sortOrder: 5),
];

Future<void> _seedAppCities() async {
  try {
    final collection = FirebaseFirestore.instance.collection('app_cities');
    final batch = FirebaseFirestore.instance.batch();
    for (final c in defaultAppCities) {
      batch.set(collection.doc(c.id), c.toFirestore());
    }
    await batch.commit();
  } catch (e) {
    print("Error seeding app_cities: $e");
  }
}

final appCitiesProvider = StreamProvider<List<AppCity>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_cities')
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      _seedAppCities();
      return defaultAppCities.toList();
    }
    return snapshot.docs
        .map((doc) => AppCity.fromFirestore(doc))
        .where((c) => c.isActive)
        .toList();
  }).handleError((err) {
    print("Error loading app_cities: $err");
    return defaultAppCities.toList();
  });
});

// --- AppChecklistTemplate Model ---
class AppChecklistTemplate {
  final String id;
  final String label;
  final int sortOrder;

  const AppChecklistTemplate({
    required this.id,
    required this.label,
    this.sortOrder = 0,
  });

  factory AppChecklistTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppChecklistTemplate(
      id: doc.id,
      label: data['label'] ?? '',
      sortOrder: (data['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'sortOrder': sortOrder,
    };
  }
}

const defaultChecklistTemplates = [
  AppChecklistTemplate(id: 'cl_venue', label: 'Secure a dream venue', sortOrder: 0),
  AppChecklistTemplate(id: 'cl_catering', label: 'Finalize catering menu', sortOrder: 1),
  AppChecklistTemplate(id: 'cl_decor', label: 'Book decor staging', sortOrder: 2),
  AppChecklistTemplate(id: 'cl_photo', label: 'Hire photographer', sortOrder: 3),
  AppChecklistTemplate(id: 'cl_pyro', label: 'Arrange pyrotechnics & effects', sortOrder: 4),
  AppChecklistTemplate(id: 'cl_logistics', label: 'Book luxury logistics', sortOrder: 5),
  AppChecklistTemplate(id: 'cl_apparel', label: 'Select apparel & grooming', sortOrder: 6),
];

Future<void> _seedChecklistTemplates() async {
  try {
    final collection = FirebaseFirestore.instance.collection('app_checklist');
    final batch = FirebaseFirestore.instance.batch();
    for (final c in defaultChecklistTemplates) {
      batch.set(collection.doc(c.id), c.toFirestore());
    }
    await batch.commit();
  } catch (e) {
    print("Error seeding app_checklist: $e");
  }
}

final appChecklistTemplateProvider = StreamProvider<List<AppChecklistTemplate>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_checklist')
      .orderBy('sortOrder')
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      _seedChecklistTemplates();
      return defaultChecklistTemplates.toList();
    }
    return snapshot.docs
        .map((doc) => AppChecklistTemplate.fromFirestore(doc))
        .toList();
  }).handleError((err) {
    print("Error loading app_checklist: $err");
    return defaultChecklistTemplates.toList();
  });
});

// --- BudgetAllocation Model ---
class BudgetAllocation {
  final String category;
  final double percentage;
  final String emoji;

  const BudgetAllocation({
    required this.category,
    required this.percentage,
    this.emoji = '',
  });

  factory BudgetAllocation.fromMap(Map<String, dynamic> map) {
    return BudgetAllocation(
      category: map['category'] ?? '',
      percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
      emoji: map['emoji'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'percentage': percentage,
      'emoji': emoji,
    };
  }
}

const defaultBudgetAllocations = [
  BudgetAllocation(category: 'Catering', percentage: 40.0, emoji: '\ud83c\udf7d\ufe0f'),
  BudgetAllocation(category: 'Venue Booking', percentage: 20.0, emoji: '\ud83c\udfdb\ufe0f'),
  BudgetAllocation(category: 'Decor & Aesthetics', percentage: 15.0, emoji: '\ud83c\udfa8'),
  BudgetAllocation(category: 'Apparel & Grooming', percentage: 10.0, emoji: '\ud83d\udc57'),
  BudgetAllocation(category: 'Media & Photography', percentage: 7.5, emoji: '\ud83d\udcf8'),
  BudgetAllocation(category: 'Logistics', percentage: 5.0, emoji: '\ud83d\ude97'),
  BudgetAllocation(category: 'Pyrotechnics', percentage: 2.5, emoji: '\ud83c\udf86'),
];

Future<void> _seedBudgetConfig() async {
  try {
    await FirebaseFirestore.instance.collection('app_config').doc('budget_allocations').set({
      'allocations': defaultBudgetAllocations.map((a) => a.toMap()).toList(),
    });
  } catch (e) {
    print("Error seeding budget config: $e");
  }
}

final budgetConfigProvider = StreamProvider<List<BudgetAllocation>>((ref) {
  return FirebaseFirestore.instance
      .collection('app_config')
      .doc('budget_allocations')
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      _seedBudgetConfig();
      return defaultBudgetAllocations.toList();
    }
    final data = doc.data()!;
    final allocations = (data['allocations'] as List<dynamic>?)
        ?.map((a) => BudgetAllocation.fromMap(Map<String, dynamic>.from(a as Map)))
        .toList();
    return (allocations != null && allocations.isNotEmpty) ? allocations : defaultBudgetAllocations.toList();
  }).handleError((err) {
    print("Error loading budget config: $err");
    return defaultBudgetAllocations.toList();
  });
});

// --- NEW: Vendor Replies Provider ---
final vendorRepliesProvider = StreamProvider<List<VendorMessage>>((ref) {
  final userId = ref.watch(authProvider.select((s) => s.userId));
  if (userId == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('vendor_messages')
      .where('clientId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snapshot) {
        final allMsgs = snapshot.docs.map((doc) => VendorMessage.fromFirestore(doc.data(), doc.id)).toList();
        // Only return messages that have a vendor reply
        return allMsgs.where((msg) => msg.vendorReply != null && msg.vendorReply!.isNotEmpty).toList();
      });
});
