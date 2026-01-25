import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/services/rating_service.dart';
import 'package:skillsync_sp2/widgets/star_rating.dart';

class ReviewCard extends StatefulWidget {
  final Map<String, dynamic> review;

  const ReviewCard({super.key, required this.review});

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  final RatingService _ratingService = RatingService();
  String _raterName = '';
  String? _raterImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRaterInfo();
  }

  Future<void> _loadRaterInfo() async {
    final info = await _ratingService.getRaterInfo(widget.review['raterUserId']);
    if (mounted) {
      setState(() {
        _raterName = info['name'] ?? 'Unknown User';
        _raterImageUrl = info['profileImageUrl'];
        _isLoading = false;
      });
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.deepPurple[100],
                backgroundImage: _raterImageUrl != null
                    ? NetworkImage(_raterImageUrl!)
                    : null,
                child: _isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurple[300],
                        ),
                      )
                    : _raterImageUrl == null
                        ? Icon(
                            Icons.person,
                            color: Colors.deepPurple[400],
                            size: 18,
                          )
                        : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _raterName.isNotEmpty ? _raterName : 'Loading...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StarRating(
                      rating: (widget.review['rating'] as num).toDouble(),
                      size: 14,
                    ),
                  ],
                ),
              ),
              Text(
                _getTimeAgo(widget.review['createdAt'] as Timestamp?),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          if (widget.review['feedback'] != null &&
              (widget.review['feedback'] as String).isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.review['feedback'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
