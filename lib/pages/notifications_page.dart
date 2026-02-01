import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skillsync_sp2/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              await _notificationService.markAllAsRead();
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<QueryDocumentSnapshot>>(
        stream: _notificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see project updates here',
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
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _NotificationTile(
                notificationId: doc.id,
                data: data,
                onDismissed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  await _notificationService.deleteNotification(doc.id);
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Notification deleted'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                onTap: () async {
                  if (data['isRead'] != true) {
                    await _notificationService.markAsRead(doc.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String notificationId;
  final Map<String, dynamic> data;
  final VoidCallback onDismissed;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notificationId,
    required this.data,
    required this.onDismissed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final isRead = data['isRead'] as bool? ?? false;
    final createdAt = data['createdAt'] as Timestamp?;

    // Get icon and color based on type
    final (IconData icon, Color color) = _getIconAndColor(type);

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: isRead ? null : Colors.blue.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getTimeAgo(createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Unread indicator
                if (!isRead)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (IconData, Color) _getIconAndColor(String type) {
    switch (type) {
      case 'request_received':
        return (Icons.person_add, Colors.orange);
      case 'request_accepted':
        return (Icons.check_circle, Colors.green);
      case 'request_rejected':
        return (Icons.cancel, Colors.red);
      default:
        return (Icons.notifications, Colors.blue);
    }
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
  }
}
