import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page.dart';
import 'discover_page.dart';
import 'map_explore_page.dart';
import 'saved_trips_page.dart';
import 'documents_page.dart';
import 'settings_page.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  static const _pages = <Widget>[
    HomePage(),
    DiscoverPage(),
    MapExplorePage(),
    SavedTripsPage(),
    DocumentsPage(),
    SettingsPage(),
  ];

  static const _sunset = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1D26) : Colors.white;
    final inactiveColor = isDark ? Colors.white38 : const Color(0xFFB0B5C0);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 60 : 20),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', inactiveColor),
              _buildNavItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Discover', inactiveColor),
              _buildNavItem(2, Icons.map_rounded, Icons.map_outlined, 'Map', inactiveColor),
              _buildNavItem(3, Icons.bookmark_rounded, Icons.bookmark_border_rounded, 'Saved', inactiveColor),
              _buildNavItem(4, Icons.folder_rounded, Icons.folder_open_rounded, 'Files', inactiveColor),
              _buildNavItem(5, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', inactiveColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, Color inactiveColor) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 12 : 8,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? _sunset.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? _sunset : inactiveColor,
              size: 22,
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: _sunset,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
