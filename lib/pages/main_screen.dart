import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_page.dart';
import 'discover_page.dart';
import 'map_explore_page.dart';
import 'blog_page.dart';
import 'documents_page.dart';
import 'profile_page.dart';

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
    BlogPage(),
    DocumentsPage(),
    ProfilePage(),
  ];

  static const _sunset = Color(0xFFFF6B6B);

  static const _icons = <List<IconData>>[
    [Icons.home_rounded, Icons.home_outlined],
    [Icons.explore_rounded, Icons.explore_outlined],
    [Icons.map_rounded, Icons.map_outlined],
    [Icons.edit_note_rounded, Icons.edit_note_outlined],
    [Icons.folder_rounded, Icons.folder_open_rounded],
    [Icons.person_rounded, Icons.person_outline_rounded],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.only(top: 12, bottom: 24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1D26).withAlpha(140)
                  : Colors.white.withAlpha(140),
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_icons.length, (i) {
                final isActive = _currentIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: isActive ? 50 : 42,
                        height: isActive ? 50 : 42,
                        decoration: BoxDecoration(
                          color: isActive ? _sunset : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: isActive
                              ? [BoxShadow(color: _sunset.withAlpha(60), blurRadius: 12, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: Icon(
                          isActive ? _icons[i][0] : _icons[i][1],
                          color: isActive ? Colors.white : inactiveColor,
                          size: isActive ? 24 : 22,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
