import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Page'),
        backgroundColor: Colors.deepPurple[200],
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('This is the Profile Page')),
    );
  }
}
