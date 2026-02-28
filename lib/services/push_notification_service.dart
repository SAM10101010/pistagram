import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/notification_model.dart';
import '../screens/profile_screen.dart';
import '../screens/messages_screen.dart';
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
  static final Dio _dio = Dio();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // TODO: Replace with your FCM server key from Firebase Console:
  // Project Settings > Cloud Messaging > Server key
  static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE';
  static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';

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
      case 'follow_request':
        if (fromUid.isNotEmpty) {
          navigator.push(SlideRightRoute(page: ProfileScreen(userId: fromUid)));
        }
        break;
      case 'message':
        navigator.push(SlideRightRoute(page: const MessagesScreen()));
        break;
      case 'like':
      case 'comment':
        // Navigate to profile of the person who liked/commented
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

  /// Send push notification to a user directly via FCM legacy HTTP API.
  /// Called from addNotification in firestore_service.dart.
  static Future<void> sendPushToUser(NotificationModel notif) async {
    if (_fcmServerKey == 'YOUR_FCM_SERVER_KEY_HERE') return;

    try {
      // Only push for these types
      const pushTypes = ['follow', 'follow_request', 'like', 'comment', 'message'];
      if (!pushTypes.contains(notif.type)) return;

      // Get recipient's FCM tokens
      final recipientDoc = await _db.collection('users').doc(notif.toUid).get();
      if (!recipientDoc.exists) return;
      final recipientData = recipientDoc.data()!;
      final tokens = List<String>.from(recipientData['fcmTokens'] ?? []);
      if (tokens.isEmpty) return;

      // Get sender's display name
      String senderName = 'Someone';
      if (notif.fromUid.isNotEmpty) {
        final senderDoc = await _db.collection('users').doc(notif.fromUid).get();
        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          senderName = senderData['displayName'] ?? senderData['username'] ?? 'Someone';
        }
      }

      // Build title and body
      String title = 'Pistagram';
      String body = notif.message;

      switch (notif.type) {
        case 'follow':
          title = 'New Follower';
          body = '$senderName started following you.';
          break;
        case 'follow_request':
          title = 'Follow Request';
          body = '$senderName wants to follow you.';
          break;
        case 'like':
          title = 'New Like';
          body = '$senderName liked your ${notif.postId.isNotEmpty ? 'post' : 'reel'}.';
          break;
        case 'comment':
          title = 'New Comment';
          body = '$senderName commented: ${notif.message}';
          break;
        case 'message':
          title = 'New Message';
          body = '$senderName sent you a message.';
          break;
      }

      // Send to each token
      for (final token in tokens) {
        try {
          await _dio.post(
            _fcmUrl,
            options: Options(headers: {
              'Content-Type': 'application/json',
              'Authorization': 'key=$_fcmServerKey',
            }),
            data: {
              'to': token,
              'notification': {'title': title, 'body': body},
              'data': {
                'type': notif.type,
                'fromUid': notif.fromUid,
                'postId': notif.postId,
                'reelId': notif.reelId,
              },
              'android': {
                'notification': {
                  'channel_id': 'pistagram_notifications',
                },
              },
            },
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Push notification error: $e');
    }
  }
}
