import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/auth/auth_page.dart';
import 'package:skillsync_sp2/pages/setup_info.dart';
import 'package:skillsync_sp2/pages/navigation_bar.dart';
import 'package:skillsync_sp2/services/notification_service.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _notificationInitialized = false;

  Future<bool> _checkHasCompletedSetup(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.exists && doc.data()?['hasCompletedSetup'] == true;
  }

  void _initializeNotifications() {
    if (!_notificationInitialized) {
      _notificationInitialized = true;
      NotificationService().requestPermissionAndSaveToken();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final user = snapshot.data!;
            // Initialize notifications when user is authenticated
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeNotifications();
            });
            return FutureBuilder<bool>(
              future: _checkHasCompletedSetup(user.uid),
              builder: (context, setupSnapshot) {
                if (setupSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (setupSnapshot.data == true) {
                  return NavigationPage();
                }
                return const SetupInfoPage();
              },
            );
          } else {
            _notificationInitialized = false;
            return const AuthPage();
          }
        },
      ),
    );
  }
}
