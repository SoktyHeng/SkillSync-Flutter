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

  // Notification channel for Android - Chat
  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
  );

  // Notification channel for Android - Project
  static const AndroidNotificationChannel _projectChannel =
      AndroidNotificationChannel(
    'project_notifications',
    'Project Notifications',
    description: 'Notifications for project requests',
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

    // Create notification channels on Android
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_chatChannel);
    await androidPlugin?.createNotificationChannel(_projectChannel);
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

    final messageType = message.data['type'] as String?;

    // Check if this is a chat message for the currently open conversation
    if (messageType == 'chat_message') {
      final conversationId = message.data['conversationId'];
      if (conversationId != null && conversationId == _activeConversationId) {
        // Don't show notification if user is viewing this conversation
        return;
      }
    }

    // Determine which channel to use based on message type
    final isProjectNotification = messageType == 'request_received' ||
        messageType == 'request_accepted' ||
        messageType == 'request_rejected';
    final channel = isProjectNotification ? _projectChannel : _chatChannel;

    // Show local notification
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null) {
      // Build payload based on type
      final payload = isProjectNotification
          ? message.data['projectId']
          : message.data['conversationId'];

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
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
        payload: payload,
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

  /// Get notifications stream for current user
  Stream<List<QueryDocumentSnapshot>> getNotifications() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs;
      // Sort client-side to avoid composite index requirement
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // descending
      });
      return docs;
    });
  }

  /// Get unread notifications count stream
  Stream<int> getUnreadCount() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      // Filter client-side to avoid composite index requirement
      return snapshot.docs
          .where((doc) => doc.data()['isRead'] != true)
          .length;
    });
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final batch = _firestore.batch();
      final allDocs = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Filter client-side to avoid composite index requirement
      final unreadDocs =
          allDocs.docs.where((doc) => doc.data()['isRead'] != true);

      for (var doc in unreadDocs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      debugPrint('Marked ${unreadDocs.length} notifications as read');
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}
