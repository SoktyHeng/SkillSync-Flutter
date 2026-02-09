import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> checkUserSetupAndNavigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data()?['hasCompletedSetup'] == true) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        Navigator.pushReplacementNamed(context, '/setup');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/setup');
      }
    }
  }

  Future<void> signInWithMicrosoft() async {
    setState(() => _isLoading = true);
    try {
      final microsoftProvider = MicrosoftAuthProvider();
      microsoftProvider.addScope('email');
      microsoftProvider.addScope('profile');

      microsoftProvider.setCustomParameters({
        'tenant': 'c1f3dc23-b7f8-48d3-9b5d-2b12f158f01f',
      });

      await FirebaseAuth.instance.signInWithProvider(microsoftProvider);
      await checkUserSetupAndNavigate();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microsoft sign-in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background header with curve
          ClipPath(
            clipper: _CurvedBottomClipper(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.42,
              decoration: BoxDecoration(
                color: Colors.deepPurple[500],
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.28),

                // Logo
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // App name
                Text(
                  'SKILLSYNC',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple[500],
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CONNECT. COLLABORATE. CREATE.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 48),

                // Sign in with Microsoft button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : signInWithMicrosoft,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Microsoft logo (4 colored squares)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: GridView.count(
                                    crossAxisCount: 2,
                                    mainAxisSpacing: 2,
                                    crossAxisSpacing: 2,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: const [
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Color(0xFFF25022)),
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Color(0xFF7FBA00)),
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Color(0xFF00A4EF)),
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: Color(0xFFFFB900)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Sign in with Microsoft',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const Spacer(),

                // Version info at bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'SkillSync v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom clipper for the curved bottom edge
class _CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
