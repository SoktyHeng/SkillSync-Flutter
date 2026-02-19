import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:skillsync_sp2/services/group_chat_service.dart';

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
    String status = 'recruiting',
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
      'status': status,
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

  // Get paginated projects
  Future<QuerySnapshot> getProjectsPaginated({
    int limit = 10,
    DocumentSnapshot? lastDoc,
  }) {
    Query query = _firestore
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    return query.get();
  }

  // Get a single project by ID
  Future<Map<String, dynamic>?> getProjectById(String projectId) async {
    try {
      final doc = await _firestore.collection('projects').doc(projectId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting project: $e');
      return null;
    }
  }

  // Toggle bookmark for a project
  Future<bool> toggleBookmark(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final bookmarkRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('bookmarks')
        .doc(projectId);

    try {
      final doc = await bookmarkRef.get();
      if (doc.exists) {
        await bookmarkRef.delete();
        return false; // unbookmarked
      } else {
        await bookmarkRef.set({
          'createdAt': FieldValue.serverTimestamp(),
        });
        return true; // bookmarked
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
      rethrow;
    }
  }

  // Check if a project is bookmarked
  Future<bool> isBookmarked(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .doc(projectId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking bookmark: $e');
      return false;
    }
  }

  // Get all bookmarked projects
  Future<List<Map<String, dynamic>>> getBookmarkedProjects() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final bookmarksSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('bookmarks')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> projects = [];

      for (var bookmarkDoc in bookmarksSnapshot.docs) {
        final projectDoc = await _firestore
            .collection('projects')
            .doc(bookmarkDoc.id)
            .get();

        if (projectDoc.exists) {
          final projectData = projectDoc.data()!;
          projectData['projectId'] = projectDoc.id;
          projects.add(projectData);
        } else {
          // Project was deleted, clean up bookmark
          await bookmarkDoc.reference.delete();
        }
      }

      return projects;
    } catch (e) {
      debugPrint('Error getting bookmarked projects: $e');
      return [];
    }
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

  // Update project status
  Future<void> updateProjectStatus({
    required String projectId,
    required String status,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      await _firestore.collection('projects').doc(projectId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Project status updated successfully');
    } catch (e) {
      debugPrint('Error updating project status: $e');
      rethrow;
    }
  }

  // Update a project
  Future<void> updateProject({
    required String projectId,
    required String title,
    required String description,
    required List<String> techStack,
    required List<String> lookingFor,
    String? duration,
    String status = 'recruiting',
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
        'status': status,
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
      // Get the request to find the user ID
      final requestDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .doc(requestId)
          .get();

      final requestUserId = requestDoc.data()?['userId'] as String?;

      // Update request status
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .doc(requestId)
          .update({'status': 'accepted'});
      debugPrint('Contribution request accepted');

      // Auto-create or update group chat for the project
      if (requestUserId != null) {
        await _addToProjectGroupChat(projectId, requestUserId);
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
      rethrow;
    }
  }

  // Add a new contributor to the project's group chat
  Future<void> _addToProjectGroupChat(
      String projectId, String newMemberId) async {
    final groupChatService = GroupChatService();

    try {
      // Check if group chat already exists for this project
      final existingGroupChat =
          await groupChatService.getGroupChatByProjectId(projectId);

      if (existingGroupChat != null) {
        // Add the new member to the existing group chat
        await groupChatService.addMember(existingGroupChat.id, newMemberId);
      } else {
        // Create a new group chat with the project owner and new contributor
        final projectDoc =
            await _firestore.collection('projects').doc(projectId).get();
        final projectData = projectDoc.data();
        if (projectData == null) return;

        final ownerId = projectData['uid'] as String;
        final projectTitle = projectData['title'] as String? ?? 'Project Chat';

        // Get all existing accepted contributors
        final acceptedRequests = await _firestore
            .collection('projects')
            .doc(projectId)
            .collection('requests')
            .where('status', isEqualTo: 'accepted')
            .get();

        final memberIds = <String>{ownerId};
        for (final doc in acceptedRequests.docs) {
          final userId = doc.data()['userId'] as String?;
          if (userId != null) memberIds.add(userId);
        }

        await groupChatService.createGroupChat(
          projectId: projectId,
          name: projectTitle,
          memberIds: memberIds.toList(),
        );
      }
    } catch (e) {
      // Don't rethrow - group chat creation failure shouldn't block acceptance
      debugPrint('Error managing project group chat: $e');
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

  // Remove a contributor from the project and its group chat
  Future<void> removeContributor(
      String projectId, String requestId, String userId) async {
    try {
      // Delete the request document
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('requests')
          .doc(requestId)
          .delete();
      debugPrint('Contributor removed from project');

      // Also remove from the project's group chat
      final groupChatService = GroupChatService();
      final existingGroupChat =
          await groupChatService.getGroupChatByProjectId(projectId);
      if (existingGroupChat != null) {
        await groupChatService.removeMember(existingGroupChat.id, userId);
      }
    } catch (e) {
      debugPrint('Error removing contributor: $e');
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
      // Use collectionGroup query to find all accepted requests for this user
      final requestsSnapshot = await _firestore
          .collectionGroup('requests')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      List<Map<String, dynamic>> contributingProjects = [];

      for (var requestDoc in requestsSnapshot.docs) {
        // Get the parent project ID from the request document path
        final projectId = requestDoc.reference.parent.parent!.id;
        final projectDoc =
            await _firestore.collection('projects').doc(projectId).get();

        if (projectDoc.exists) {
          final projectData = projectDoc.data()!;
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
