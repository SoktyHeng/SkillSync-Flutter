import 'package:flutter/material.dart';
import 'package:skillsync_sp2/pages/home.dart';
import 'package:skillsync_sp2/pages/message.dart';
import 'package:skillsync_sp2/pages/profile.dart';
import 'package:skillsync_sp2/pages/project.dart';
import 'package:skillsync_sp2/services/notification_service.dart';

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  int _selectedIndex = 0;
  final NotificationService _notificationService = NotificationService();

  void _navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  final List<Widget> _pages = [
    HomePage(),
    MessagePage(),
    ProjectPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: StreamBuilder<int>(
        stream: _notificationService.getUnreadCount(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          return BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _navigateBottomBar,
            type: BottomNavigationBarType.fixed,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.message),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.file_copy_outlined),
                label: 'Projects',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(fontSize: 10),
                  ),
                  child: const Icon(Icons.person),
                ),
                label: 'Profile',
              ),
            ],
          );
        },
      ),
    );
  }
}
