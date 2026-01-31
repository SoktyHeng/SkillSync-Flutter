import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the system notification tray
  debugPrint('Background message received: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Track active conversation to suppress notifications
  String? _activeConversationId;

  // Notification channel for Android
  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
  );

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    // Request permission
    await requestPermission();

    // Setup local notifications for foreground messages
    await _setupLocalNotifications();

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTap);

    // Handle notification that launched the app
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTap(initialMessage);
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen((token) {
      saveTokenToFirestore(token);
    });
  }

  /// Request notification permissions
  Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');
  }

  /// Setup local notifications for foreground display
  Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channel on Android
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_chatChannel);
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Get unique device identifier
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    }

    return 'unknown_device';
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await _getDeviceId();

      await _firestore.collection('fcm_tokens').doc(user.uid).set({
        'tokens': {
          deviceId: {
            'token': token,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'updatedAt': FieldValue.serverTimestamp(),
          }
        }
      }, SetOptions(merge: true));

      debugPrint('FCM token saved for device: $deviceId');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Request permission and save token (call after login)
  Future<void> requestPermissionAndSaveToken() async {
    await requestPermission();
    final token = await getToken();
    if (token != null) {
      await saveTokenToFirestore(token);
    }
  }

  /// Delete FCM token on logout
  Future<void> deleteToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await _getDeviceId();

      await _firestore.collection('fcm_tokens').doc(user.uid).update({
        'tokens.$deviceId': FieldValue.delete(),
      });

      // Also delete the token from FCM
      await _messaging.deleteToken();

      debugPrint('FCM token deleted for device: $deviceId');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Set active conversation (to suppress notifications)
  void setActiveConversation(String conversationId) {
    _activeConversationId = conversationId;
  }

  /// Clear active conversation
  void clearActiveConversation() {
    _activeConversationId = null;
  }

  /// Handle foreground messages
  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message: ${message.notification?.title}');

    // Check if this is a chat message for the currently open conversation
    final conversationId = message.data['conversationId'];
    if (conversationId != null && conversationId == _activeConversationId) {
      // Don't show notification if user is viewing this conversation
      return;
    }

    // Show local notification
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _chatChannel.id,
            _chatChannel.name,
            channelDescription: _chatChannel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: conversationId,
      );
    }
  }

  /// Handle notification tap from background/terminated state
  void _onNotificationTap(RemoteMessage message) {
    final conversationId = message.data['conversationId'];
    if (conversationId != null) {
      // Navigate to chat - this will be handled by the app's navigation
      debugPrint('Notification tapped, conversationId: $conversationId');
      // You can use a GlobalKey<NavigatorState> or a navigation service
      // to navigate to the chat page here
    }
  }

  /// Handle local notification tap
  void _onLocalNotificationTap(NotificationResponse response) {
    final conversationId = response.payload;
    if (conversationId != null) {
      debugPrint('Local notification tapped, conversationId: $conversationId');
      // Navigate to chat page
    }
  }
}
