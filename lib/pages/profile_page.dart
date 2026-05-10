import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'user_list_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  String _displayName = '';
  String _username = '';
  String _photoUrl = '';
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

  Future<void> _loadProfileData() async {
    if (_effectiveUserId.isEmpty) return;

    // Load basic info
    final profile = await _authService.getUserProfile(_effectiveUserId);
    if (mounted) {
      setState(() {
        _displayName = profile?['fullName'] ?? 'Traveller';
        _username = profile?['username'] ?? 'traveller';
        _photoUrl = profile?['photoUrl'] ?? '';
        _followerCount = profile?['followerCount'] ?? 0;
        _followingCount = profile?['followingCount'] ?? 0;
        _isLoading = false;
      });
    }

    if (!_isMe) {
      _authService.isFollowing(_effectiveUserId).listen((isFollowing) {
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

    final countries = <String>{};
    final cities = <String>{};

    for (var doc in blogsQuery.docs) {
      final data = doc.data();
      if (data['country'] != null) countries.add(data['country']);
      if (data['city'] != null) cities.add(data['city']);
    }

    if (mounted) {
      setState(() {
        _countryCount = countries.length;
        _cityCount = cities.length;
      });
    }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isMe)
            IconButton(
              icon: Icon(Icons.settings_outlined, color: textColor),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
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
                  _buildStatItem('Countries', _countryCount.toString(), textColor),
                  _buildStatItem('Cities', _cityCount.toString(), textColor),
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
            return Container(
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
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
