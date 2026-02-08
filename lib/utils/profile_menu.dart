import 'package:flutter/material.dart';

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({
    super.key,
    required this.text,
    required this.icon,
    this.press,
    this.badgeCount,
  });

  final String text;
  final IconData icon;
  final VoidCallback? press;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextButton(
        onPressed: press,
        style: TextButton.styleFrom(
          foregroundColor: Colors.deepPurple[500],
          padding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F6F9),
        ),
        child: Row(
          children: [
            Badge(
              isLabelVisible: badgeCount != null && badgeCount! > 0,
              label: Text(
                badgeCount != null && badgeCount! > 99
                    ? '99+'
                    : '${badgeCount ?? 0}',
                style: const TextStyle(fontSize: 10),
              ),
              child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: isDark ? Colors.grey[400] : const Color(0xFF757575)),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: isDark ? Colors.grey[400] : const Color(0xFF757575)),
          ],
        ),
      ),
    );
  }
}
