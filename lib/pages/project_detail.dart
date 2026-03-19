import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/user_profile.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class ProjectDetail extends StatefulWidget {
  final Map<String, dynamic> project;
  final String projectId;

  const ProjectDetail({
    super.key,
    required this.project,
    required this.projectId,
  });

  @override
  State<ProjectDetail> createState() => _ProjectDetailState();
}

class _ProjectDetailState extends State<ProjectDetail> {
  final ProjectService _projectService = ProjectService();
  String _creatorName = '';
  String? _creatorImageUrl;
  bool _isLoading = true;
  String? _requestStatus;
  bool _isRequesting = false;
  bool _didRequestThisSession = false;
  bool _isBookmarked = false;
  List<String> _takenRoles = [];
  double _averageRating = 0.0;
  int _ratingCount = 0;
  int? _userRating;
  bool _isRating = false;

  @override
  void initState() {
    super.initState();
    _loadCreatorInfo();
    _loadRequestStatus();
    _loadBookmarkStatus();
    _loadTakenRoles();
    _loadRating();
  }

  Future<void> _loadBookmarkStatus() async {
    final bookmarked = await _projectService.isBookmarked(widget.projectId);
    if (mounted) {
      setState(() {
        _isBookmarked = bookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    try {
      final isNowBookmarked = await _projectService.toggleBookmark(widget.projectId);
      if (mounted) {
        setState(() {
          _isBookmarked = isNowBookmarked;
        });
      }
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  Future<void> _loadCreatorInfo() async {
    final userInfo = await _projectService.getUserInfo(widget.project['uid']);
    if (mounted) {
      setState(() {
        _creatorName = userInfo['name'] ?? 'Unknown User';
        _creatorImageUrl = userInfo['profileImageUrl'];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRequestStatus() async {
    final status = await _projectService.getRequestStatus(widget.projectId);
    if (mounted) {
      setState(() {
        _requestStatus = status;
      });
    }
  }

  Future<void> _loadTakenRoles() async {
    final taken = await _projectService.getTakenRoles(widget.projectId);
    if (mounted) {
      setState(() {
        _takenRoles = taken;
      });
    }
  }

  Future<void> _loadRating() async {
    final ratingData = await _projectService.getProjectRating(widget.projectId);
    final userRating = await _projectService.getUserRating(widget.projectId);
    if (mounted) {
      setState(() {
        _averageRating = (ratingData['average'] as num).toDouble();
        _ratingCount = ratingData['count'] as int;
        _userRating = userRating;
      });
    }
  }

  Future<void> _submitRating(int rating) async {
    setState(() => _isRating = true);
    try {
      await _projectService.rateProject(widget.projectId, rating);
      if (mounted) {
        setState(() {
          _userRating = rating;
          _isRating = false;
        });
        await _loadRating();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit rating: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildStars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (rating >= i + 1) {
          return Icon(Icons.star, size: size, color: Colors.amber[600]);
        } else if (rating >= i + 0.5) {
          return Icon(Icons.star_half, size: size, color: Colors.amber[600]);
        } else {
          return Icon(Icons.star_border, size: size, color: Colors.amber[600]);
        }
      }),
    );
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _sendContributeRequest({String? role}) async {
    setState(() {
      _isRequesting = true;
    });

    try {
      await _projectService.requestToContribute(widget.projectId, role: role);
      if (mounted) {
        setState(() {
          _requestStatus = 'pending';
          _isRequesting = false;
          _didRequestThisSession = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request sent successfully!'),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showContributeDialog() {
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);
    final availableRoles =
        lookingFor.where((r) => !_takenRoles.contains(r)).toList();
    String? selectedRole = availableRoles.isNotEmpty ? availableRoles.first : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Request to Contribute'),
          content: lookingFor.isEmpty
              ? const Text(
                  'Would you like to send a request to join this project? The project owner will review your request.',
                )
              : availableRoles.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'All roles have been filled',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'There are no open positions left for this project.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select the role you\'d like to fill:'),
                    const SizedBox(height: 12),
                    ...availableRoles.map((role) {
                      final isSelected = selectedRole == role;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedRole = role),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple[50]
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepPurple[400]!
                                  : Colors.grey[300]!,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 18,
                                color: isSelected
                                    ? Colors.deepPurple[500]
                                    : Colors.grey[400],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  role,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (lookingFor.isNotEmpty && selectedRole == null)
                  ? null
                  : availableRoles.isEmpty && lookingFor.isNotEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          _sendContributeRequest(role: selectedRole);
                        },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[500],
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Map<String, Map<String, dynamic>> statusConfig = {
      'recruiting': {'label': 'Recruiting', 'color': Colors.deepPurple},
      'in_progress': {'label': 'In Progress', 'color': Colors.orange},
      'completed': {'label': 'Completed', 'color': Colors.green},
    };
    final config = statusConfig[status] ?? statusConfig['recruiting']!;
    final MaterialColor color = config['color'] as MaterialColor;
    final String label = config['label'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color[200]!),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color[700],
        ),
      ),
    );
  }

  Widget _buildContributeButton() {
    if (_isRequesting) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple[300],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_requestStatus == 'pending') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[400],
          disabledBackgroundColor: Colors.orange[400],
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 20),
            SizedBox(width: 8),
            Text(
              'Request Pending',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_requestStatus == 'accepted') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[500],
          disabledBackgroundColor: Colors.green[500],
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 20),
            SizedBox(width: 8),
            Text(
              'You\'re a Contributor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_requestStatus == 'rejected') {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[400],
          disabledBackgroundColor: Colors.grey[400],
          disabledForegroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, size: 20),
            SizedBox(width: 8),
            Text(
              'Request Declined',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return ElevatedButton(
      onPressed: _showContributeDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple[500],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      child: const Text(
        'Contribute',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);
    final duration = widget.project['duration'] as String?;
    final description = widget.project['description'] ?? '';
    final title = widget.project['title'] ?? 'Untitled Project';
    final status = widget.project['status'] as String? ?? 'recruiting';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didRequestThisSession);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Project Details'),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.deepPurple[500] : null,
              ),
              tooltip: _isBookmarked ? 'Remove from saved' : 'Save project',
              onPressed: _toggleBookmark,
            ),
          ],
        ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creator Info Section - Tappable to view profile
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: widget.project['uid'],
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey[50],
                  border: Border(bottom: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800]! : Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple[100],
                      backgroundImage: _creatorImageUrl != null
                          ? NetworkImage(_creatorImageUrl!)
                          : null,
                      child: _isLoading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepPurple[300],
                              ),
                            )
                          : _creatorImageUrl == null
                          ? Icon(
                              Icons.person,
                              color: Colors.deepPurple[400],
                              size: 28,
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _creatorName.isNotEmpty ? _creatorName : 'Loading...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Posted ${_getTimeAgo(widget.project['createdAt'] as Timestamp?)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),

            // Project Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Average Rating
                  if (_ratingCount > 0)
                    Row(
                      children: [
                        _buildStars(_averageRating, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '($_ratingCount ${_ratingCount == 1 ? 'rating' : 'ratings'})',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Duration
                  if (duration != null && duration.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 18,
                            color: Colors.deepPurple[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Timeline: $duration',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Description Section
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Skill Section
                  if (techStack.isNotEmpty) ...[
                    const Text(
                      'Skill',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: techStack.map((tech) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            tech,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[700],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Looking For Section
                  if (lookingFor.isNotEmpty) ...[
                    const Text(
                      'Looking For Roles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...lookingFor.map((role) {
                      final isFilled = _takenRoles.contains(role);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isFilled
                                    ? Colors.grey[100]
                                    : Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isFilled
                                    ? Icons.check_circle
                                    : Icons.person_search,
                                size: 20,
                                color: isFilled
                                    ? Colors.grey[400]
                                    : Colors.green[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                role,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: isFilled
                                      ? Colors.grey[400]
                                      : Colors.grey[800],
                                  fontWeight: FontWeight.w500,
                                  decoration: isFilled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                            if (isFilled)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Filled',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600]),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Open',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.green[700]),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],

                  // Rate this project (contributors only)
                  if (_requestStatus == 'accepted') ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Rate this Project',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userRating != null
                          ? 'Your rating: $_userRating/5 — tap to change'
                          : 'Share your experience as a contributor',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        return GestureDetector(
                          onTap: _isRating ? null : () => _submitRating(star),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(
                              star <= (_userRating ?? 0)
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 36,
                              color: _isRating
                                  ? Colors.amber[300]
                                  : Colors.amber[600],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],

                  // Bottom spacing for button
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: _buildContributeButton(),
          ),
        ),
      ),
    ),
    );
  }
}
