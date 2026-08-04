import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized notification service for ShadiSphere using OneSignal.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _appId = "4dcfa038-680e-4522-9c3c-c537ff68e4a9";
  static const String _restApiKey = "YOUR_REST_API_KEY_HERE";

  Future<void> initialize() async {
    try {
      if (!kIsWeb) {
        // OneSignal Web is supported differently, so we initialize primarily for mobile
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize(_appId);
        OneSignal.Notifications.requestPermission(true);
        
        // Listen for login state to associate the user
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user != null) {
            OneSignal.login(user.uid);
            debugPrint('[OneSignal] Logged in with user: ${user.uid}');
          } else {
            OneSignal.logout();
            debugPrint('[OneSignal] Logged out');
          }
        });
      }
    } catch (e) {
      debugPrint('[OneSignal] Initialization error: $e');
    }
  }

  // ─── Static helpers to write notification documents ───

  /// Send a push notification by directly hitting the OneSignal REST API.
  static Future<void> sendNotification({
    required String recipientUid,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': [recipientUid]
          },
          'target_channel': 'push',
          'headings': {'en': title},
          'contents': {'en': body},
          'data': {
            'type': type,
            ...?data,
          },
        }),
      );

      // 2. Save to Firestore so it shows up in the app's Notifications UI
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': recipientUid,
        'title': title,
        'message': body,
        'type': type,
        'data': data ?? {},
        'isRead': false,
        'time': FieldValue.serverTimestamp(),
      });

      debugPrint('[OneSignal] Sent to $recipientUid: $title. Response: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('[OneSignal] Error sending: $e');
    }
  }
}
