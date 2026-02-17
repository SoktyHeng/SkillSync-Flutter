import 'dart:io';

import 'package:any_link_preview/any_link_preview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skillsync_sp2/pages/group_info_page.dart';
import 'package:skillsync_sp2/services/group_chat_service.dart';
import 'package:skillsync_sp2/services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupChatPage extends StatefulWidget {
  final String groupChatId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.groupChatId,
    required this.groupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final GroupChatService _groupChatService = GroupChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isSending = false;
  bool _isUploadingImage = false;
  late String _groupName;

  // Pagination state for older messages
  final List<DocumentSnapshot> _olderMessages = [];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;
  DocumentSnapshot? _oldestStreamDoc;

  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>\"]+',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _groupName = widget.groupName;
    NotificationService().setActiveConversation(widget.groupChatId);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    NotificationService().clearActiveConversation();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingOlder &&
        _hasMoreOlder) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlder) return;

    final DocumentSnapshot? oldestDoc =
        _olderMessages.isNotEmpty ? _olderMessages.last : _oldestStreamDoc;
    if (oldestDoc == null) return;

    setState(() => _isLoadingOlder = true);

    try {
      final snapshot = await _groupChatService.getOlderMessages(
        widget.groupChatId,
        lastDoc: oldestDoc,
      );
      setState(() {
        _olderMessages.addAll(snapshot.docs);
        _hasMoreOlder = snapshot.docs.length >= 30;
        _isLoadingOlder = false;
      });
    } catch (e) {
      setState(() => _isLoadingOlder = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _groupChatService.sendMessage(
        groupChatId: widget.groupChatId,
        text: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: ${e.toString()}'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);

      await _groupChatService.sendImageMessage(
        groupChatId: widget.groupChatId,
        imageFile: File(pickedFile.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending image: ${e.toString()}'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.deepPurple[500]),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.deepPurple[500]),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  String? _extractFirstUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}';
    }
  }

  Widget _buildDateHeader(String label) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : Colors.grey[50],
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupInfoPage(
                  groupChatId: widget.groupChatId,
                ),
              ),
            );
            if (!mounted) return;
            if (result is String && result != 'left' && result != 'deleted') {
              setState(() => _groupName = result);
            } else if (result == 'left' || result == 'deleted') {
              Navigator.pop(context);
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.deepPurple[100],
                child:
                    Icon(Icons.group, color: Colors.deepPurple[400], size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _groupName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          // Upload progress indicator
          if (_isUploadingImage)
            LinearProgressIndicator(
              backgroundColor: Colors.deepPurple[100],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple[500]!),
            ),

          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  _groupChatService.getMessages(widget.groupChatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _olderMessages.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: Colors.deepPurple[500]),
                  );
                }

                final streamDocs = snapshot.data?.docs ?? [];

                if (streamDocs.isNotEmpty) {
                  _oldestStreamDoc = streamDocs.last;
                }

                final allDocs = [...streamDocs, ..._olderMessages];

                if (allDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style:
                              TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style:
                              TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  );
                }

                final totalCount =
                    allDocs.length + (_isLoadingOlder ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: totalCount,
                  itemBuilder: (context, index) {
                    if (index >= allDocs.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final message =
                        allDocs[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUserId;

                    // Date header logic for reversed list
                    bool showDateHeader = index == allDocs.length - 1;
                    if (!showDateHeader && index < allDocs.length - 1) {
                      final currentTime =
                          message['createdAt'] as Timestamp?;
                      final olderMessage =
                          allDocs[index + 1].data() as Map<String, dynamic>;
                      final olderTime =
                          olderMessage['createdAt'] as Timestamp?;
                      if (currentTime != null && olderTime != null) {
                        final currentDate = currentTime.toDate();
                        final olderDate = olderTime.toDate();
                        showDateHeader = DateTime(currentDate.year,
                                currentDate.month, currentDate.day) !=
                            DateTime(olderDate.year, olderDate.month,
                                olderDate.day);
                      } else if (currentTime != null) {
                        showDateHeader = true;
                      }
                    }

                    // Show sender name when different from next message (older)
                    final showSenderName = !isMe &&
                        (index == allDocs.length - 1 ||
                            (allDocs[index + 1].data()
                                    as Map<String, dynamic>)['senderId'] !=
                                message['senderId'] ||
                            showDateHeader);

                    final timestamp = message['createdAt'] as Timestamp?;
                    final dateLabel = timestamp != null
                        ? _getDateLabel(timestamp.toDate())
                        : '';

                    return Column(
                      children: [
                        _buildMessageBubble(message, isMe, showSenderName),
                        if (showDateHeader && dateLabel.isNotEmpty)
                          _buildDateHeader(dateLabel),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Message Input
          _buildMessageInput(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> message, bool isMe, bool showSenderName) {
    final timestamp = message['createdAt'] as Timestamp?;
    final timeString = _formatTime(timestamp);
    final senderName = message['senderName'] as String? ?? 'Unknown';
    final messageType = message['type'] as String? ?? 'text';
    final imageUrl = message['imageUrl'] as String?;
    final text = message['text'] as String? ?? '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.deepPurple[500] : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
                child: Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isMe ? Colors.white70 : Colors.deepPurple[400],
                  ),
                ),
              ),

            // Image content
            if (messageType == 'image' && imageUrl != null)
              GestureDetector(
                onTap: () => _openFullScreenImage(imageUrl),
                child: Padding(
                  padding: EdgeInsets.only(top: showSenderName ? 4 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(showSenderName ? 0 : 16),
                      topRight: Radius.circular(showSenderName ? 0 : 16),
                    ),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: isMe ? Colors.white : Colors.deepPurple[500],
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 200,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image,
                          color: isMe ? Colors.white70 : Colors.grey[400],
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Text content
            if (messageType == 'text' || (messageType != 'image' && text.isNotEmpty))
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: showSenderName ? 4 : 10,
                  bottom: 0,
                ),
                child: _buildTextWithLinks(text, isMe),
              ),

            // Link preview
            if (messageType == 'text' && _extractFirstUrl(text) != null)
              _buildLinkPreview(_extractFirstUrl(text)!, isMe),

            // Timestamp
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 8,
                top: messageType == 'image' && text.isEmpty ? 8 : 4,
              ),
              child: Text(
                timeString,
                style: TextStyle(
                  fontSize: 11,
                  color: isMe ? Colors.white70 : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextWithLinks(String text, bool isMe) {
    final matches = _urlRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : Colors.grey[800],
        ),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(
            fontSize: 15,
            color: isMe ? Colors.white : Colors.grey[800],
          ),
        ));
      }

      final url = match.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _launchUrl(url),
          child: Text(
            url,
            style: TextStyle(
              fontSize: 15,
              color: isMe ? Colors.white : Colors.deepPurple[700],
              decoration: TextDecoration.underline,
              decorationColor: isMe ? Colors.white : Colors.deepPurple[700],
            ),
          ),
        ),
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(
          fontSize: 15,
          color: isMe ? Colors.white : Colors.grey[800],
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildLinkPreview(String url, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AnyLinkPreview(
          link: url,
          displayDirection: UIDirection.uiDirectionVertical,
          bodyMaxLines: 3,
          bodyTextOverflow: TextOverflow.ellipsis,
          titleStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isMe ? Colors.white : Colors.grey[800],
          ),
          bodyStyle: TextStyle(
            fontSize: 12,
            color: isMe ? Colors.white70 : Colors.grey[600],
          ),
          backgroundColor: isMe
              ? Colors.deepPurple[600]!
              : Theme.of(context).cardColor,
          borderRadius: 8,
          boxShadow: const [],
          errorBody: '',
          errorTitle: '',
          errorWidget: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildMessageInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            IconButton(
              onPressed: _isUploadingImage ? null : _showImagePickerSheet,
              icon: Icon(
                Icons.attach_file,
                color: _isUploadingImage
                    ? Colors.grey[400]
                    : Colors.deepPurple[500],
              ),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.deepPurple[500],
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
