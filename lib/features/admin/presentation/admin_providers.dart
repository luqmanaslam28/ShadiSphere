import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../auth/presentation/auth_providers.dart';

// --- Models ---

class AdminVendor {
  final String id;
  final String name;
  final String category;
  final String location;
  final String rating;
  final String accountStatus; // 'active', 'warning', 'suspended'

  const AdminVendor({
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.rating,
    this.accountStatus = 'active',
  });

  factory AdminVendor.fromFirestore(Map<String, dynamic> data, String id) {
    return AdminVendor(
      id: id,
      name: data['name'] ?? 'Unknown Vendor',
      category: data['category'] ?? 'Uncategorized',
      location: data['location'] ?? 'Unknown Location',
      rating: data['rating']?.toString() ?? '0.0',
      accountStatus: data['accountStatus'] ?? 'active',
    );
  }
}

class AdminSubscription {
  final String id;
  final String vendorId;
  final String vendorName;
  final String tier;
  final double amount;
  final DateTime date;

  const AdminSubscription({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.tier,
    required this.amount,
    required this.date,
  });

  factory AdminSubscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AdminSubscription(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown',
      tier: data['tier'] ?? 'premium',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      date: (data['date'] is String) 
          ? DateTime.tryParse(data['date']) ?? DateTime.now()
          : (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class DashboardMetrics {
  final String totalConsumers;
  final String activeVendors;
  final String totalBookings;
  final double totalRevenue;
  final Map<String, double> weeklyRegistrations;

  const DashboardMetrics({
    required this.totalConsumers,
    required this.activeVendors,
    required this.totalBookings,
    this.totalRevenue = 0.0,
    required this.weeklyRegistrations,
  });

  static DashboardMetrics fromFirestore(Map<String, dynamic> data) {
    final Map<String, double> regs = {};
    if (data['weeklyRegistrations'] != null) {
      (data['weeklyRegistrations'] as Map<String, dynamic>).forEach((key, val) {
        regs[key] = (val as num).toDouble();
      });
    }
    return DashboardMetrics(
      totalConsumers: data['totalConsumers'] ?? '14,230',
      activeVendors: data['activeVendors'] ?? '842',
      totalBookings: data['totalBookings'] ?? '3,491',
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      weeklyRegistrations: regs.isNotEmpty ? regs : {
        'Mon': 42.0,
        'Tue': 65.0,
        'Wed': 88.0,
        'Thu': 54.0,
        'Fri': 95.0,
        'Sat': 120.0,
        'Sun': 74.0,
      },
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'totalConsumers': totalConsumers,
      'activeVendors': activeVendors,
      'totalBookings': totalBookings,
      'totalRevenue': totalRevenue,
      'weeklyRegistrations': weeklyRegistrations,
    };
  }
}

// SRS §4.1: Governance Audit Log Entry
class GovernanceLogEntry {
  final String id;
  final String vendorName;
  final String action; // 'warning_issued', 'suspended', 'restored', 'deleted'
  final String performedBy;
  final DateTime timestamp;
  final String details;

  const GovernanceLogEntry({
    required this.id,
    required this.vendorName,
    required this.action,
    required this.performedBy,
    required this.timestamp,
    required this.details,
  });

  factory GovernanceLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GovernanceLogEntry(
      id: doc.id,
      vendorName: data['vendorName'] ?? '',
      action: data['action'] ?? '',
      performedBy: data['performedBy'] ?? 'System',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      details: data['details'] ?? '',
    );
  }
}

class CityRecommendation {
  final String id;
  final String name;
  final int count;
  final DateTime lastRequested;

  const CityRecommendation({
    required this.id,
    required this.name,
    required this.count,
    required this.lastRequested,
  });

  factory CityRecommendation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CityRecommendation(
      id: doc.id,
      name: data['name'] ?? '',
      count: (data['count'] as num?)?.toInt() ?? 1,
      lastRequested: (data['lastRequested'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// --- Notifiers ---

class VendorManagementState {
  final List<AdminVendor> vendors;
  final String selectedCity;
  final String selectedRating;

  VendorManagementState({
    this.vendors = const [],
    this.selectedCity = 'karachi',
    this.selectedRating = 'All',
  });

  VendorManagementState copyWith({
    List<AdminVendor>? vendors,
    String? selectedCity,
    String? selectedRating,
  }) {
    return VendorManagementState(
      vendors: vendors ?? this.vendors,
      selectedCity: selectedCity ?? this.selectedCity,
      selectedRating: selectedRating ?? this.selectedRating,
    );
  }
}

class VendorManagementNotifier extends Notifier<VendorManagementState> {
  StreamSubscription? _sub;

  @override
  VendorManagementState build() {
    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('vendors').snapshots().listen((snapshot) {
        final vendors = snapshot.docs.map((doc) => AdminVendor.fromFirestore(doc.data(), doc.id)).toList();
        state = state.copyWith(vendors: vendors);
      }, onError: (err) {
        print("Error listening to vendors: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return VendorManagementState();
  }

  void setCityFilter(String city) {
    state = state.copyWith(selectedCity: city);
  }

  void setRatingFilter(String rating) {
    state = state.copyWith(selectedRating: rating);
  }

  Future<void> warnVendor(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendors').doc(id).update({
        'accountStatus': 'warning',
      });
      await FirebaseFirestore.instance.collection('vendor_profile').doc(id).update({
        'accountStatus': 'warning',
      });
      
      // Notify vendor
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': id,
        'title': 'Account Warning',
        'message': 'You have received a formal warning due to compliance issues. Please contact support.',
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'system',
      });
    } catch (e) {
      print("Error warning vendor: $e");
    }
  }

  Future<void> reactivateVendor(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendors').doc(id).update({
        'accountStatus': 'active',
      });
      await FirebaseFirestore.instance.collection('vendor_profile').doc(id).update({
        'accountStatus': 'active',
      });
      
      // Notify vendor
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': id,
        'title': 'Account Reactivated',
        'message': 'Your account warnings and suspensions have been cleared. You are now fully active.',
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'system',
      });
    } catch (e) {
      print("Error reactivating vendor: $e");
    }
  }

  Future<void> suspendVendor(String id) async {
    try {
      await FirebaseFirestore.instance.collection('vendors').doc(id).update({
        'accountStatus': 'suspended',
      });
      await FirebaseFirestore.instance.collection('vendor_profile').doc(id).update({
        'accountStatus': 'suspended',
      });
      
      // Notify vendor
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': id,
        'title': 'Account Suspended',
        'message': 'Your account has been suspended due to compliance violations.',
        'time': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'system',
      });

      // Remove vendor from consumer ledgers
      final ledgersSnap = await FirebaseFirestore.instance.collection('shared_ledgers').get();
      for (var ledger in ledgersSnap.docs) {
        final itemsSnap = await ledger.reference.collection('items').where('vendorId', isEqualTo: id).get();
        for (var item in itemsSnap.docs) {
          await item.reference.delete();
          
          // Notify ledger owner
          final ledgerData = ledger.data();
          if (ledgerData['ownerId'] != null) {
            await FirebaseFirestore.instance.collection('notifications').add({
              'recipientId': ledgerData['ownerId'],
              'title': 'Vendor Suspended',
              'message': 'A vendor in your ledger has been suspended and removed from your ledger.',
              'time': FieldValue.serverTimestamp(),
              'isRead': false,
              'type': 'system',
            });
          }
        }
      }

      // Also check private ledgers
      final privateLedgersSnap = await FirebaseFirestore.instance.collection('ledger').where('vendorId', isEqualTo: id).get();
      for (var item in privateLedgersSnap.docs) {
        final userId = item.data()['userId'];
        await item.reference.delete();
        if (userId != null) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'recipientId': userId,
            'title': 'Vendor Suspended',
            'message': 'A vendor in your ledger has been suspended and removed from your ledger.',
            'time': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'system',
          });
        }
      }

    } catch (e) {
      print("Error suspending vendor: $e");
    }
  }
}

