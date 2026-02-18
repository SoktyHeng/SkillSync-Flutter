import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skillsync_sp2/pages/project_detail.dart';
import 'package:skillsync_sp2/pages/user_profile.dart';
import 'package:skillsync_sp2/pages/saved_projects.dart';
import 'package:skillsync_sp2/pages/user_search.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProjectService _projectService = ProjectService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedDuration = 'All';
  String _selectedStatus = 'All';

  final List<String> _durationFilters = [
    'All',
    'Less than 1 week',
    '1-2 weeks',
    '2-4 weeks',
    '1-3 months',
    '3+ months',
  ];

  // Pagination state
  final List<DocumentSnapshot> _projects = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreProjects();
    }
  }

  Future<void> _loadProjects() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot = await _projectService.getProjectsPaginated(
        limit: _pageSize,
      );
      setState(() {
        _projects.clear();
        _projects.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreProjects() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);

    try {
      final snapshot = await _projectService.getProjectsPaginated(
        limit: _pageSize,
        lastDoc: _lastDoc,
      );
      setState(() {
        _projects.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  bool get _hasActiveFilters => _selectedDuration != 'All' || _selectedStatus != 'All';

  Widget _buildFilterButton(bool isDark) {
    return GestureDetector(
      onTap: () => _showFilterBottomSheet(isDark),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: _hasActiveFilters
              ? Colors.deepPurple[50]
              : (isDark ? Colors.grey[800] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: _hasActiveFilters
              ? Border.all(color: Colors.deepPurple[300]!)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.tune,
              color: _hasActiveFilters ? Colors.deepPurple[600] : Colors.grey[600],
            ),
            if (_hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[500],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Projects',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (_hasActiveFilters)
                        TextButton(
                          onPressed: () {
                            setSheetState(() {});
                            setState(() {
                              _selectedDuration = 'All';
                              _selectedStatus = 'All';
                            });
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Clear All',
                            style: TextStyle(color: Colors.deepPurple[500]),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Duration Section
                  Text(
                    'Duration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durationFilters.map((duration) {
                      final isSelected = _selectedDuration == duration;
                      return FilterChip(
                        label: Text(duration),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {});
                          setState(() {
                            _selectedDuration = selected ? duration : 'All';
                          });
                        },
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        selectedColor: Colors.deepPurple[50],
                        checkmarkColor: Colors.deepPurple[700],
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.deepPurple[700] : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? Colors.deepPurple[300]! : Colors.grey[300]!,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Status Section
                  Text(
                    'Project Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {'value': 'All', 'label': 'All', 'color': Colors.deepPurple},
                      {'value': 'recruiting', 'label': 'Recruiting', 'color': Colors.deepPurple},
                      {'value': 'in_progress', 'label': 'In Progress', 'color': Colors.orange},
                      {'value': 'completed', 'label': 'Completed', 'color': Colors.green},
                    ].map((item) {
                      final value = item['value'] as String;
                      final label = item['label'] as String;
                      final color = item['color'] as MaterialColor;
                      final isSelected = _selectedStatus == value;
                      return FilterChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          setSheetState(() {});
                          setState(() {
                            _selectedStatus = selected ? value : 'All';
                          });
                        },
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        selectedColor: color[50],
                        checkmarkColor: color[700],
                        labelStyle: TextStyle(
                          color: isSelected ? color[700] : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? color[300]! : Colors.grey[300]!,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple[500],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
      appBar: AppBar(
        title: const Text('Discover Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Users',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const UserSearchPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Saved Projects',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedProjectsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar with Filter Icon
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                _buildFilterButton(isDark),
              ],
            ),
          ),
          // Active filter chips
          if (_selectedDuration != 'All' || _selectedStatus != 'All')
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
              child: Row(
                children: [
                  if (_selectedDuration != 'All')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          _selectedDuration,
                          style: TextStyle(fontSize: 12, color: Colors.deepPurple[700]),
                        ),
                        backgroundColor: Colors.deepPurple[50],
                        deleteIcon: Icon(Icons.close, size: 16, color: Colors.deepPurple[700]),
                        onDeleted: () {
                          setState(() {
                            _selectedDuration = 'All';
                          });
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.deepPurple[200]!),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  if (_selectedStatus != 'All')
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Builder(
                        builder: (context) {
                          final Map<String, Map<String, dynamic>> statusConfig = {
                            'recruiting': {'label': 'Recruiting', 'color': Colors.deepPurple},
                            'in_progress': {'label': 'In Progress', 'color': Colors.orange},
                            'completed': {'label': 'Completed', 'color': Colors.green},
                          };
                          final config = statusConfig[_selectedStatus] ?? statusConfig['recruiting']!;
                          final MaterialColor color = config['color'] as MaterialColor;
                          final String label = config['label'] as String;
                          return Chip(
                            label: Text(
                              label,
                              style: TextStyle(fontSize: 12, color: color[700]),
                            ),
                            backgroundColor: color[50],
                            deleteIcon: Icon(Icons.close, size: 16, color: color[700]),
                            onDeleted: () {
                              setState(() {
                                _selectedStatus = 'All';
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: color[200]!),
                            ),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),

          // Projects List
          Expanded(
            child: _buildProjectsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: Colors.deepPurple[500]),
      );
    }

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Apply client-side filters
    final filteredProjects = _projects.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['uid'] == currentUserId) return false;
      if (!_matchesSearchQuery(data)) return false;
      if (_selectedDuration != 'All') {
        final duration = data['duration'] as String?;
        if (!_matchesDurationFilter(duration)) return false;
      }
      if (_selectedStatus != 'All') {
        final status = data['status'] as String? ?? 'recruiting';
        if (status != _selectedStatus) return false;
      }
      return true;
    }).toList();

    if (filteredProjects.isEmpty) {
      String emptyMessage;
      String emptySubtitle;

      if (_searchQuery.isNotEmpty) {
        emptyMessage = 'No projects found for "$_searchQuery"';
        emptySubtitle = 'Try a different search term';
      } else if (_selectedDuration != 'All') {
        emptyMessage = 'No projects with $_selectedDuration duration';
        emptySubtitle = 'Try a different duration filter';
      } else {
        emptyMessage = 'No projects yet';
        emptySubtitle = 'Check back later for new projects!';
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
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
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProjects,
      color: Colors.deepPurple[500],
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredProjects.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filteredProjects.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final project =
              filteredProjects[index].data() as Map<String, dynamic>;
          final projectId = filteredProjects[index].id;
          return _ProjectFeedCard(
            project: project,
            projectId: projectId,
            projectService: _projectService,
          );
        },
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
    final status = widget.project['status'] as String? ?? 'recruiting';

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

              // Project Title and Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.project['title'] ?? 'Untitled Project',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(status),
                ],
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
