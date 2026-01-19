import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/auth/auth_page.dart';
import 'package:skillsync_sp2/pages/home.dart';
import 'package:skillsync_sp2/pages/setup_info.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const SetupInfoPage();
          } else {
            return const AuthPage();
          }
        },
      ),
    );
  }
}
