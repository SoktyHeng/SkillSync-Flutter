import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class GroupChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Create a group chat for a project
  Future<String> createGroupChat({
    required String projectId,
    required String name,
    required List<String> memberIds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final docRef = await _firestore.collection('group_chats').add({
        'name': name,
        'projectId': projectId,
        'creatorId': user.uid,
        'members': memberIds,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'lastMessageSenderName': '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Group chat created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating group chat: $e');
      rethrow;
    }
  }

  /// Get or create a group chat for a project
  Future<String> getOrCreateGroupChat({
    required String projectId,
    required String projectTitle,
    required List<String> memberIds,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      // Check if group chat already exists for this project
      final existing = await _firestore
          .collection('group_chats')
          .where('projectId', isEqualTo: projectId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return existing.docs.first.id;
      }

      // Create new group chat
      return await createGroupChat(
        projectId: projectId,
        name: projectTitle,
        memberIds: memberIds,
      );
    } catch (e) {
      debugPrint('Error getting/creating group chat: $e');
      rethrow;
    }
  }

  /// Get group chat document by project ID
  Future<DocumentSnapshot?> getGroupChatByProjectId(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection('group_chats')
          .where('projectId', isEqualTo: projectId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting group chat by project: $e');
      return null;
    }
  }

  /// Send a message in a group chat
  Future<void> sendMessage({
    required String groupChatId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');
    if (text.trim().isEmpty) throw Exception('Message cannot be empty');

    try {
      // Get sender name
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'Unknown';

      final batch = _firestore.batch();

      // Add message to subcollection
      final messageRef = _firestore
          .collection('group_chats')
          .doc(groupChatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': user.uid,
        'senderName': senderName,
        'text': text.trim(),
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update group chat with last message info
      final groupChatRef =
          _firestore.collection('group_chats').doc(groupChatId);
      batch.update(groupChatRef, {
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'lastMessageSenderName': senderName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('Group message sent successfully');
    } catch (e) {
      debugPrint('Error sending group message: $e');
      rethrow;
    }
  }

  /// Send an image message in a group chat
  Future<void> sendImageMessage({
    required String groupChatId,
    required File imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      final senderName = userDoc.data()?['name'] ?? 'Unknown';

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('chat_images/groups/$groupChatId/${timestamp}_${user.uid}.jpg');

      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final imageUrl = await ref.getDownloadURL();

      final batch = _firestore.batch();

      final messageRef = _firestore
          .collection('group_chats')
          .doc(groupChatId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': user.uid,
        'senderName': senderName,
        'text': '',
        'type': 'image',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final groupChatRef =
          _firestore.collection('group_chats').doc(groupChatId);
      batch.update(groupChatRef, {
        'lastMessage': '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'lastMessageSenderName': senderName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('Group image message sent successfully');
    } catch (e) {
      debugPrint('Error sending group image message: $e');
      rethrow;
    }
  }

  /// Get real-time stream of messages for a group chat
  Stream<QuerySnapshot> getMessages(String groupChatId) {
    return _firestore
        .collection('group_chats')
        .doc(groupChatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Get real-time stream of all group chats for the current user
  Stream<QuerySnapshot> getGroupChats() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('group_chats')
        .where('members', arrayContains: user.uid)
        .snapshots();
  }

  /// Add a member to a group chat
  Future<void> addMember(String groupChatId, String userId) async {
    try {
      await _firestore.collection('group_chats').doc(groupChatId).update({
        'members': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Member added to group: $userId');
    } catch (e) {
      debugPrint('Error adding member: $e');
      rethrow;
    }
  }

  /// Remove a member from a group chat (creator only)
  Future<void> removeMember(String groupChatId, String userId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final groupDoc =
          await _firestore.collection('group_chats').doc(groupChatId).get();
      final creatorId = groupDoc.data()?['creatorId'];

      if (creatorId != user.uid) {
        throw Exception('Only the group creator can remove members');
      }

      await _firestore.collection('group_chats').doc(groupChatId).update({
        'members': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Member removed from group: $userId');
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  /// Leave a group chat
  Future<void> leaveGroup(String groupChatId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      await _firestore.collection('group_chats').doc(groupChatId).update({
        'members': FieldValue.arrayRemove([user.uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Left group chat: $groupChatId');
    } catch (e) {
      debugPrint('Error leaving group: $e');
      rethrow;
    }
  }

  /// Update group name (creator only)
  Future<void> updateGroupName(String groupChatId, String newName) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final groupDoc =
          await _firestore.collection('group_chats').doc(groupChatId).get();
      final creatorId = groupDoc.data()?['creatorId'];

      if (creatorId != user.uid) {
        throw Exception('Only the group creator can rename the group');
      }

      await _firestore.collection('group_chats').doc(groupChatId).update({
        'name': newName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Group name updated: $newName');
    } catch (e) {
      debugPrint('Error updating group name: $e');
      rethrow;
    }
  }

  /// Delete a group chat and all its messages (creator only)
  Future<void> deleteGroupChat(String groupChatId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final groupDoc =
          await _firestore.collection('group_chats').doc(groupChatId).get();
      final creatorId = groupDoc.data()?['creatorId'];

      if (creatorId != user.uid) {
        throw Exception('Only the group creator can delete the group');
      }

      // Delete all messages first
      final messagesSnapshot = await _firestore
          .collection('group_chats')
          .doc(groupChatId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore.collection('group_chats').doc(groupChatId));
      await batch.commit();

      debugPrint('Group chat deleted: $groupChatId');
    } catch (e) {
      debugPrint('Error deleting group chat: $e');
      rethrow;
    }
  }

  /// Get member details for a group chat
  Future<List<Map<String, dynamic>>> getMembers(String groupChatId) async {
    try {
      final groupDoc =
          await _firestore.collection('group_chats').doc(groupChatId).get();
      final memberIds =
          List<String>.from(groupDoc.data()?['members'] ?? []);

      final members = <Map<String, dynamic>>[];
      for (final uid in memberIds) {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists) {
          members.add({
            'uid': uid,
            'name': userDoc.data()?['name'] ?? 'Unknown',
            'profileImageUrl': userDoc.data()?['profileImageUrl'],
          });
        }
      }
      return members;
    } catch (e) {
      debugPrint('Error getting group members: $e');
      return [];
    }
  }
}
