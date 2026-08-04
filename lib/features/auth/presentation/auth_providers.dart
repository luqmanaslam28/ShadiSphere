import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// --- Models ---

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? email;
  final String? role; // 'consumer' | 'vendor' | 'admin'
  final String? displayName;
  final String? phone;
  final String? businessName;
  final String? city;
  final String? category;
  final bool isLoadingProfile;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.email,
    this.role,
    this.displayName,
    this.phone,
    this.businessName,
    this.city,
    this.category,
    this.isLoadingProfile = false,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? email,
    String? role,
    String? displayName,
    String? phone,
    String? businessName,
    String? city,
    String? category,
    bool? isLoadingProfile,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      city: city ?? this.city,
      category: category ?? this.category,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
    );
  }
}

class PlatformFeedback {
  final String id;
  final String userId;
  final String userEmail;
  final int rating;
  final String comment;
  final DateTime submittedAt;

  const PlatformFeedback({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.submittedAt,
  });

  factory PlatformFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PlatformFeedback(
      id: doc.id,
      userId: data['userId']?.toString() ?? '',
      userEmail: data['userEmail']?.toString() ?? 'Anonymous',
      rating: (data['rating'] as num?)?.toInt() ?? 0,
      comment: data['comment']?.toString() ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// --- Notifiers ---

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Attempt to read current firebase user
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Run async load to get additional fields, but return initial basic authenticated state
        _loadUserProfile(user.uid, user.email ?? '');
        return AuthState(
          isAuthenticated: true,
          userId: user.uid,
          email: user.email,
          displayName: user.displayName,
          isLoadingProfile: true,
        );
      }
    } catch (e) {
      debugPrint("FirebaseAuth not available during startup initialization: $e");
    }
    return const AuthState();
  }

  Future<void> _loadUserProfile(String uid, String email) async {
    try {
      // First look in users collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final dbRole = data['role']?.toString();
        
        if (dbRole == 'admin') {
          state = state.copyWith(
            role: 'admin',
            displayName: data['name'] ?? 'Admin',
            phone: data['phone'] ?? '',
            city: data['city']?.toString(),
            isLoadingProfile: false,
          );
          return;
        } else if (dbRole == 'vendor') {
          String businessName = '';
          String category = '';
          try {
            final vendorDoc = await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).get();
            if (vendorDoc.exists) {
              businessName = vendorDoc.data()?['businessName'] ?? '';
              category = vendorDoc.data()?['category'] ?? '';
            }
          } catch (e) {
            debugPrint("Error fetching vendor business name: $e");
          }
          state = state.copyWith(
            role: 'vendor',
            businessName: businessName.isNotEmpty ? businessName : (data['name'] ?? 'Vendor'),
            phone: data['phone'] ?? '',
            city: data['city']?.toString(),
            category: category,
            isLoadingProfile: false,
          );
          return;
        } else {
          // Default to consumer
          state = state.copyWith(
            role: 'consumer',
            displayName: data['name'] ?? '',
            phone: data['phone'] ?? '',
            city: data['city']?.toString(),
            isLoadingProfile: false,
          );
          return;
        }
      }

      // If not in users, check if they exist in vendor_profile
      final vendorDoc = await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).get();
      if (vendorDoc.exists) {
        final data = vendorDoc.data() ?? {};
        state = state.copyWith(
          role: 'vendor',
          businessName: data['businessName'] ?? '',
          category: data['category']?.toString(),
          isLoadingProfile: false,
        );
        return;
      }

      // Default fallback based on email
      if (email.contains('admin')) {
        state = state.copyWith(role: 'admin', isLoadingProfile: false);
      } else if (email.contains('vendor')) {
        state = state.copyWith(role: 'vendor', isLoadingProfile: false);
      } else {
        state = state.copyWith(role: 'consumer', isLoadingProfile: false);
      }
    } catch (e) {
      debugPrint("Error loading user profile: $e");
    } finally {
      // Ensure we clear the loading flag even if an error occurs (like permission denied)
      if (state.isLoadingProfile) {
        state = state.copyWith(isLoadingProfile: false);
      }
    }
  }

  bool _isFirebaseAvailable() {
    try {
      if (Firebase.apps.isEmpty) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    if (!_isFirebaseAvailable()) {
      // Test-safe offline mock fallback
      final String mockRole = email.contains('admin')
          ? 'admin'
          : (email.contains('vendor') ? 'vendor' : 'consumer');
      
      final mockUid = 'mock_uid_${email.hashCode}';

      // Seed mock database for tests/offline
      try {
        if (mockRole == 'admin') {
          await FirebaseFirestore.instance.collection('users').doc(mockUid).set({
            'name': 'System Admin (Mock)',
            'email': email,
            'role': 'admin',
          });
        }
      } catch (dbError) {
        debugPrint("Offline mock database write skipped: $dbError");
      }
      
      state = AuthState(
        isAuthenticated: true,
        userId: mockUid,
        email: email,
        role: mockRole,
        displayName: email.split('@').first,
        businessName: mockRole == 'vendor' ? 'Mock Event Group' : null,
        city: 'Lahore, Pakistan',
        category: mockRole == 'vendor' ? 'Venues' : null,
      );
      return;
    }

    // Real Firebase Auth flow: propagate any credentials/auth exceptions directly to UI
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user != null) {
      final uid = credential.user!.uid;

      // Seed admin user in database if it's admin email and document doesn't exist
      if (email == 'admin@shadisphere.com' || email.contains('admin')) {
        try {
          final adminDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (!adminDoc.exists) {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'name': 'System Admin',
              'email': email,
              'role': 'admin',
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        } catch (e) {
          debugPrint("Error seeding admin user document in Firestore: $e");
        }
      }

      state = AuthState(
        isAuthenticated: true,
        userId: uid,
        email: credential.user!.email,
        displayName: credential.user!.displayName,
      );
      await _loadUserProfile(uid, email);
    }
  }

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String role,
    String? name,
    String? phone,
    String? businessName,
    String? category,
    String? location,
  }) async {
    if (!_isFirebaseAvailable()) {
      // Test-safe offline mock fallback
      final mockUid = 'mock_uid_${email.hashCode}';
      state = AuthState(
        isAuthenticated: true,
        userId: mockUid,
        email: email,
        role: role,
        displayName: role == 'vendor' ? businessName : name,
        phone: phone,
        businessName: role == 'vendor' ? businessName : null,
        city: location ?? 'Lahore, Pakistan',
        category: role == 'vendor' ? (category ?? 'Venues') : null,
      );

      // Try offline database mock write to print trace, ignoring exceptions
      try {
        if (role == 'vendor') {
          await FirebaseFirestore.instance.collection('vendor_profile').doc(mockUid).set({
            'businessName': businessName ?? 'New Premium Vendor',
            'location': location ?? 'Karachi, Pakistan',
            'category': category ?? 'Venues',
            'bio': 'Registered via ShadiSphere Platform (Offline Mock).',
            'subscriptionTier': 'free',
          });
          await FirebaseFirestore.instance.collection('users').doc(mockUid).set({
            'name': businessName ?? 'New Premium Vendor',
            'email': email,
            'role': 'vendor',
          });
        } else {
          await FirebaseFirestore.instance.collection('users').doc(mockUid).set({
            'name': name ?? (role == 'admin' ? 'System Admin' : 'New User'),
            'email': email,
            'phone': phone ?? '',
            'role': role,
          });
        }
      } catch (dbError) {
        debugPrint("Offline mock database write skipped: $dbError");
      }
      return;
    }

    // Real Firebase Auth Flow
    final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid != null) {
      if (role == 'vendor') {
        // Write vendor metadata to vendor_profile
        await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).set({
          'businessName': businessName ?? 'New Premium Vendor',
          'location': location ?? 'Karachi, Pakistan',
          'category': category ?? 'Venues',
          'bio': 'Registered via ShadiSphere Platform.',
          'createdAt': FieldValue.serverTimestamp(),
          'subscriptionTier': 'free',
          'hasAcceptedTerms': false,
        });
        
        // SYNC to vendors collection for consumers to discover
        await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
          'name': businessName ?? 'New Premium Vendor',
          'location': location ?? 'Karachi, Pakistan',
          'category': category ?? 'Venues',
          'description': 'Registered via ShadiSphere Platform.',
          'subscriptionTier': 'free',
          'hasAcceptedTerms': false,
        }, SetOptions(merge: true));

        // Also record in users collection with role: 'vendor'
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': businessName ?? 'New Premium Vendor',
          'email': email,
          'role': 'vendor',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Write consumer/admin metadata to users
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name ?? (role == 'admin' ? 'System Admin' : 'New User'),
          'email': email,
          'phone': phone ?? '',
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      state = AuthState(
        isAuthenticated: true,
        userId: uid,
        email: email,
        role: role,
        displayName: role == 'vendor' ? businessName : name,
        phone: phone,
        businessName: role == 'vendor' ? businessName : null,
        category: role == 'vendor' ? category : null,
      );
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint("Firebase Auth sign out error: $e");
    }
    state = const AuthState();
  }

  Future<void> updateUserCity(String city) async {
    final uid = state.userId;
    if (uid != null && uid.isNotEmpty) {
      try {
        if (_isFirebaseAvailable()) {
          if (state.city != null) {
            // If we are setting a city for the first time, check if it's already in the users collection
            await FirebaseFirestore.instance.collection('users').doc(state.userId).set({
              'city': city,
            }, SetOptions(merge: true));
          } else {
            await FirebaseFirestore.instance.collection('users').doc(state.userId).update({
              'city': city,
            });
          }
        }
      } catch (e) {
        debugPrint("Failed to update user city: $e");
      } finally {
        state = state.copyWith(city: city);
      }
    }
  }

  Future<void> updateUserName(String name) async {
    final uid = state.userId;
    if (uid != null && uid.isNotEmpty) {
      try {
        if (_isFirebaseAvailable()) {
          await FirebaseFirestore.instance.collection('users').doc(state.userId).update({
            'name': name,
          });
        }
      } catch (e) {
        debugPrint("Failed to update user name: $e");
      } finally {
        state = state.copyWith(displayName: name);
      }
    }
  }

  Future<void> submitPlatformFeedback(int rating, String comment) async {
    final uid = state.userId;
    final email = state.email;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('platform_feedback').add({
        'userId': uid,
        'userEmail': email ?? 'Anonymous',
        'rating': rating,
        'comment': comment.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to submit feedback: $e");
    }
  }

  Future<void> submitCityRecommendation(String city) async {
    if (!_isFirebaseAvailable()) {
      debugPrint("Offline mode: Simulated city recommendation for $city");
      return;
    }
    try {
      final String safeCityId = city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final docRef = FirebaseFirestore.instance.collection('city_recommendations').doc(safeCityId);
      
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.update({
          'count': FieldValue.increment(1),
          'lastRequested': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.set({
          'name': city.trim(),
          'count': 1,
          'lastRequested': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error submitting city recommendation: $e");
    }
  }

  Future<void> simulateSubscriptionPayment(String tier, double amount) async {
    final uid = state.userId;
    if (uid == null) return;
    
    if (!_isFirebaseAvailable()) {
      debugPrint("Offline mock subscription payment: $tier");
      return;
    }
    
    try {
      final expiryDate = DateTime.now().add(const Duration(days: 30));

      // 1. Update vendor profile
      await FirebaseFirestore.instance.collection('vendor_profile').doc(uid).update({
        'subscriptionTier': tier,
        'subscriptionExpiry': expiryDate.toIso8601String(),
      });

      // SYNC to vendors collection
      await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
        'subscriptionTier': tier,
        'subscriptionExpiry': expiryDate.toIso8601String(),
      }, SetOptions(merge: true));
      
      // 2. Log in admin subscriptions
      await FirebaseFirestore.instance.collection('admin_subscriptions').add({
        'vendorId': uid,
        'vendorName': state.businessName ?? state.displayName ?? 'Unknown Vendor',
        'tier': tier,
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error simulating subscription payment: $e");
    }
  }
}

// --- Provider ---

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
