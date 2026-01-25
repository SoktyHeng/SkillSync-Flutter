import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's UID
  String? get currentUserId => _auth.currentUser?.uid;

  // Create a new project
  Future<void> createProject({
    required String title,
    required String description,
    required List<String> techStack,
    required List<String> lookingFor,
    String? duration,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final project = {
      'uid': user.uid,
      'title': title,
      'description': description,
      'techStack': techStack,
      'lookingFor': lookingFor,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('projects').add(project);
      debugPrint('Project created successfully');
    } catch (e) {
      debugPrint('Error creating project: $e');
      rethrow;
    }
  }

  // Get all projects (stream for real-time updates)
  Stream<QuerySnapshot> getAllProjects() {
    return _firestore
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get projects by current user
  Stream<QuerySnapshot> getMyProjects() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // Note: Removed orderBy to avoid composite index requirement
    // Sorting is done client-side in project.dart
    return _firestore
        .collection('projects')
        .where('uid', isEqualTo: user.uid)
        .snapshots();
  }

  // Update a project
  Future<void> updateProject({
    required String projectId,
    required String title,
    required String description,
    required List<String> techStack,
    required List<String> lookingFor,
    String? duration,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      await _firestore.collection('projects').doc(projectId).update({
        'title': title,
        'description': description,
        'techStack': techStack,
        'lookingFor': lookingFor,
        'duration': duration,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Project updated successfully');
    } catch (e) {
      debugPrint('Error updating project: $e');
      rethrow;
    }
  }

  // Delete a project
  Future<void> deleteProject(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      await _firestore.collection('projects').doc(projectId).delete();
      debugPrint('Project deleted successfully');
    } catch (e) {
      debugPrint('Error deleting project: $e');
      rethrow;
    }
  }

  // Get user name by UID
  Future<String> getUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['name'] ?? 'Unknown User';
    } catch (e) {
      return 'Unknown User';
    }
  }

  // Get user info (name and profile image) by UID
  Future<Map<String, String?>> getUserInfo(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      return {
        'name': data?['name'] ?? 'Unknown User',
        'profileImageUrl': data?['profileImageUrl'],
      };
    } catch (e) {
      return {'name': 'Unknown User', 'profileImageUrl': null};
    }
  }
}
