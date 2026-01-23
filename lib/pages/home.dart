import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/project_detail.dart';
import 'package:skillsync_sp2/pages/user_profile.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProjectService _projectService = ProjectService();
  String _selectedDuration = 'All';

  final List<String> _durationFilters = [
    'All',
    '1 week',
    '2 weeks',
    '1 month',
    '3 months',
    'Ongoing',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Discover Projects'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Duration Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _durationFilters.map((duration) {
                  final isSelected = _selectedDuration == duration;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(duration),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedDuration = duration;
                        });
                      },
                      backgroundColor: Colors.grey[100],
                      selectedColor: Colors.deepPurple[100],
                      checkmarkColor: Colors.deepPurple[700],
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.deepPurple[700]
                            : Colors.grey[700],
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.deepPurple[300]!
                              : Colors.grey[300]!,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Projects List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _projectService.getAllProjects(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepPurple[500],
                    ),
                  );
                }

                final allProjects = snapshot.data?.docs ?? [];
                final currentUserId = FirebaseAuth.instance.currentUser?.uid;

                // Filter out current user's projects and apply duration filter
                final projects = allProjects.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Exclude current user's projects
                  if (data['uid'] == currentUserId) return false;

                  // Apply duration filter
                  if (_selectedDuration != 'All') {
                    final duration =
                        (data['duration'] as String?)?.toLowerCase() ?? '';
                    if (!duration.contains(_selectedDuration.toLowerCase())) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDuration == 'All'
                              ? 'No projects yet'
                              : 'No projects with $_selectedDuration duration',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for new projects!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    final project =
                        projects[index].data() as Map<String, dynamic>;
                    final projectId = projects[index].id;
                    return _ProjectFeedCard(
                      project: project,
                      projectId: projectId,
                      projectService: _projectService,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectFeedCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final String projectId;
  final ProjectService projectService;

  const _ProjectFeedCard({
    required this.project,
    required this.projectId,
    required this.projectService,
  });

  @override
  State<_ProjectFeedCard> createState() => _ProjectFeedCardState();
}

class _ProjectFeedCardState extends State<_ProjectFeedCard> {
  String _creatorName = '';
  String? _creatorImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreatorInfo();
  }

  Future<void> _loadCreatorInfo() async {
    final userInfo = await widget.projectService.getUserInfo(
      widget.project['uid'],
    );
    if (mounted) {
      setState(() {
        _creatorName = userInfo['name'] ?? 'Unknown User';
        _creatorImageUrl = userInfo['profileImageUrl'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetail(
              project: widget.project,
              projectId: widget.projectId,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creator Info Row
            Row(
              children: [
                // Profile Picture and Name - Tappable to view profile
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
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.deepPurple[100],
                        backgroundImage: _creatorImageUrl != null
                            ? NetworkImage(_creatorImageUrl!)
                            : null,
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.deepPurple[300],
                                ),
                              )
                            : _creatorImageUrl == null
                            ? Icon(
                                Icons.person,
                                color: Colors.deepPurple[400],
                                size: 24,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _creatorName.isNotEmpty ? _creatorName : 'Loading...',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Time ago
                Text(
                  _getTimeAgo(widget.project['createdAt'] as Timestamp?),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Project Title
            Text(
              widget.project['title'] ?? 'Untitled Project',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              widget.project['description'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),

            // Tech Stack
            if (techStack.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: techStack.take(5).map((tech) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tech,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Looking For
            if (lookingFor.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 16,
                    color: Colors.green[600],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Looking for: ${lookingFor.join(", ")}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w ago';
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
}
