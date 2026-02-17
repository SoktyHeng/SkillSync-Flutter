import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  /// Generate a unique conversation ID from two user IDs
  String _generateConversationId(String uid1, String uid2) {
    final sortedUids = [uid1, uid2]..sort();
    return '${sortedUids[0]}_${sortedUids[1]}';
  }

  /// Get or create a conversation between the current user and another user
  Future<String> getOrCreateConversation(String otherUserId,
      {int maxRetries = 3}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    final conversationId = _generateConversationId(user.uid, otherUserId);
    final conversationRef =
        _firestore.collection('conversations').doc(conversationId);

    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final doc = await conversationRef.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Connection timeout. Please check your internet.');
          },
        );

        if (!doc.exists) {
          await conversationRef.set({
            'participants': [user.uid, otherUserId],
            'lastMessage': '',
            'lastMessageTime': FieldValue.serverTimestamp(),
            'lastMessageSenderId': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout. Please check your internet.');
            },
          );
          debugPrint('Conversation created: $conversationId');
        }

        return conversationId;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        debugPrint(
            'Error getting/creating conversation (attempt ${attempt + 1}): $e');

        if (attempt < maxRetries - 1) {
          // Wait before retrying with exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      }
    }

    throw lastException ?? Exception('Failed to create conversation');
  }

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    if (text.trim().isEmpty) {
      throw Exception('Message cannot be empty');
    }

    try {
      final batch = _firestore.batch();

      // Add message to subcollection
      final messageRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': user.uid,
        'text': text.trim(),
        'type': 'text',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update conversation with last message info
      final conversationRef =
          _firestore.collection('conversations').doc(conversationId);
      batch.update(conversationRef, {
        'lastMessage': text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('Message sent successfully');
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Send an image message in a conversation
  Future<void> sendImageMessage({
    required String conversationId,
    required File imageFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user logged in');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('chat_images/$conversationId/${timestamp}_${user.uid}.jpg');

      await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final imageUrl = await ref.getDownloadURL();

      final batch = _firestore.batch();

      final messageRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .doc();

      batch.set(messageRef, {
        'senderId': user.uid,
        'text': '',
        'type': 'image',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final conversationRef =
          _firestore.collection('conversations').doc(conversationId);
      batch.update(conversationRef, {
        'lastMessage': '📷 Photo',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('Image message sent successfully');
    } catch (e) {
      debugPrint('Error sending image message: $e');
      rethrow;
    }
  }

  /// Get real-time stream of latest messages for a conversation
  Stream<QuerySnapshot> getMessages(String conversationId, {int limit = 30}) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Get older messages before a given document for pagination
  Future<QuerySnapshot> getOlderMessages(
    String conversationId, {
    required DocumentSnapshot lastDoc,
    int limit = 30,
  }) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .startAfterDocument(lastDoc)
        .limit(limit)
        .get();
  }

  /// Get real-time stream of all conversations for the current user
  Stream<QuerySnapshot> getConversations() {
    final user = _auth.currentUser;
    if (user == null) {
      return const Stream.empty();
    }

    // Note: Removed orderBy to avoid requiring composite index
    // Sorting is done client-side in the UI
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots();
  }

  /// Delete a conversation and all its messages
  Future<void> deleteConversation(String conversationId) async {
    try {
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(
          _firestore.collection('conversations').doc(conversationId));
      await batch.commit();
      debugPrint('Conversation deleted: $conversationId');
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Get information about the other participant in a conversation
  Future<Map<String, dynamic>> getOtherParticipantInfo(
      String conversationId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'name': 'Unknown User', 'profileImageUrl': null};
    }

    try {
      final conversationDoc =
          await _firestore.collection('conversations').doc(conversationId).get();

      if (!conversationDoc.exists) {
        return {'name': 'Unknown User', 'profileImageUrl': null};
      }

      final participants =
          List<String>.from(conversationDoc.data()?['participants'] ?? []);
      final otherUserId = participants.firstWhere(
        (uid) => uid != user.uid,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) {
        return {'name': 'Unknown User', 'profileImageUrl': null};
      }

      final userDoc =
          await _firestore.collection('users').doc(otherUserId).get();
      return {
        'uid': otherUserId,
        'name': userDoc.data()?['name'] ?? 'Unknown User',
        'profileImageUrl': userDoc.data()?['profileImageUrl'],
      };
    } catch (e) {
      debugPrint('Error getting participant info: $e');
      return {'name': 'Unknown User', 'profileImageUrl': null};
    }
  }
}
