import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's email
  String? get currentUserEmail => _auth.currentUser?.email;

  // Get current user's UID
  String? get currentUserId => _auth.currentUser?.uid;

  // Save user profile to Firestore
  Future<void> saveUserProfile({
    required String name,
    required String major,
    required String yearOfStudy,
    required String phoneNumber,
    required List<String> skills,
    String? githubUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    debugPrint('Saving profile for user: ${user.uid}');
    debugPrint('Email: ${user.email}');

    final userProfile = {
      'uid': user.uid,
      'email': user.email,
      'name': name,
      'major': major,
      'yearOfStudy': yearOfStudy,
      'phoneNumber': phoneNumber,
      'skills': skills,
      'githubUrl': githubUrl ?? '',
      'hasCompletedSetup': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      debugPrint('Starting Firestore write...');
      final docRef = _firestore.collection('users').doc(user.uid);
      debugPrint('Document reference created: ${docRef.path}');

      // Save to 'users' collection with UID as document ID
      await docRef
          .set(
            userProfile,
            SetOptions(merge: true),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('Firestore write TIMED OUT after 10 seconds');
              throw Exception(
                  'Firestore write timed out. Check your internet connection and Firebase configuration.');
            },
          );
      debugPrint('Profile saved successfully');
    } catch (e) {
      debugPrint('Firestore error: $e');
      rethrow;
    }
  }

  // Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  // Check if user profile exists
  Future<bool> hasUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.exists;
  }

  // Check if user has completed setup
  Future<bool> hasCompletedSetup() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.exists && doc.data()?['hasCompletedSetup'] == true;
  }

  // Update specific fields in user profile
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    data['updatedAt'] = FieldValue.serverTimestamp();

    await _firestore.collection('users').doc(user.uid).update(data);
  }
}