class AdminSubscriptionsNotifier extends Notifier<List<AdminSubscription>> {
  StreamSubscription? _sub;

  @override
  List<AdminSubscription> build() {
    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('admin_subscriptions').snapshots().listen((snapshot) {
        final list = snapshot.docs.map((doc) => AdminSubscription.fromFirestore(doc)).toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        state = list;
        
        // Compute total revenue for THIS MONTH and update DashboardMetrics seamlessly
        double revenue = 0.0;
        final now = DateTime.now();
        for (var doc in snapshot.docs) {
          final dateStr = doc.data()['date'];
          final date = (dateStr is String) 
              ? DateTime.tryParse(dateStr) ?? now 
              : (dateStr as Timestamp?)?.toDate() ?? now;
          if (date.year == now.year && date.month == now.month) {
            final amt = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
            revenue += amt;
          }
        }
        ref.read(adminMetricsProvider.notifier).updateTotalRevenue(revenue);
      }, onError: (err) {
        debugPrint("Error listening to admin_subscriptions: $err");
      });
    } catch (e) {
      debugPrint("Firestore not available for subscriptions: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }
}

class AdminMetricsNotifier extends Notifier<DashboardMetrics> {
  StreamSubscription? _sub;

  DashboardMetrics _defaultMetrics() {
    return const DashboardMetrics(
      totalConsumers: '14,230',
      activeVendors: '842',
      totalBookings: '3,491',
      weeklyRegistrations: {
        'Mon': 42.0,
        'Tue': 65.0,
        'Wed': 88.0,
        'Thu': 54.0,
        'Fri': 95.0,
        'Sat': 120.0,
        'Sun': 74.0,
      },
    );
  }

  void _seedMetrics() async {
    try {
      await FirebaseFirestore.instance.collection('admin_metrics').doc('dashboard').set(_defaultMetrics().toFirestore());
    } catch (e) {
      print("Error seeding metrics: $e");
    }
  }

  @override
  DashboardMetrics build() {
    try {
      _sub?.cancel();
      _sub = FirebaseFirestore.instance.collection('admin_metrics').doc('dashboard').snapshots().listen((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          _seedMetrics();
          state = _defaultMetrics();
        } else {
          state = DashboardMetrics.fromFirestore(snapshot.data()!);
        }
      }, onError: (err) {
        print("Error listening to admin_metrics: $err");
      });
    } catch (e) {
      print("Firestore not available: $e");
    }

    ref.onDispose(() {
      _sub?.cancel();
    });

    return _defaultMetrics();
  }

  void updateTotalRevenue(double newTotal) async {
    final current = state;
    if (current.totalRevenue == newTotal) return;
    
    state = DashboardMetrics(
      totalConsumers: current.totalConsumers,
      activeVendors: current.activeVendors,
      totalBookings: current.totalBookings,
      totalRevenue: newTotal,
      weeklyRegistrations: current.weeklyRegistrations,
    );
    
    try {
      await FirebaseFirestore.instance.collection('admin_metrics').doc('dashboard').update({
        'totalRevenue': newTotal,
      });
    } catch (e) {
      debugPrint("Error updating total revenue in firestore: $e");
    }
  }
}

// Governance Audit Log Stream
final governanceLogProvider = StreamProvider<List<GovernanceLogEntry>>((ref) {
  return FirebaseFirestore.instance
      .collection('admin_governance_log')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => GovernanceLogEntry.fromFirestore(doc)).toList());
});

