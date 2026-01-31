import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/chat_page.dart';
import 'package:skillsync_sp2/services/chat_service.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Conversations List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
        stream: _chatService.getConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: Colors.deepPurple[500]),
            );
          }

          if (snapshot.hasError) {
            debugPrint('Conversation error: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading conversations',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your internet connection',
                      style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final conversationDocs = snapshot.data?.docs ?? [];

          // Sort conversations by lastMessageTime (newest first)
          final conversations = conversationDocs.toList()
            ..sort((a, b) {
              final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime']
                  as Timestamp?;
              final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime']
                  as Timestamp?;
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;
              return bTime.compareTo(aTime);
            });

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a conversation from a user profile!',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _ConversationTile(
                conversationId: conversation.id,
                conversationData: conversation.data() as Map<String, dynamic>,
                chatService: _chatService,
                searchQuery: _searchQuery,
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

class _ConversationTile extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> conversationData;
  final ChatService chatService;
  final String searchQuery;

  const _ConversationTile({
    required this.conversationId,
    required this.conversationData,
    required this.chatService,
    required this.searchQuery,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  String _otherUserId = '';
  String _otherUserName = '';
  String? _otherUserImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOtherUserInfo();
  }

  Future<void> _loadOtherUserInfo() async {
    final info =
        await widget.chatService.getOtherParticipantInfo(widget.conversationId);
    if (mounted) {
      setState(() {
        _otherUserId = info['uid'] ?? '';
        _otherUserName = info['name'] ?? 'Unknown User';
        _otherUserImageUrl = info['profileImageUrl'];
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
      return '${date.day}/${date.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Now';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter by search query
    if (widget.searchQuery.isNotEmpty &&
        !_otherUserName.toLowerCase().contains(widget.searchQuery)) {
      return const SizedBox.shrink();
    }

    final lastMessage = widget.conversationData['lastMessage'] ?? '';
    final lastMessageTime =
        widget.conversationData['lastMessageTime'] as Timestamp?;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.deepPurple[100],
        backgroundImage: _otherUserImageUrl != null
            ? NetworkImage(_otherUserImageUrl!)
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
            : _otherUserImageUrl == null
                ? Icon(Icons.person, color: Colors.deepPurple[400], size: 28)
                : null,
      ),
      title: Text(
        _otherUserName.isNotEmpty ? _otherUserName : 'Loading...',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          lastMessage.isNotEmpty ? lastMessage : 'No messages yet',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      trailing: Text(
        _getTimeAgo(lastMessageTime),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[500],
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: widget.conversationId,
              otherUserId: _otherUserId,
              otherUserName: _otherUserName,
              otherUserImageUrl: _otherUserImageUrl,
            ),
          ),
        );
      },
    );
  }
}
