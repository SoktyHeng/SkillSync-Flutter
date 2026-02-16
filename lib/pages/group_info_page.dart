import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/user_profile.dart';
import 'package:skillsync_sp2/services/group_chat_service.dart';

class GroupInfoPage extends StatefulWidget {
  final String groupChatId;

  const GroupInfoPage({
    super.key,
    required this.groupChatId,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final GroupChatService _groupChatService = GroupChatService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _groupName = '';
  String _creatorId = '';
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  bool get _isCreator => _currentUserId == _creatorId;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final doc = await _firestore
          .collection('group_chats')
          .doc(widget.groupChatId)
          .get();

      if (!doc.exists) return;

      final data = doc.data()!;
      _groupName = data['name'] ?? '';
      _creatorId = data['creatorId'] ?? '';

      final members =
          await _groupChatService.getMembers(widget.groupChatId);

      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading group info: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editGroupName() async {
    final controller = TextEditingController(text: _groupName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter group name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _groupName) {
      try {
        await _groupChatService.updateGroupName(
            widget.groupChatId, newName);
        setState(() => _groupName = newName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    }
  }

  Future<void> _removeMember(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Remove $userName from the group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupChatService.removeMember(widget.groupChatId, userId);
        await _loadGroupInfo();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text(
            'Are you sure you want to leave this group? You will no longer receive messages.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupChatService.leaveGroup(widget.groupChatId);
        if (mounted) Navigator.pop(context, 'left');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text(
            'Are you sure you want to delete this group? All messages will be lost. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _groupChatService.deleteGroupChat(widget.groupChatId);
        if (mounted) Navigator.pop(context, 'deleted');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Group Info'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: Colors.deepPurple[500]))
          : ListView(
              children: [
                // Group Header
                Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.deepPurple[100],
                        child: Icon(Icons.group,
                            color: Colors.deepPurple[400], size: 40),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _groupName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (_isCreator)
                            IconButton(
                              icon: Icon(Icons.edit,
                                  size: 20, color: Colors.deepPurple[400]),
                              onPressed: _editGroupName,
                            ),
                        ],
                      ),
                      Text(
                        '${_members.length} member${_members.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Members Section
                Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Members',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      ..._members.map((member) {
                        final isOwner = member['uid'] == _creatorId;
                        final isSelf = member['uid'] == _currentUserId;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple[100],
                            backgroundImage: member['profileImageUrl'] != null
                                ? NetworkImage(member['profileImageUrl'])
                                : null,
                            child: member['profileImageUrl'] == null
                                ? Icon(Icons.person,
                                    color: Colors.deepPurple[400])
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (isOwner)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Owner',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.deepPurple[400],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              if (isSelf)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: _isCreator && !isSelf
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  onPressed: () => _removeMember(
                                      member['uid'], member['name']),
                                )
                              : null,
                          onTap: isSelf
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserProfilePage(
                                          userId: member['uid']),
                                    ),
                                  );
                                },
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Actions
                Container(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  child: Column(
                    children: [
                      if (!_isCreator)
                        ListTile(
                          leading:
                              const Icon(Icons.exit_to_app, color: Colors.red),
                          title: const Text(
                            'Leave Group',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: _leaveGroup,
                        ),
                      if (_isCreator)
                        ListTile(
                          leading:
                              const Icon(Icons.delete, color: Colors.red),
                          title: const Text(
                            'Delete Group',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: _deleteGroup,
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
