import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/project_detail.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class SavedProjectsPage extends StatefulWidget {
  const SavedProjectsPage({super.key});

  @override
  State<SavedProjectsPage> createState() => _SavedProjectsPageState();
}

class _SavedProjectsPageState extends State<SavedProjectsPage> {
  final ProjectService _projectService = ProjectService();
  List<Map<String, dynamic>> _savedProjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedProjects();
  }

  Future<void> _loadSavedProjects() async {
    setState(() => _isLoading = true);
    final projects = await _projectService.getBookmarkedProjects();
    if (mounted) {
      setState(() {
        _savedProjects = projects;
        _isLoading = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(title: const Text('Saved Projects')),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple[500],
              ),
            )
          : _savedProjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved projects yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bookmark projects from the feed to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedProjects,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _savedProjects.length,
                    itemBuilder: (context, index) {
                      final project = _savedProjects[index];
                      final projectId = project['projectId'] as String;
                      return _SavedProjectCard(
                        project: project,
                        projectId: projectId,
                        projectService: _projectService,
                        getTimeAgo: _getTimeAgo,
                        onRemoved: _loadSavedProjects,
                      );
                    },
                  ),
                ),
    );
  }
}

class _SavedProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final String projectId;
  final ProjectService projectService;
  final String Function(Timestamp?) getTimeAgo;
  final VoidCallback onRemoved;

  const _SavedProjectCard({
    required this.project,
    required this.projectId,
    required this.projectService,
    required this.getTimeAgo,
    required this.onRemoved,
  });

  @override
  State<_SavedProjectCard> createState() => _SavedProjectCardState();
}

class _SavedProjectCardState extends State<_SavedProjectCard> {
  String _creatorName = '';
  String? _creatorImageUrl;
  bool _isLoadingCreator = true;

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
        _isLoadingCreator = false;
      });
    }
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

  Future<void> _removeBookmark() async {
    await widget.projectService.toggleBookmark(widget.projectId);
    if (mounted) {
      widget.onRemoved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);
    final status = widget.project['status'] as String? ?? 'recruiting';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetail(
              project: widget.project,
              projectId: widget.projectId,
            ),
          ),
        );
        // Refresh list when returning (project may have been unbookmarked)
        widget.onRemoved();
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.deepPurple[100],
                    backgroundImage: _creatorImageUrl != null
                        ? NetworkImage(_creatorImageUrl!)
                        : null,
                    child: _isLoadingCreator
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
                  Expanded(
                    child: Text(
                      _creatorName.isNotEmpty ? _creatorName : 'Loading...',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    widget.getTimeAgo(
                      widget.project['createdAt'] as Timestamp?,
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.bookmark,
                      color: Colors.deepPurple[500],
                      size: 22,
                    ),
                    onPressed: _removeBookmark,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove from saved',
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
              if (lookingFor.isNotEmpty)
                Text(
                  'Looking for: ${lookingFor.join(", ")}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
