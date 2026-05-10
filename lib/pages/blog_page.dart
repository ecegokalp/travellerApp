import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    if (snapshot.hasError) return Center(child: Text('Something went wrong'));
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
            trailing: const Icon(Icons.more_horiz),
          ),
          if (blog['imageUrl'] != null)
            ClipRRect(
              child: Image.network(blog['imageUrl'], height: 250, width: double.infinity, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blog['content'] ?? '', style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : _darkText)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    StreamBuilder<bool>(
                      stream: _authService.isLiked(authorId, blogId),
                      builder: (context, snapshot) {
                        final isLiked = snapshot.data ?? false;
                        return _socialAction(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          likeCount.toString(),
                          color: isLiked ? _accent : _warmGray,
                          onTap: () => _authService.toggleLike(authorId, blogId),
                        );
                      },
                    ),
                    const SizedBox(width: 16),
                    _socialAction(
                      Icons.chat_bubble_outline_rounded,
                      commentCount.toString(),
                      onTap: () => _showCommentsSheet(authorId, blogId),
                    ),
                    const SizedBox(width: 16),
                    _socialAction(Icons.send_rounded, ''),
                    const Spacer(),
                    const Icon(Icons.bookmark_border_rounded, color: _warmGray),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
  final GeminiService _geminiService = GeminiService();
  final AuthService _authService = AuthService();
  File? _image;
  bool _loading = false;
  late String? _country, _city;

  @override
  void initState() {
    super.initState();
    _city = widget.initialCity;
    _country = widget.initialCountry;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Text('Share Your Adventure', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: _contentController,
                    maxLines: 8,
                    decoration: InputDecoration(
                      hintText: "Where did you go? What did you see?",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAIBtn(),
                  const SizedBox(height: 16),
                  _buildImagePicker(),
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
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Post Story', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBtn() {
    return TextButton.icon(
      onPressed: () async {
        setState(() => _loading = true);
        final res = await _geminiService.generateBlogContent(_country ?? "World", _city ?? "Adventure");
        if (res != null) _contentController.text = res;
        setState(() => _loading = false);
      },
      icon: const Icon(Icons.auto_awesome, color: Color(0xFFFF6B6B)),
      label: const Text('AI Magic Writer', style: TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () async {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) setState(() => _image = File(img.path));
      },
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: _image != null ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.file(_image!, fit: BoxFit.cover)) : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
      ),
    );
  }

  Future<void> _savePost() async {
    setState(() => _loading = true);
    final user = _authService.currentUser;
    String? url;
    if (_image != null) {
      final ref = FirebaseStorage.instance.ref().child('blogs/${DateTime.now()}.jpg');
      await ref.putFile(_image!);
      url = await ref.getDownloadURL();
    }
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('blogs').add({
      'authorId': user.uid,
      'authorName': user.displayName ?? 'Traveller',
      'authorPhotoUrl': user.photoURL ?? '',
      'content': _contentController.text,
      'imageUrl': url,
      'city': _city ?? 'Unknown',
      'country': _country ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
      'likeCount': 0,
      'commentCount': 0,
    });
    Navigator.pop(context);
  }
}