// --- Providers ---

final adminVendorManagementProvider = NotifierProvider<VendorManagementNotifier, VendorManagementState>(() {
  return VendorManagementNotifier();
});

final adminMetricsProvider = NotifierProvider<AdminMetricsNotifier, DashboardMetrics>(() {
  return AdminMetricsNotifier();
});

final adminCityRecommendationsProvider = StreamProvider<List<CityRecommendation>>((ref) {
  return FirebaseFirestore.instance
      .collection('city_recommendations')
      .orderBy('count', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => CityRecommendation.fromFirestore(doc)).toList());
});

final adminFeedbackProvider = StreamProvider<List<PlatformFeedback>>((ref) {
  return FirebaseFirestore.instance
      .collection('platform_feedback')
      .orderBy('submittedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => PlatformFeedback.fromFirestore(doc)).toList());
});

final adminSubscriptionsProvider = NotifierProvider<AdminSubscriptionsNotifier, List<AdminSubscription>>(() {
  return AdminSubscriptionsNotifier();
});

class SubscriptionPlan {
  final String id;
  final String name;
  final double price;
  final String colorHex;
  final String iconName;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.colorHex,
    required this.iconName,
  });

  SubscriptionPlan copyWith({String? name, double? price, String? colorHex, String? iconName}) {
    return SubscriptionPlan(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
    );
  }

  factory SubscriptionPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SubscriptionPlan(
      id: doc.id,
      name: data['name']?.toString() ?? 'Unknown',
      price: double.tryParse(data['price']?.toString() ?? '0') ?? 0,
      colorHex: data['colorHex']?.toString() ?? 'D4AF37',
      iconName: data['iconName']?.toString() ?? 'star',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'colorHex': colorHex,
      'iconName': iconName,
    };
  }
}

class SubscriptionPlansNotifier extends Notifier<List<SubscriptionPlan>> {
  StreamSubscription? _sub;

  @override
  List<SubscriptionPlan> build() {
    _sub = FirebaseFirestore.instance.collection('subscription_plans').snapshots().listen((snapshot) async {
      if (snapshot.docs.isEmpty) {
        // Seed default plans
        final batch = FirebaseFirestore.instance.batch();
        
        final premiumRef = FirebaseFirestore.instance.collection('subscription_plans').doc('premium');
        batch.set(premiumRef, {
          'name': 'Premium',
          'price': 5000,
          'colorHex': 'D4AF37',
          'iconName': 'star',
        });
        
        final platinumRef = FirebaseFirestore.instance.collection('subscription_plans').doc('platinum');
        batch.set(platinumRef, {
          'name': 'Platinum',
          'price': 10000,
          'colorHex': '78909C',
          'iconName': 'diamond',
        });
        
        await batch.commit();
        return; 
      }
      
      state = snapshot.docs.map((doc) => SubscriptionPlan.fromFirestore(doc)).toList();
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    return [];
  }

  void addPlan(String name, double price, String colorHex, String iconName) {
    final id = name.toLowerCase().replaceAll(' ', '_');
    FirebaseFirestore.instance.collection('subscription_plans').doc(id).set({
      'name': name,
      'price': price,
      'colorHex': colorHex,
      'iconName': iconName,
    });
  }

  void updatePlan(String id, String name, double price, String colorHex, String iconName) {
    FirebaseFirestore.instance.collection('subscription_plans').doc(id).update({
      'name': name,
      'price': price,
      'colorHex': colorHex,
      'iconName': iconName,
    });
  }

  void removePlan(String id) {
    FirebaseFirestore.instance.collection('subscription_plans').doc(id).delete();
  }
}

final subscriptionPlansProvider = NotifierProvider<SubscriptionPlansNotifier, List<SubscriptionPlan>>(() {
  return SubscriptionPlansNotifier();
});
