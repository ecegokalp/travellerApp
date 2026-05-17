import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';
import 'profile_page.dart';

class BlogPage extends StatefulWidget {
  final String? initialCountry;
  final String? initialCity;

  const BlogPage({super.key, this.initialCountry, this.initialCity});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  // Cache like/bookmark states to prevent repeated Firestore calls on every rebuild
  final Map<String, bool> _likeCache = {};
  final Map<String, bool> _bookmarkCache = {};

  static const _accent = Color(0xFFFF6B6B);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.initialCity != null || widget.initialCountry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreatePostSheet(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      appBar: AppBar(
        title: Text('Wander Feed', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _accent,
          unselectedLabelColor: _warmGray,
          indicatorColor: _accent,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(text: 'Explore'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeed(isGlobal: true),
          _buildFeed(isGlobal: false),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePostSheet(context),
        backgroundColor: _accent,
        icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
        label: Text('Share Story', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildFeed({required bool isGlobal}) {
    if (isGlobal) {
      return StreamBuilder<QuerySnapshot>(
        stream: _authService.getCommunityFeed(),
        builder: (context, snapshot) => _buildBlogListView(snapshot),
      );
    } else {
      return StreamBuilder<List<String>>(
        stream: _authService.getFollowingUids(_authService.currentUser?.uid ?? ''),
        builder: (context, uidsSnapshot) {
          if (uidsSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final uids = uidsSnapshot.data ?? [];

          if (uids.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline, size: 64, color: _warmGray),
                  const SizedBox(height: 16),
                  Text('Follow people to see their stories!', style: GoogleFonts.inter(color: _warmGray)),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _authService.getFollowingFeed(uids),
            builder: (context, snapshot) => _buildBlogListView(snapshot),
          );
        },
      );
    }
  }

  Widget _buildBlogListView(AsyncSnapshot<QuerySnapshot> snapshot) {
    if (snapshot.hasError) {
      debugPrint('FEED ERROR: ${snapshot.error}');
      return Center(child: Text('Error: ${snapshot.error}', style: GoogleFonts.inter(color: _warmGray, fontSize: 12)));
    }
    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

    final docs = snapshot.data!.docs;
    if (docs.isEmpty) return Center(child: Text('No stories yet.', style: GoogleFonts.inter(color: _warmGray)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final blog = docs[index].data() as Map<String, dynamic>;
        return _buildSocialCard(blog, docs[index].id);
      },
    );
  }

  void _shareBlog(Map<String, dynamic> blog) {
    final authorName = blog['authorName'] ?? 'Traveller';
    final city = blog['city'] ?? '';
    final country = blog['country'] ?? '';
    final content = blog['content'] ?? '';
    final location = [city, country].where((s) => s.isNotEmpty).join(', ');

    final shareText = StringBuffer();
    if (location.isNotEmpty) {
      shareText.writeln('$authorName - $location');
      shareText.writeln();
    }
    shareText.writeln(content);
    shareText.writeln();
    shareText.write('Shared via Wander');

    Share.share(shareText.toString());
  }

  void _toggleBookmark(String authorId, String blogId, Map<String, dynamic> blog, bool isSaved) {
    if (isSaved) {
      _authService.unsaveBlog(authorId, blogId);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Story removed from saved', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: _warmGray,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ));
    } else {
      _authService.saveBlog(authorId, blogId, blog);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Story saved!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF2ECC71),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Widget _buildSocialCard(Map<String, dynamic> blog, String blogId) {
    final authorName = blog['authorName'] ?? 'Traveller';
    final authorId = blog['authorId'];
    final authorPhotoUrl = blog['authorPhotoUrl'] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final likeCount = blog['likeCount'] ?? 0;
    final commentCount = blog['commentCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: authorId))),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _accent, width: 2)),
                child: CircleAvatar(
                  backgroundColor: _accent.withAlpha(30),
                  backgroundImage: authorPhotoUrl.isNotEmpty ? NetworkImage(authorPhotoUrl) : null,
                  child: authorPhotoUrl.isEmpty ? Text(authorName[0].toUpperCase(), style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)) : null,
                ),
              ),
            ),
            title: Text(authorName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text('${blog['city']}, ${blog['country']}', style: GoogleFonts.inter(color: _accent, fontSize: 12, fontWeight: FontWeight.w600)),
            trailing: authorId == _authService.currentUser?.uid
                ? GestureDetector(
                    onTap: () => _showBlogOptionsSheet(blogId, blog),
                    child: const Icon(Icons.more_horiz),
                  )
                : const Icon(Icons.more_horiz),
          ),
          if (blog['imageUrls'] != null && (blog['imageUrls'] as List).length > 1)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: (blog['imageUrls'] as List).length,
                itemBuilder: (_, i) => Stack(
                  children: [
                    Image.network(
                      blog['imageUrls'][i], height: 250, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, e, s) => Container(
                        height: 250, color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                      ),
                    ),
                    Positioned(
                      bottom: 8, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                        child: Text('${i + 1}/${(blog['imageUrls'] as List).length}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (blog['imageUrl'] != null)
            ClipRRect(
              child: Image.network(blog['imageUrl'], height: 250, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, e, s) => Container(
                  height: 250, width: double.infinity,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blog['content'] ?? '', style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : _darkText)),
                const SizedBox(height: 16),
                _buildSocialRow(authorId, blogId, blog, likeCount, commentCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialRow(String authorId, String blogId, Map<String, dynamic> blog, int likeCount, int commentCount) {
    final likeKey = '${authorId}_$blogId';
    final bookmarkKey = '${authorId}_$blogId';

    // Load like/bookmark state only once per blog, not on every rebuild
    if (!_likeCache.containsKey(likeKey)) {
      _authService.isLikedOnce(authorId, blogId).then((val) {
        if (mounted) setState(() => _likeCache[likeKey] = val);
      });
    }
    if (!_bookmarkCache.containsKey(bookmarkKey)) {
      _authService.isBlogSavedOnce(authorId, blogId).then((val) {
        if (mounted) setState(() => _bookmarkCache[bookmarkKey] = val);
      });
    }

    final isLiked = _likeCache[likeKey] ?? false;
    final isSaved = _bookmarkCache[bookmarkKey] ?? false;

    return Row(
      children: [
        _socialAction(
          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          likeCount.toString(),
          color: isLiked ? _accent : _warmGray,
          onTap: () {
            _likeCache[likeKey] = !isLiked;
            _authService.toggleLike(authorId, blogId);
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(width: 16),
        _socialAction(
          Icons.chat_bubble_outline_rounded,
          commentCount.toString(),
          onTap: () => _showCommentsSheet(authorId, blogId),
        ),
        const SizedBox(width: 16),
        _socialAction(
          Icons.send_rounded,
          '',
          onTap: () => _shareBlog(blog),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            _bookmarkCache[bookmarkKey] = !isSaved;
            _toggleBookmark(authorId, blogId, blog, isSaved);
            if (mounted) setState(() {});
          },
          child: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: isSaved ? _accent : _warmGray,
          ),
        ),
      ],
    );
  }

  Widget _socialAction(IconData icon, String count, {Color? color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? _warmGray),
          if (count.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(count, style: GoogleFonts.inter(fontSize: 13, color: color ?? _warmGray, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  void _showBlogOptionsSheet(String blogId, Map<String, dynamic> blog) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: _accent),
                title: Text('Edit Story', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditBlogSheet(blogId, blog);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                title: Text('Delete Story', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteBlog(blogId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteBlog(String blogId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Story', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this story? This cannot be undone.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: _warmGray)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _authService.deleteBlog(blogId);
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Story deleted', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    backgroundColor: _warmGray,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditBlogSheet(String blogId, Map<String, dynamic> blog) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPostSheet(
        blogId: blogId,
        blog: blog,
        authService: _authService,
      ),
    );
  }

  void _showCommentsSheet(String authorId, String blogId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(authorId: authorId, blogId: blogId),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(initialCity: widget.initialCity, initialCountry: widget.initialCountry),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String authorId;
  final String blogId;
  const _CommentsSheet({required this.authorId, required this.blogId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
              stream: _authService.getComments(widget.authorId, widget.blogId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Could not load comments', style: GoogleFonts.inter(color: Colors.grey)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return Center(child: Text('No comments yet.', style: GoogleFonts.inter(color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final comment = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFF6B6B).withAlpha(30),
                        child: Text((comment['username'] ?? 'T')[0].toUpperCase(), style: const TextStyle(color: Color(0xFFFF6B6B))),
                      ),
                      title: Text(comment['username'] ?? 'Traveller', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(comment['text'] ?? '', style: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white70 : Colors.black87)),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
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
                  onPressed: () {
                    if (_commentController.text.trim().isEmpty) return;
                    _authService.addComment(widget.authorId, widget.blogId, _commentController.text);
                    _commentController.clear();
                  },
                  icon: const Icon(Icons.send_rounded, color: Color(0xFFFF6B6B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  final String? initialCountry;
  final String? initialCity;
  const _CreatePostSheet({this.initialCountry, this.initialCity});

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final _contentController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final AuthService _authService = AuthService();
  final List<File> _images = [];
  bool _loading = false;

  static const _accent = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _cityController.text = widget.initialCity ?? '';
    _countryController.text = widget.initialCountry ?? '';
  }

  @override
  void dispose() {
    _contentController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Share Your Adventure', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location fields
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          style: GoogleFonts.inter(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'City',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                            prefixIcon: const Icon(Icons.location_city_rounded, color: _accent, size: 20),
                            filled: true,
                            fillColor: isDark ? Colors.white10 : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _countryController,
                          style: GoogleFonts.inter(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Country',
                            hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                            prefixIcon: const Icon(Icons.public_rounded, color: _accent, size: 20),
                            filled: true,
                            fillColor: isDark ? Colors.white10 : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Content
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: "Where did you go? What did you see?",
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAIBtn(),
                  const SizedBox(height: 16),
                  _buildImagePicker(isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _savePost,
              style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text('Post Story', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBtn() {
    return TextButton.icon(
      onPressed: _loading ? null : () async {
        final city = _cityController.text.trim();
        final country = _countryController.text.trim();
        setState(() => _loading = true);
        try {
          final res = await _geminiService.generateBlogContent(
            country.isNotEmpty ? country : "World",
            city.isNotEmpty ? city : "Adventure",
          );
          if (res != null && mounted) _contentController.text = res;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI generation failed: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _loading = false);
        }
      },
      icon: const Icon(Icons.auto_awesome, color: _accent),
      label: Text('AI Magic Writer', style: GoogleFonts.inter(color: _accent, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._images.asMap().entries.map((entry) {
            final i = entry.key;
            final file = entry.value;
            return Container(
              width: 120, height: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(file, fit: BoxFit.cover, width: 120, height: 120),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_images.length < 5)
            GestureDetector(
              onTap: () async {
                final img = await ImagePicker().pickImage(source: ImageSource.gallery);
                if (img != null && mounted) setState(() => _images.add(File(img.path)));
              },
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(8) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withAlpha(40), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 28, color: Colors.grey.withAlpha(150)),
                    const SizedBox(height: 4),
                    Text('${_images.length}/5', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _savePost() async {
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please write something before posting', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    if (city.isEmpty || country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter city and country', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      // Upload all images
      List<String> imageUrls = [];
      for (int i = 0; i < _images.length; i++) {
        final ref = FirebaseStorage.instance.ref().child('user_blogs/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
        await ref.putFile(_images[i]);
        imageUrls.add(await ref.getDownloadURL());
      }

      // Get user profile for fullName
      final profile = await _authService.getUserProfile(user.uid);
      final authorName = profile?['fullName'] ?? user.displayName ?? 'Traveller';
      final authorPhoto = profile?['photoUrl'] ?? user.photoURL ?? '';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('blogs').add({
        'authorId': user.uid,
        'authorName': authorName,
        'authorPhotoUrl': authorPhoto,
        'content': content,
        'imageUrl': imageUrls.isNotEmpty ? imageUrls.first : null,
        'imageUrls': imageUrls,
        'city': city,
        'country': country,
        'createdAt': FieldValue.serverTimestamp(),
        'likeCount': 0,
        'commentCount': 0,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post story: $e', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _EditPostSheet extends StatefulWidget {
  final String blogId;
  final Map<String, dynamic> blog;
  final AuthService authService;
  const _EditPostSheet({required this.blogId, required this.blog, required this.authService});

  @override
  State<_EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends State<_EditPostSheet> {
  late final TextEditingController _contentController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  bool _loading = false;

  static const _accent = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.blog['content'] ?? '');
    _cityController = TextEditingController(text: widget.blog['city'] ?? '');
    _countryController = TextEditingController(text: widget.blog['country'] ?? '');
  }

  @override
  void dispose() {
    _contentController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Edit Story', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cityController,
                          style: GoogleFonts.inter(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'City',
                            prefixIcon: const Icon(Icons.location_city_rounded, color: _accent, size: 20),
                            filled: true,
                            fillColor: isDark ? Colors.white10 : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _countryController,
                          style: GoogleFonts.inter(fontSize: 14, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Country',
                            prefixIcon: const Icon(Icons.public_rounded, color: _accent, size: 20),
                            filled: true,
                            fillColor: isDark ? Colors.white10 : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    maxLines: 10,
                    style: GoogleFonts.inter(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: "Edit your story...",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _loading ? null : _updatePost,
              style: ElevatedButton.styleFrom(backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Save Changes', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePost() async {
    final content = _contentController.text.trim();
    final city = _cityController.text.trim();
    final country = _countryController.text.trim();

    if (content.isEmpty || city.isEmpty || country.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all fields', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await widget.authService.updateBlog(widget.blogId, {
        'content': content,
        'city': city,
        'country': country,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Story updated!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}