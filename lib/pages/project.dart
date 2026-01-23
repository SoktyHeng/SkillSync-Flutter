import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/project_creation.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class ProjectPage extends StatefulWidget {
  const ProjectPage({super.key});

  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  final ProjectService _projectService = ProjectService();
  final user = FirebaseAuth.instance.currentUser!;



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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Projects'),
        backgroundColor: Colors.white,
        elevation: 0,
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
      ),
      body: StreamBuilder<QuerySnapshot>(
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
              final isOwner = project['uid'] == user.uid;

              return _ProjectCard(
                project: project,
                projectId: projectId,
                isOwner: isOwner,
                getTimeAgo: _getTimeAgo,
                projectService: _projectService,
                onDelete: () {
                  _showDeleteConfirmation(projectId);
                },
              );
            },
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
  final VoidCallback onDelete;

  const _ProjectCard({
    required this.project,
    required this.projectId,
    required this.isOwner,
    required this.getTimeAgo,
    required this.projectService,
    required this.onDelete,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  String _posterName = '';

  @override
  void initState() {
    super.initState();
    _loadPosterName();
  }

  Future<void> _loadPosterName() async {
    final name = await widget.projectService.getUserName(widget.project['uid']);
    if (mounted) {
      setState(() {
        _posterName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final lookingFor = List<String>.from(widget.project['lookingFor'] ?? []);
    final duration = widget.project['duration'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      color: Colors.white,
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
                  widget.getTimeAgo(widget.project['createdAt'] as Timestamp?),
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
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      tech,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.grey[600],
                  ),
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

            // Footer with poster name and action button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Posted by ',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Text(
                      _posterName.isNotEmpty ? _posterName : 'Loading...',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (widget.isOwner)
                  IconButton(
                    onPressed: widget.onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red[400],
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Application feature coming soon!',
                          ),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple[500],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Apply to Join',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
