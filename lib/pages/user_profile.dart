import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/chat_page.dart';
import 'package:skillsync_sp2/services/chat_service.dart';
import 'package:skillsync_sp2/services/rating_service.dart';
import 'package:skillsync_sp2/services/user_service.dart';
import 'package:skillsync_sp2/widgets/rating_dialog.dart';
import 'package:skillsync_sp2/widgets/review_card.dart';
import 'package:skillsync_sp2/widgets/star_rating.dart';
import 'package:url_launcher/url_launcher.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final UserService _userService = UserService();
  final RatingService _ratingService = RatingService();
  final ChatService _chatService = ChatService();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  Map<String, dynamic>? _myExistingRating;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final userData = await _userService.getUserProfileById(widget.userId);
      final myRating = await _ratingService.getMyRatingForUser(widget.userId);

      if (mounted) {
        setState(() {
          _userData = userData;
          _isOwnProfile = currentUserId == widget.userId;
          _myExistingRating = myRating;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showRatingDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RatingDialog(
        userId: widget.userId,
        userName: _userData?['name'] ?? 'User',
        existingRating: _myExistingRating,
      ),
    );

    if (result == true) {
      // Refresh data after rating
      _loadUserData();
    }
  }

  Future<void> _openGitHub() async {
    final githubUrl = _userData?['githubUrl'];
    if (githubUrl != null && githubUrl.toString().isNotEmpty) {
      final uri = Uri.parse(githubUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _openChat() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final conversationId =
          await _chatService.getOrCreateConversation(widget.userId);

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: conversationId,
              otherUserId: widget.userId,
              otherUserName: _userData?['name'] ?? 'User',
              otherUserImageUrl: _userData?['profileImageUrl'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        String errorMessage = 'Unable to start chat. Please try again.';
        if (e.toString().contains('timeout') ||
            e.toString().contains('unavailable')) {
          errorMessage = 'Connection issue. Please check your internet and try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _openChat,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Profile'),
        elevation: 0,
        actions: [
          if (!_isOwnProfile && !_isLoading && _userData != null)
            IconButton(
              icon: Icon(Icons.message_outlined, color: Colors.deepPurple[500]),
              onPressed: _openChat,
              tooltip: 'Send Message',
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.deepPurple[500]),
            )
          : _userData == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      _buildProfileHeader(),

                      // About Section
                      _buildAboutSection(),

                      // Skills Section
                      _buildSkillsSection(),

                      // Reviews Section
                      _buildReviewsSection(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
      bottomNavigationBar: _isOwnProfile || _isLoading || _userData == null
          ? null
          : _buildRateButton(),
    );
  }

  Widget _buildProfileHeader() {
    final averageRating = (_userData?['averageRating'] ?? 0).toDouble();
    final totalRatings = _userData?['totalRatings'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.deepPurple[100],
            backgroundImage: _userData?['profileImageUrl'] != null
                ? NetworkImage(_userData!['profileImageUrl'])
                : null,
            child: _userData?['profileImageUrl'] == null
                ? Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.deepPurple[400],
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            _userData?['name'] ?? 'Unknown User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StarRating(rating: averageRating, size: 20),
              const SizedBox(width: 8),
              Text(
                averageRating > 0 ? averageRating.toStringAsFixed(1) : 'No ratings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              if (totalRatings > 0) ...[
                Text(
                  ' ($totalRatings ${totalRatings == 1 ? 'review' : 'reviews'})',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.school_outlined, 'Major', _userData?['major']),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Year',
            _userData?['yearOfStudy'],
          ),
          if (_userData?['githubUrl'] != null &&
              (_userData!['githubUrl'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _openGitHub,
              child: Row(
                children: [
                  Icon(Icons.code, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _userData?['githubUsername'] != null &&
                                  (_userData!['githubUsername'] as String)
                                      .isNotEmpty
                              ? '@${_userData!['githubUsername']}'
                              : 'View GitHub Profile',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.deepPurple[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_userData?['githubLinked'] == true) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified, size: 16, color: Colors.green[600]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Colors.deepPurple[500],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value ?? 'Not specified',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsSection() {
    final skills = _userData?['skills'] as List<dynamic>? ?? [];

    if (skills.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Skills',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.deepPurple[200]!),
                ),
                child: Text(
                  skill.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.deepPurple[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reviews',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _ratingService.getUserRatings(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      color: Colors.deepPurple[500],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No reviews yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort reviews by createdAt descending (newest first)
              final reviews = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final review = reviews[index].data() as Map<String, dynamic>;
                  return ReviewCard(review: review);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRateButton() {
    final hasRated = _myExistingRating != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _showRatingDialog,
            icon: Icon(hasRated ? Icons.edit : Icons.star_outline),
            label: Text(
              hasRated ? 'Update Your Rating' : 'Rate This User',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple[500],
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
