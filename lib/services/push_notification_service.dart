import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/follow_requests_screen.dart';
import '../utils/animations.dart';

/// Top-level background handler — must be outside the class
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Request permission (handles Android 13 runtime + iOS dialog)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications for foreground display
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      'pistagram_notifications',
      'Pistagram Notifications',
      description: 'Notifications for follows, likes, comments, and messages',
      importance: Importance.high,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Tap handler when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from terminated state via notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    // Auto re-save token if user is already logged in (app restart)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      saveToken(currentUser.uid);
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotif.show(
      message.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pistagram_notifications',
          'Pistagram Notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    _navigateFromPayload(message.data);
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null || response.payload!.isEmpty) return;
    try {
      final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
      _navigateFromPayload(data);
    } catch (_) {}
  }

  static void _navigateFromPayload(Map<String, dynamic> data) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    final type = data['type'] ?? '';
    final fromUid = data['fromUid'] ?? '';

    switch (type) {
      case 'follow':
        if (fromUid.isNotEmpty) {
          navigator.push(SlideRightRoute(page: ProfileScreen(userId: fromUid)));
        }
        break;
      case 'follow_request':
        navigator.push(SlideRightRoute(page: const FollowRequestsScreen()));
        break;
      case 'message':
        navigator.push(SlideRightRoute(page: const MessagesScreen()));
        break;
      case 'like':
      case 'comment':
      case 'comment_reply':
      case 'comment_like':
        // Navigate to profile of the person who interacted
        if (fromUid.isNotEmpty) {
          navigator.push(SlideRightRoute(page: ProfileScreen(userId: fromUid)));
        }
        break;
      default:
        break;
    }
  }

  static Future<void> saveToken(String uid) async {
    final token = await _fcm.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    }
    // Listen for future token refreshes
    _fcm.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      });
    });
  }

  static Future<void> removeToken(String uid) async {
    final token = await _fcm.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
    }
  }

  // Push notifications are sent server-side via Cloud Function trigger.
  // See functions/src/sendPushNotification.ts — it fires on every new
  // document in the 'notifications' collection and sends FCM messages
  // to the recipient's registered device tokens.
  //
  // To deploy: firebase deploy --only functions:sendPushNotification
}
