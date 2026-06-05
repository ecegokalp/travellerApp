import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'user_list_page.dart';
import 'settings_page.dart';
import 'saved_stories_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  StreamSubscription? _followingSub;
  String _displayName = '';
  String _username = '';
  String _photoUrl = '';
  String _bio = '';
  final Set<String> _blogCountries = {};
  final Set<String> _blogCities = {};
  List<String> _manualCountries = [];
  List<String> _manualCities = [];
  int _countryCount = 0;
  int _cityCount = 0;
  int _followerCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  bool _isLoading = true;

  String get _effectiveUserId => widget.userId ?? _authService.currentUser?.uid ?? '';
  bool get _isMe => _effectiveUserId == _authService.currentUser?.uid;

  static const _accent = Color(0xFFFF6B6B);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _followingSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (_effectiveUserId.isEmpty) return;

    // Load basic info
    final profile = await _authService.getUserProfile(_effectiveUserId);
    if (mounted) {
      setState(() {
        _displayName = profile?['fullName'] ?? 'Traveller';
        _username = profile?['username'] ?? 'traveller';
        _photoUrl = profile?['photoUrl'] ?? '';
        _bio = profile?['bio'] ?? '';
        _manualCountries = List<String>.from(profile?['visitedCountries'] ?? const []);
        _manualCities = List<String>.from(profile?['visitedCities'] ?? const []);
        _followerCount = profile?['followerCount'] ?? 0;
        _followingCount = profile?['followingCount'] ?? 0;
        _isLoading = false;
      });
    }

    if (!_isMe) {
      _followingSub?.cancel();
      _followingSub = _authService.isFollowing(_effectiveUserId).listen((isFollowing) {
        if (mounted) {
          setState(() {
            _isFollowing = isFollowing;
          });
        }
      });
    }

    // Load stats from blogs
    final blogsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(_effectiveUserId)
        .collection('blogs')
        .get();

    _blogCountries.clear();
    _blogCities.clear();
    for (var doc in blogsQuery.docs) {
      final data = doc.data();
      if (data['country'] != null && (data['country'] as String).isNotEmpty) _blogCountries.add(data['country']);
      if (data['city'] != null && (data['city'] as String).isNotEmpty) _blogCities.add(data['city']);
    }

    if (mounted) setState(_recountStats);
  }

  void _recountStats() {
    _countryCount = {..._blogCountries, ..._manualCountries}.length;
    _cityCount = {..._blogCities, ..._manualCities}.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          if (_isMe) ...[
            IconButton(
              icon: Icon(Icons.bookmark_rounded, color: textColor),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedStoriesPage()));
              },
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: textColor),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_accent, Color(0xFFFF8E53)]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: _accent.withAlpha(50), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                      image: _photoUrl.isNotEmpty 
                          ? DecorationImage(image: NetworkImage(_photoUrl), fit: BoxFit.cover) 
                          : null,
                    ),
                    child: _photoUrl.isEmpty ? Center(
                      child: Text(
                        _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'T',
                        style: GoogleFonts.playfairDisplay(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(_displayName, style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  Text('@$_username', style: GoogleFonts.inter(color: _warmGray, fontSize: 14)),
                  if (_bio.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _accent.withAlpha(isDark ? 24 : 14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_bio, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : _darkText, height: 1.45)),
                    ),
                  ],
                  if (_isMe) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _editBio,
                      icon: Icon(_bio.isEmpty ? Icons.add_rounded : Icons.edit_outlined, size: 16),
                      label: Text(_bio.isEmpty ? 'Add Bio' : 'Edit Bio', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _accent,
                        side: const BorderSide(color: _accent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                      ),
                    ),
                  ],
                  if (!_isMe) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (_isFollowing) {
                          await _authService.unfollowUser(_effectiveUserId);
                        } else {
                          await _authService.followUser(_effectiveUserId);
                        }
                        // Refresh data
                        _loadProfileData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? Colors.grey[200] : _accent,
                        foregroundColor: _isFollowing ? Colors.black87 : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      ),
                      child: Text(_isFollowing ? 'Unfollow' : 'Follow', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => _openPlaces(isCountry: true),
                    child: _buildStatItem('Countries', _countryCount.toString(), textColor),
                  ),
                  GestureDetector(
                    onTap: () => _openPlaces(isCountry: false),
                    child: _buildStatItem('Cities', _cityCount.toString(), textColor),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListPage(
                          title: 'Followers',
                          userId: _effectiveUserId,
                          isFollowers: true,
                        ),
                      ),
                    ),
                    child: _buildStatItem(
                        'Followers',
                        _followerCount >= 1000
                            ? '${(_followerCount / 1000).toStringAsFixed(1)}k'
                            : _followerCount.toString(),
                        textColor),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserListPage(
                          title: 'Following',
                          userId: _effectiveUserId,
                          isFollowers: false,
                        ),
                      ),
                    ),
                    child: _buildStatItem('Following', _followingCount.toString(), textColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tabs/Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Travel Stories', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 16),
                  _buildBlogList(),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _editBio() {
    final controller = TextEditingController(text: _bio);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _darkText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final len = controller.text.length;
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.grey.withAlpha(60), borderRadius: BorderRadius.circular(3)))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text('Edit Bio', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 24, color: textColor)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(14) : Colors.grey.withAlpha(25), shape: BoxShape.circle),
                          child: Icon(Icons.close_rounded, size: 18, color: textColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('A short intro shown on your profile', style: GoogleFonts.inter(fontSize: 13, color: _warmGray)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFF6F3EE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: controller.text.isEmpty ? Colors.transparent : _accent.withAlpha(70), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextField(
                          controller: controller,
                          autofocus: true,
                          minLines: 4,
                          maxLines: 6,
                          maxLength: 150,
                          onChanged: (_) => setSheet(() {}),
                          style: GoogleFonts.inter(fontSize: 15, color: textColor, height: 1.5),
                          decoration: InputDecoration(
                            hintText: 'Share a little about your travel style, favourite places, or what you love exploring…',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: _warmGray.withAlpha(140), height: 1.5),
                            border: InputBorder.none,
                            isDense: true,
                            counterText: '',
                          ),
                        ),
                        Text('$len/150', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: len > 140 ? Colors.orange : _warmGray.withAlpha(160))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_accent, Color(0xFFFF8E53)]),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: _accent.withAlpha(70), blurRadius: 16, offset: const Offset(0, 8))],
                      ),
                      child: ElevatedButton(
                        onPressed: () async {
                          final text = controller.text.trim();
                          await _authService.updateBio(text);
                          if (mounted) setState(() => _bio = text);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openPlaces({required bool isCountry}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VisitedPlacesPage(
          isCountry: isCountry,
          field: isCountry ? 'visitedCountries' : 'visitedCities',
          blogPlaces: isCountry ? _blogCountries : _blogCities,
          initialManual: List<String>.from(isCountry ? _manualCountries : _manualCities),
          isMe: _isMe,
          authService: _authService,
        ),
      ),
    );
    _loadProfileData();
  }

  Widget _buildStatItem(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: _warmGray)),
      ],
    );
  }

  Widget _buildBlogList() {
    if (_effectiveUserId.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_effectiveUserId)
          .collection('blogs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text('No stories yet. Start blogging!', style: GoogleFonts.inter(color: _warmGray)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final blog = docs[index].data() as Map<String, dynamic>;
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _StoryDetailPage(
                    authorId: _effectiveUserId,
                    blogId: docs[index].id,
                    blog: blog,
                    authService: _authService,
                  ),
                ),
              ),
              child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (blog['imageUrl'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.network(
                        blog['imageUrl'],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: _accent),
                            const SizedBox(width: 4),
                            Text(
                              '${blog['city']}, ${blog['country']}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _accent, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          blog['content'] ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : _darkText, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.favorite_rounded, size: 16, color: _accent),
                            const SizedBox(width: 4),
                            Text('${blog['likeCount'] ?? 0}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _warmGray)),
                            const SizedBox(width: 16),
                            const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: _warmGray),
                            const SizedBox(width: 4),
                            Text('${blog['commentCount'] ?? 0}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _warmGray)),
                            const Spacer(),
                            Icon(Icons.chevron_right_rounded, size: 18, color: _warmGray.withAlpha(120)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
  }
}

class _VisitedPlacesPage extends StatefulWidget {
  final bool isCountry;
  final String field;
  final Set<String> blogPlaces;
  final List<String> initialManual;
  final bool isMe;
  final AuthService authService;

  const _VisitedPlacesPage({
    required this.isCountry,
    required this.field,
    required this.blogPlaces,
    required this.initialManual,
    required this.isMe,
    required this.authService,
  });

  @override
  State<_VisitedPlacesPage> createState() => _VisitedPlacesPageState();
}

class _VisitedPlacesPageState extends State<_VisitedPlacesPage> {
  static const _accent = Color(0xFFFF6B6B);
  static const _warmGray = Color(0xFF6B7280);

  late List<String> _manual;
  final _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _manual = List<String>.from(widget.initialManual);
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  List<String> get _names => (<String>{...widget.blogPlaces, ..._manual}).toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  Future<void> _addItem() async {
    final v = _addController.text.trim();
    if (v.isEmpty) return;
    if (!_manual.contains(v) && !widget.blogPlaces.contains(v)) {
      await widget.authService.addVisitedPlace(widget.field, v);
      setState(() => _manual.add(v));
    }
    _addController.clear();
  }

  Future<void> _removeItem(String v) async {
    await widget.authService.removeVisitedPlace(widget.field, v);
    setState(() => _manual.remove(v));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final title = widget.isCountry ? 'Countries' : 'Cities';
    final names = _names;

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (widget.isMe)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    style: GoogleFonts.inter(color: textColor),
                    onSubmitted: (_) => _addItem(),
                    decoration: InputDecoration(
                      hintText: widget.isCountry ? 'Add a country' : 'Add a city',
                      isDense: true,
                      filled: true,
                      fillColor: isDark ? Colors.white.withAlpha(12) : Colors.grey.withAlpha(20),
                      prefixIcon: Icon(widget.isCountry ? Icons.public_rounded : Icons.location_city_rounded, color: _accent, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _addItem,
                  child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.add, color: Colors.white, size: 22)),
                ),
              ]),
            ),
          Expanded(
            child: names.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.isCountry ? Icons.public_off_rounded : Icons.location_off_rounded, size: 48, color: _warmGray.withAlpha(120)),
                        const SizedBox(height: 12),
                        Text('No $title yet', style: GoogleFonts.inter(color: _warmGray)),
                        if (widget.isMe) ...[
                          const SizedBox(height: 4),
                          Text('Add the places you have visited', style: GoogleFonts.inter(fontSize: 12, color: _warmGray.withAlpha(160))),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: names.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.withAlpha(30)),
                    itemBuilder: (_, i) {
                      final name = names[i];
                      final fromBlog = widget.blogPlaces.contains(name);
                      final removable = widget.isMe && _manual.contains(name) && !fromBlog;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(widget.isCountry ? Icons.public_rounded : Icons.location_city_rounded, color: _accent, size: 24),
                        title: Text(name, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600)),
                        subtitle: fromBlog ? Text('from stories', style: GoogleFonts.inter(fontSize: 11, color: _warmGray)) : null,
                        trailing: removable
                            ? IconButton(icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20), onPressed: () => _removeItem(name))
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StoryDetailPage extends StatefulWidget {
  final String authorId;
  final String blogId;
  final Map<String, dynamic> blog;
  final AuthService authService;

  const _StoryDetailPage({
    required this.authorId,
    required this.blogId,
    required this.blog,
    required this.authService,
  });

  @override
  State<_StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<_StoryDetailPage> {
  static const _accent = Color(0xFFFF6B6B);
  static const _warmGray = Color(0xFF6B7280);

  late int _likeCount;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _likeCount = (widget.blog['likeCount'] ?? 0) as int;
    widget.authService.isLikedOnce(widget.authorId, widget.blogId).then((v) {
      if (mounted) setState(() => _liked = v);
    });
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    widget.authService.toggleLike(widget.authorId, widget.blogId);
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StoryCommentsSheet(authorId: widget.authorId, blogId: widget.blogId, authService: widget.authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final b = widget.blog;
    final images = (b['imageUrls'] as List?)?.cast<String>() ?? (b['imageUrl'] != null ? <String>[b['imageUrl'] as String] : <String>[]);
    final rating = (b['rating'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text(b['authorName'] ?? 'Story', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: textColor)),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          if (images.length == 1)
            Image.network(
              images.first,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, __, ___) => Container(height: 250, color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey)),
            )
          else if (images.length > 1)
            Container(
              height: 360,
              color: isDark ? Colors.black : const Color(0xFFF0ECE4),
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (_, i) => Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        images[i],
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey)),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                        child: Text('${i + 1}/${images.length}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: _accent),
                  const SizedBox(width: 4),
                  Expanded(child: Text('${b['city'] ?? ''}, ${b['country'] ?? ''}', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: _accent, fontSize: 14))),
                  if (rating > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Icon(i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded, size: 16, color: Colors.amber))),
                ]),
                const SizedBox(height: 16),
                Text(b['content'] ?? '', style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: isDark ? Colors.white70 : const Color(0xFF1F2937))),
                const SizedBox(height: 24),
                Row(children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Row(children: [
                      Icon(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _liked ? _accent : _warmGray, size: 24),
                      const SizedBox(width: 6),
                      Text('$_likeCount', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  GestureDetector(
                    onTap: _openComments,
                    child: Row(children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: _warmGray, size: 22),
                      const SizedBox(width: 6),
                      Text('${b['commentCount'] ?? 0}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: textColor)),
                    ]),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCommentsSheet extends StatefulWidget {
  final String authorId;
  final String blogId;
  final AuthService authService;

  const _StoryCommentsSheet({required this.authorId, required this.blogId, required this.authService});

  @override
  State<_StoryCommentsSheet> createState() => _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends State<_StoryCommentsSheet> {
  static const _accent = Color(0xFFFF6B6B);
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Comments', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.authService.getComments(widget.authorId, widget.blogId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return Center(child: Text('No comments yet.', style: GoogleFonts.inter(color: Colors.grey)));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final c = docs[i].data() as Map<String, dynamic>;
                    final name = (c['fullName'] as String?)?.isNotEmpty == true
                        ? c['fullName'] as String
                        : ((c['username'] as String?)?.isNotEmpty == true ? c['username'] as String : 'Traveller');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(backgroundColor: _accent.withAlpha(30), child: Text(name[0].toUpperCase(), style: const TextStyle(color: _accent))),
                      title: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(c['text'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Add a comment...',
                    filled: true,
                    fillColor: isDark ? Colors.white10 : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: _accent),
                onPressed: () {
                  if (_controller.text.trim().isEmpty) return;
                  widget.authService.addComment(widget.authorId, widget.blogId, _controller.text);
                  _controller.clear();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
