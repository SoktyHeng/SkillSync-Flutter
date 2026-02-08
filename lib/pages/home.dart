import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDuration = 'All';

  final List<String> _durationFilters = [
    'All',
    'Less than 1 week',
    '1-2 weeks',
    '2-4 weeks',
    '1-3 months',
    '3+ months',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearchQuery(Map<String, dynamic> project) {
    if (_searchQuery.isEmpty) return true;

    final query = _searchQuery.toLowerCase();
    final title = (project['title'] as String? ?? '').toLowerCase();
    final techStack = List<String>.from(project['techStack'] ?? []);
    final lookingFor = List<String>.from(project['lookingFor'] ?? []);

    // Check title
    if (title.contains(query)) return true;

    // Check tech stack
    for (final tech in techStack) {
      if (tech.toLowerCase().contains(query)) return true;
    }

    // Check looking for roles
    for (final role in lookingFor) {
      if (role.toLowerCase().contains(query)) return true;
    }

    return false;
  }

  bool _matchesDurationFilter(String? durationString) {
    if (_selectedDuration == 'All') return true;
    if (durationString == null || durationString.isEmpty) return false;
    if (durationString == 'Ongoing') return _selectedDuration == '3+ months';

    // Parse duration string format: "25 Jan 2026 - 15 Feb 2026"
    try {
      final parts = durationString.split(' - ');
      if (parts.length != 2) return false;

      final dateFormat = DateFormat('d MMM yyyy');
      final startDate = dateFormat.parse(parts[0]);
      final endDate = dateFormat.parse(parts[1]);
      final durationInDays = endDate.difference(startDate).inDays;

      switch (_selectedDuration) {
        case 'Less than 1 week':
          return durationInDays < 7;
        case '1-2 weeks':
          return durationInDays >= 7 && durationInDays <= 14;
        case '2-4 weeks':
          return durationInDays >= 15 && durationInDays <= 30;
        case '1-3 months':
          return durationInDays >= 31 && durationInDays <= 90;
        case '3+ months':
          return durationInDays > 90;
        default:
          return true;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(title: const Text('Discover Projects')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by title, tech stack, or role...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.deepPurple[300]!,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Duration Filter Bar
          Container(
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
                      backgroundColor: isDark
                          ? const Color(0xFF121212)
                          : Colors.white,
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

                // Filter out current user's projects and apply filters
                final projects = allProjects.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  // Exclude current user's projects
                  if (data['uid'] == currentUserId) return false;

                  // Apply search filter
                  if (!_matchesSearchQuery(data)) return false;

                  // Apply duration filter
                  if (_selectedDuration != 'All') {
                    final duration = data['duration'] as String?;
                    if (!_matchesDurationFilter(duration)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (projects.isEmpty) {
                  String emptyMessage;
                  String emptySubtitle;

                  if (_searchQuery.isNotEmpty) {
                    emptyMessage = 'No projects found for "$_searchQuery"';
                    emptySubtitle = 'Try a different search term';
                  } else if (_selectedDuration != 'All') {
                    emptyMessage =
                        'No projects with $_selectedDuration duration';
                    emptySubtitle = 'Try a different duration filter';
                  } else {
                    emptyMessage = 'No projects yet';
                    emptySubtitle = 'Check back later for new projects!';
                  }

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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            emptyMessage,
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptySubtitle,
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
  int _contributorCount = 0;
  String? _userRequestStatus;

  @override
  void initState() {
    super.initState();
    _loadCreatorInfo();
    _loadContributorCount();
    _loadUserRequestStatus();
  }

  Future<void> _loadUserRequestStatus() async {
    final status = await widget.projectService.getRequestStatus(
      widget.projectId,
    );
    if (mounted) {
      setState(() {
        _userRequestStatus = status;
      });
    }
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

  Future<void> _loadContributorCount() async {
    final count = await widget.projectService.getContributorCount(
      widget.projectId,
    );
    if (mounted) {
      setState(() {
        _contributorCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetail(
              project: widget.project,
              projectId: widget.projectId,
            ),
          ),
        );
        // Refresh status when returning from project detail
        if (mounted && result == true) {
          setState(() {
            _userRequestStatus = 'pending';
          });
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        color: Theme.of(context).cardColor,
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
                          builder: (context) =>
                              UserProfilePage(userId: widget.project['uid']),
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
                  // Status icon
                  if (_userRequestStatus == 'pending') ...[
                    Icon(
                      Icons.hourglass_top,
                      size: 18,
                      color: Colors.orange[600],
                    ),
                    const SizedBox(width: 8),
                  ] else if (_userRequestStatus == 'accepted') ...[
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 8),
                  ],
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
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
                    Expanded(
                      child: Text(
                        'Looking for: ${lookingFor.join(", ")}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Contributors count
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '$_contributorCount ${_contributorCount == 1 ? 'contributor' : 'contributors'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
