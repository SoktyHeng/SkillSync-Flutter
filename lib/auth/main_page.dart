import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/auth/auth_page.dart';
import 'package:skillsync_sp2/pages/setup_info.dart';
import 'package:skillsync_sp2/pages/navigation_bar.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  Future<bool> _checkHasCompletedSetup(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.exists && doc.data()?['hasCompletedSetup'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final user = snapshot.data!;
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
            return const AuthPage();
          }
        },
      ),
    );
  }
}
