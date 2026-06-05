import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import 'details_page.dart';
import 'blog_page.dart';
import 'blog_card.dart';
import 'user_search_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final AuthService _authService = AuthService();

  static const _accent = Color(0xFFFF6B6B);
  static const _accentLight = Color(0xFFFF8E53);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  int _tab = 0; // 0 = Explore, 1 = Following
  List<String> _followingUids = [];
  StreamSubscription? _followSub;
 
  static const List<Map<String, String>> _popular = [
    {'title': 'Paris, France', 'subtitle': 'The city of love', 'image': 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?q=80&w=600', 'rating': '4.8', 'category': 'Cities'},
    {'title': 'Santorini, Greece', 'subtitle': 'Blue domes', 'image': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=600', 'rating': '5.0', 'category': 'Islands'},
    {'title': 'Petra, Jordan', 'subtitle': 'Ancient Rose City', 'image': 'https://images.unsplash.com/photo-1580834341580-8c17a3a630ca?q=80&w=600', 'rating': '4.9', 'category': 'History'},
    {'title': 'Maldives', 'subtitle': 'Crystal clear waters', 'image': 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?q=80&w=600', 'rating': '4.9', 'category': 'Beaches'},
    {'title': 'Swiss Alps', 'subtitle': 'Snowy peaks', 'image': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?q=80&w=600', 'rating': '4.7', 'category': 'Mountains'},
    {'title': 'Kyoto, Japan', 'subtitle': 'Timeless temples', 'image': 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?q=80&w=600', 'rating': '4.8', 'category': 'Cities'},
  ];

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    if (uid != null) {
      _followSub = _authService.getFollowingUids(uid).listen((uids) {
        if (mounted) setState(() => _followingUids = uids);
      });
    }
  }

  @override
  void dispose() {
    _followSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(textColor, isDark),
            _tabRow(textColor, isDark),
            Expanded(
              child: RefreshIndicator(
                color: _accent,
                onRefresh: () async {
                  setState(() {});
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: _content(isDark, textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Fixed top bar (stays while scrolling) ──
  Widget _topBar(Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Text('Wander Feed', style: GoogleFonts.playfairDisplay(fontSize: 30, fontWeight: FontWeight.w800, color: textColor)),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchPage())),
            child: Container(
              width: 46, height: 46,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(15) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
              ),
              child: Icon(Icons.search_rounded, color: textColor, size: 24),
            ),
          ),
          GestureDetector(
            onTap: () => showCreateStorySheet(context),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_accent, _accentLight]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: _accent.withAlpha(60), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 25),
            ),
          ),
        ],
      ),
    );
  }

  // ── Scrollable content ──
  Widget _content(bool isDark, Color textColor) {
    if (_tab == 1 && _followingUids.isEmpty) {
      return _scroll(isDark, textColor, _emptySliver(Icons.people_outline_rounded, 'Follow people to see their stories!'));
    }

    final stream = _tab == 0 ? _authService.getCommunityFeed() : _authService.getFollowingFeed(_followingUids);

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        Widget feed;
        if (snapshot.connectionState == ConnectionState.waiting) {
          feed = const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator(color: _accent))));
        } else {
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            feed = _emptySliver(Icons.auto_stories_outlined, _tab == 0 ? 'No stories yet.' : 'No stories from people you follow yet.');
          } else {
            feed = SliverList(
              delegate: SliverChildBuilderDelegate(
                (c, i) {
                  final blog = docs[i].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: BlogCard(blog: blog, blogId: docs[i].id, authService: _authService),
                  );
                },
                childCount: docs.length,
              ),
            );
          }
        }
        return _scroll(isDark, textColor, feed);
      },
    );
  }

  Widget _scroll(bool isDark, Color textColor, Widget feedSliver) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _popularSection(isDark, textColor)),
        feedSliver,
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  // ── Popular Places ──
  Widget _popularSection(bool isDark, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Popular Places', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.w700, color: textColor)),
              const Spacer(),
              Text('Top rated', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: _accent)),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _popular.length,
            itemBuilder: (context, i) => _popularCard(_popular[i], isDark),
          ),
        ),
      ],
    );
  }

  Widget _popularCard(Map<String, String> d, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DestinationDetailPage(destination: d))),
      child: Container(
        width: 165,
        margin: const EdgeInsets.only(right: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: d['image']!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200]),
                errorWidget: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined)),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                    colors: [Colors.transparent, Colors.black.withAlpha(170)],
                  ),
                ),
              ),
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withAlpha(120), borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(d['rating']!, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['category']!.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white70, letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text(d['title']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Explore / Following tabs (scroll with content) ──
  Widget _tabRow(Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [_tabItem('Explore', 0, isDark), _tabItem('Following', 1, isDark)]),
    );
  }

  Widget _tabItem(String label, int i, bool isDark) {
    final active = _tab == i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = i),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 15, fontWeight: active ? FontWeight.bold : FontWeight.w600, color: active ? _accent : _warmGray)),
            const SizedBox(height: 10),
            Container(height: 3, width: 56, decoration: BoxDecoration(color: active ? _accent : Colors.transparent, borderRadius: BorderRadius.circular(2))),
            Container(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
          ],
        ),
      ),
    );
  }

  Widget _emptySliver(IconData icon, String message) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 60, left: 24, right: 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: _warmGray.withAlpha(120)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _warmGray)),
          ],
        ),
      ),
    );
  }
}