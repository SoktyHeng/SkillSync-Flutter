import 'package:flutter/material.dart';

class SetupInfoPage extends StatefulWidget {
  const SetupInfoPage({super.key});

  @override
  State<SetupInfoPage> createState() => _SetupInfoPageState();
}

class _SetupInfoPageState extends State<SetupInfoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: Text('Setup Info Page'))),
    );
  }
}
