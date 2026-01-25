import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/my_project_detail.dart';
import 'package:skillsync_sp2/pages/project_creation.dart';
import 'package:skillsync_sp2/pages/project_detail.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage>
    with SingleTickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
  final user = FirebaseAuth.instance.currentUser!;
  late TabController _tabController;
  List<Map<String, dynamic>> _contributingProjects = [];
  bool _isLoadingContributing = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadContributingProjects();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContributingProjects() async {
    final projects = await _projectService.getContributingProjects();
    if (mounted) {
      setState(() {
        _contributingProjects = projects;
        _isLoadingContributing = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProjectCreation(),
                  ),
                );
              },
              icon: Icon(
                Icons.add_circle_outline,
                color: Colors.deepPurple[500],
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.deepPurple[600],
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Colors.deepPurple[600],
          tabs: const [
            Tab(text: 'My Projects'),
            Tab(text: 'Contributing'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMyProjectsList(), _buildContributingProjectsList()],
      ),
    );
  }

  Widget _buildMyProjectsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _projectService.getMyProjects(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.deepPurple[500]),
          );
        }

        final projectDocs = snapshot.data?.docs ?? [];

        // Sort by createdAt descending (newest first)
        projectDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final projects = projectDocs;

        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No projects yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first project!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index].data() as Map<String, dynamic>;
            final projectId = projects[index].id;

            return _ProjectCard(
              project: project,
              projectId: projectId,
              isOwner: true,
              getTimeAgo: _getTimeAgo,
              projectService: _projectService,
              onDelete: () {
                _showDeleteConfirmation(projectId);
              },
              onRefresh: null,
            );
          },
        );
      },
    );
  }

  Widget _buildContributingProjectsList() {
    if (_isLoadingContributing) {
      return Center(
        child: CircularProgressIndicator(color: Colors.deepPurple[500]),
      );
    }

    if (_contributingProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No contributing projects',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Projects you contribute to will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadContributingProjects,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contributingProjects.length,
        itemBuilder: (context, index) {
          final project = _contributingProjects[index];
          final projectId = project['projectId'] as String;

          return _ProjectCard(
            project: project,
            projectId: projectId,
            isOwner: false,
            getTimeAgo: _getTimeAgo,
            projectService: _projectService,
            onDelete: null,
            onRefresh: _loadContributingProjects,
            isContributor: true,
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(String projectId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text('Delete Project'),
          content: const Text(
            'Are you sure you want to delete this project? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _projectService.deleteProject(projectId);
                  _showSnackBar('Project deleted successfully');
                } catch (e) {
                  _showSnackBar('Error deleting project: ${e.toString()}');
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends StatefulWidget {
  final Map<String, dynamic> project;
  final String projectId;
  final bool isOwner;
  final String Function(Timestamp?) getTimeAgo;
  final ProjectService projectService;
  final VoidCallback? onDelete;
  final VoidCallback? onRefresh;
  final bool isContributor;

  const _ProjectCard({
    required this.project,
    required this.projectId,
    required this.isOwner,
    required this.getTimeAgo,
    required this.projectService,
    this.onDelete,
    this.onRefresh,
    this.isContributor = false,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  int _contributorCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isOwner) {
      _loadContributorCount();
    }
  }

  Future<void> _loadContributorCount() async {
    widget.projectService.getContributors(widget.projectId).listen((snapshot) {
      if (mounted) {
        setState(() {
          _contributorCount = snapshot.docs.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);
    final duration = widget.project['duration'] as String?;

    return GestureDetector(
      onTap: () {
        if (widget.isOwner) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyProjectDetail(
                project: widget.project,
                projectId: widget.projectId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectDetail(
                project: widget.project,
                projectId: widget.projectId,
              ),
            ),
          );
        }
      },
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and time
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
                  Text(
                    widget.getTimeAgo(
                      widget.project['createdAt'] as Timestamp?,
                    ),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
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
              ),
              const SizedBox(height: 16),

              // Tech Stack
              if (techStack.isNotEmpty) ...[
                Text(
                  'Tech Stack:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: techStack.map((tech) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        tech,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Looking For
              if (lookingFor.isNotEmpty) ...[
                Text(
                  'Looking for:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lookingFor.map((role) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Text(
                        role,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Duration
              if (duration != null && duration.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Duration: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      duration,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.deepPurple[600],
                      ),
                    ),
                  ],
                ),
              ],

              const Divider(height: 32),

              // Footer with action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.isOwner)
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          size: 18,
                          color: Colors.deepPurple[400],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_contributorCount contributor${_contributorCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  else if (widget.isContributor)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Contributor',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(),
                  if (widget.isOwner && widget.onDelete != null)
                    IconButton(
                      onPressed: widget.onDelete,
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
