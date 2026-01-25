import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  // Submit a new rating or update existing one
  Future<void> submitRating({
    required String ratedUserId,
    required int rating,
    String? feedback,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('No user logged in');
    }

    if (currentUser.uid == ratedUserId) {
      throw Exception('Cannot rate yourself');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('Rating must be between 1 and 5');
    }

    // Check if user has already rated this person
    final existingRating = await getMyRatingForUser(ratedUserId);

    if (existingRating != null) {
      // Update existing rating
      await _firestore.collection('ratings').doc(existingRating['id']).update({
        'rating': rating,
        'feedback': feedback ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new rating
      await _firestore.collection('ratings').add({
        'ratedUserId': ratedUserId,
        'raterUserId': currentUser.uid,
        'rating': rating,
        'feedback': feedback ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update user's average rating
    await updateUserAverageRating(ratedUserId);
  }

  // Get all ratings for a specific user
  Stream<QuerySnapshot> getUserRatings(String userId) {
    // Note: Removed orderBy to avoid needing a composite index
    // Results are sorted client-side in the UI if needed
    return _firestore
        .collection('ratings')
        .where('ratedUserId', isEqualTo: userId)
        .snapshots();
  }

  // Get current user's rating for a specific user
  Future<Map<String, dynamic>?> getMyRatingForUser(String userId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final query = await _firestore
        .collection('ratings')
        .where('ratedUserId', isEqualTo: userId)
        .where('raterUserId', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return {
      'id': doc.id,
      ...doc.data(),
    };
  }

  // Check if current user has already rated a user
  Future<bool> hasRatedUser(String userId) async {
    final rating = await getMyRatingForUser(userId);
    return rating != null;
  }

  // Calculate and update user's average rating
  Future<void> updateUserAverageRating(String userId) async {
    final ratingsQuery = await _firestore
        .collection('ratings')
        .where('ratedUserId', isEqualTo: userId)
        .get();

    if (ratingsQuery.docs.isEmpty) {
      await _firestore.collection('users').doc(userId).update({
        'averageRating': 0,
        'totalRatings': 0,
      });
      return;
    }

    double totalRating = 0;
    for (var doc in ratingsQuery.docs) {
      totalRating += (doc.data()['rating'] as num).toDouble();
    }

    final averageRating = totalRating / ratingsQuery.docs.length;

    await _firestore.collection('users').doc(userId).update({
      'averageRating': averageRating,
      'totalRatings': ratingsQuery.docs.length,
    });
  }

  // Delete a rating
  Future<void> deleteRating(String ratedUserId) async {
    final existingRating = await getMyRatingForUser(ratedUserId);
    if (existingRating != null) {
      await _firestore.collection('ratings').doc(existingRating['id']).delete();
      await updateUserAverageRating(ratedUserId);
    }
  }

  // Get rater info for displaying in reviews
  Future<Map<String, dynamic>> getRaterInfo(String raterId) async {
    final doc = await _firestore.collection('users').doc(raterId).get();
    return {
      'name': doc.data()?['name'] ?? 'Unknown User',
      'profileImageUrl': doc.data()?['profileImageUrl'],
    };
  }
}
