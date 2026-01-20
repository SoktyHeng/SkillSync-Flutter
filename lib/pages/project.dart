import 'package:flutter/material.dart';

class ProjectPage extends StatelessWidget {
  const ProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project'),
        backgroundColor: Colors.deepPurple[200],
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('This is the Project Page')),
    );
  }
}
