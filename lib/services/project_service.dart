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

  // Send a contribution request
  Future<void> requestToContribute(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      // Check if already requested
      final existingRequest = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('You have already requested to contribute');
      }

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .add({
        'userId': user.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Contribution request sent successfully');
    } catch (e) {
      debugPrint('Error sending contribution request: $e');
      rethrow;
    }
  }

  // Get contribution requests for a project (for owner)
  Stream<QuerySnapshot> getContributionRequests(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  // Get all contributors (accepted requests) for a project
  Stream<QuerySnapshot> getContributors(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('requests')
        .where('status', isEqualTo: 'accepted')
        .snapshots();
  }

  // Get contributor count for a project
  Future<int> getContributorCount(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .where('status', isEqualTo: 'accepted')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting contributor count: $e');
      return 0;
    }
  }

  // Accept a contribution request
  Future<void> acceptContributionRequest(
      String projectId, String requestId) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .doc(requestId)
          .update({'status': 'accepted'});
      debugPrint('Contribution request accepted');
    } catch (e) {
      debugPrint('Error accepting request: $e');
      rethrow;
    }
  }

  // Reject a contribution request
  Future<void> rejectContributionRequest(
      String projectId, String requestId) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .doc(requestId)
          .update({'status': 'rejected'});
      debugPrint('Contribution request rejected');
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      rethrow;
    }
  }

  // Check if current user has already requested to contribute
  Future<String?> getRequestStatus(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final request = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .where('userId', isEqualTo: user.uid)
          .get();

      if (request.docs.isEmpty) return null;
      return request.docs.first.data()['status'] as String?;
    } catch (e) {
      debugPrint('Error checking request status: $e');
      return null;
    }
  }

  // Get projects where current user is an accepted contributor
  Future<List<Map<String, dynamic>>> getContributingProjects() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      // Get all projects
      final projectsSnapshot = await _firestore.collection('projects').get();
      List<Map<String, dynamic>> contributingProjects = [];

      for (var projectDoc in projectsSnapshot.docs) {
        // Check if user is an accepted contributor in this project
        final requestSnapshot = await _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('requests')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'accepted')
            .get();

        if (requestSnapshot.docs.isNotEmpty) {
          final projectData = projectDoc.data();
          projectData['projectId'] = projectDoc.id;
          contributingProjects.add(projectData);
        }
      }

      // Sort by createdAt descending
      contributingProjects.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return contributingProjects;
    } catch (e) {
      debugPrint('Error getting contributing projects: $e');
      return [];
    }
  }
}
