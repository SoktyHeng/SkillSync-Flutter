import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/user_profile.dart';
import 'package:skillsync_sp2/services/project_service.dart';

class MyProjectDetail extends StatefulWidget {
  final Map<String, dynamic> project;
  final String projectId;

  const MyProjectDetail({
    super.key,
    required this.project,
    required this.projectId,
  });

  @override
  State<MyProjectDetail> createState() => _MyProjectDetailState();
}

class _MyProjectDetailState extends State<MyProjectDetail>
    with SingleTickerProviderStateMixin {
  final ProjectService _projectService = ProjectService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await _projectService.acceptContributionRequest(
        widget.projectId,
        requestId,
      );
      _showSnackBar('Request accepted!');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await _projectService.rejectContributionRequest(
        widget.projectId,
        requestId,
      );
      _showSnackBar('Request rejected');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final techStack = List<String>.from(widget.project['techStack'] ?? []);
    final duration = widget.project['duration'] as String?;
    final description = widget.project['description'] ?? '';
    final title = widget.project['title'] ?? 'Untitled Project';

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? null
          : Colors.grey[50],
      appBar: AppBar(title: const Text('Project Details')),
      body: Column(
        children: [
          // Project Info Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                if (techStack.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: techStack.take(4).map((tech) {
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
                if (duration != null && duration.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        duration,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.deepPurple[600],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.deepPurple[600],
            tabs: const [
              Tab(text: 'Requests'),
              Tab(text: 'Contributors'),
            ],
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Pending Requests Tab
                _buildRequestsList(),
                // Contributors Tab
                _buildContributorsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _projectService.getContributionRequests(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.deepPurple[500]),
          );
        }

        final requests = snapshot.data?.docs ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'When someone requests to join,\nthey\'ll appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final requestData = request.data() as Map<String, dynamic>;
            final userId = requestData['userId'] as String;

            return _RequestCard(
              userId: userId,
              requestId: request.id,
              projectService: _projectService,
              onAccept: () => _acceptRequest(request.id),
              onReject: () => _rejectRequest(request.id),
            );
          },
        );
      },
    );
  }

  Widget _buildContributorsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _projectService.getContributors(widget.projectId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: Colors.deepPurple[500]),
          );
        }

        final contributors = snapshot.data?.docs ?? [];

        if (contributors.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No contributors yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Accept requests to add contributors\nto your project',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          // padding: const EdgeInsets.all(16),
          itemCount: contributors.length,
          itemBuilder: (context, index) {
            final contributor = contributors[index];
            final contributorData = contributor.data() as Map<String, dynamic>;
            final userId = contributorData['userId'] as String;

            return _ContributorCard(
              userId: userId,
              projectService: _projectService,
            );
          },
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  final String userId;
  final String requestId;
  final ProjectService projectService;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.userId,
    required this.requestId,
    required this.projectService,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  String _userName = '';
  String? _userImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await widget.projectService.getUserInfo(widget.userId);
    if (mounted) {
      setState(() {
        _userName = userInfo['name'] ?? 'Unknown User';
        _userImageUrl = userInfo['profileImageUrl'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Profile Picture
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        UserProfilePage(userId: widget.userId),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.deepPurple[100],
                backgroundImage: _userImageUrl != null
                    ? NetworkImage(_userImageUrl!)
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
                    : _userImageUrl == null
                    ? Icon(
                        Icons.person,
                        color: Colors.deepPurple[400],
                        size: 28,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            // Name
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UserProfilePage(userId: widget.userId),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wants to contribute',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Row(
              children: [
                IconButton(
                  onPressed: widget.onReject,
                  icon: Icon(Icons.close, color: Colors.red[400]),
                  style: IconButton.styleFrom(backgroundColor: Colors.red[50]),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onAccept,
                  icon: Icon(Icons.check, color: Colors.green[600]),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green[50],
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

class _ContributorCard extends StatefulWidget {
  final String userId;
  final ProjectService projectService;

  const _ContributorCard({required this.userId, required this.projectService});

  @override
  State<_ContributorCard> createState() => _ContributorCardState();
}

class _ContributorCardState extends State<_ContributorCard> {
  String _userName = '';
  String? _userImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await widget.projectService.getUserInfo(widget.userId);
    if (mounted) {
      setState(() {
        _userName = userInfo['name'] ?? 'Unknown User';
        _userImageUrl = userInfo['profileImageUrl'];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfilePage(userId: widget.userId),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.deepPurple[100],
          backgroundImage: _userImageUrl != null
              ? NetworkImage(_userImageUrl!)
              : null,
          child: _isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.deepPurple[300],
                  ),
                )
              : _userImageUrl == null
              ? Icon(Icons.person, color: Colors.deepPurple[400], size: 24)
              : null,
        ),
        title: Text(
          _userName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Contributor',
          style: TextStyle(fontSize: 13, color: Colors.green[600]),
        ),
        trailing: Icon(Icons.check_circle, color: Colors.green[500]),
      ),
    );
  }
}
