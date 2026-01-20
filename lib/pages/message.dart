import 'package:flutter/material.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.deepPurple[200],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('This is the Messages Page'),
      ),
    );
  }
}
