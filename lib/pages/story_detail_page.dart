import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/app_widgets.dart';

class StoryDetailPage extends StatefulWidget {
  final String authorId;
  final String blogId;
  final Map<String, dynamic> blog;
  final AuthService authService;

  const StoryDetailPage({
    super.key,
    required this.authorId,
    required this.blogId,
    required this.blog,
    required this.authService,
  });

  @override
  State<StoryDetailPage> createState() => _StoryDetailPageState();
}

class _StoryDetailPageState extends State<StoryDetailPage> {
  static const _accent = Color(0xFF0D9488);
  static const _warmGray = Color(0xFF6B7280);

  late int _likeCount;
  bool _liked = false;
  late Map<String, dynamic> _blog;

  bool get _isOwner => widget.authorId == widget.authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _blog = Map<String, dynamic>.from(widget.blog);
    _likeCount = (_blog['likeCount'] ?? 0) as int;
    widget.authService.isLikedOnce(widget.authorId, widget.blogId).then((v) {
      if (mounted) setState(() => _liked = v);
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Story', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure? This cannot be undone.', style: GoogleFonts.inter()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: GoogleFonts.inter(color: _warmGray))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.authService.deleteBlog(widget.blogId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openEdit() {
    final contentCtrl = TextEditingController(text: _blog['content'] ?? '');
    final cityCtrl = TextEditingController(text: _blog['city'] ?? '');
    final countryCtrl = TextEditingController(text: _blog['country'] ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget field(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) => TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: _accent, size: 20),
            filled: true,
            fillColor: isDark ? Colors.white10 : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          decoration: BoxDecoration(color: Theme.of(ctx).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(60), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text('Edit Story', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold, fontSize: 22)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: field(cityCtrl, 'City', Icons.location_city_rounded)),
                const SizedBox(width: 12),
                Expanded(child: field(countryCtrl, 'Country', Icons.public_rounded)),
              ]),
              const SizedBox(height: 12),
              field(contentCtrl, 'Your story...', Icons.notes_rounded, maxLines: 5),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final data = {
                      'content': contentCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                      'country': countryCtrl.text.trim(),
                    };
                    await widget.authService.updateBlog(widget.blogId, data);
                    if (mounted) setState(() => _blog.addAll(data));
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text('Save Changes', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      builder: (_) => StoryCommentsSheet(authorId: widget.authorId, blogId: widget.blogId, authService: widget.authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final b = _blog;
    final images = (b['imageUrls'] as List?)?.cast<String>() ?? (b['imageUrl'] != null ? <String>[b['imageUrl'] as String] : <String>[]);
    final rating = (b['rating'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppHeader(
        title: b['authorName'] ?? 'Story',
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_horiz_rounded, color: textColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (v) {
                if (v == 'edit') _openEdit();
                if (v == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, color: _accent, size: 20), const SizedBox(width: 10), Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w600))])),
                PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20), const SizedBox(width: 10), Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.redAccent))])),
              ],
            ),
        ],
      ),
      body: ListView(
        children: [
          if (images.length == 1)
            Image.network(
              images.first,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (_, _, _) => Container(height: 250, color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey)),
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
                        errorBuilder: (_, _, _) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey)),
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

class StoryCommentsSheet extends StatefulWidget {
  final String authorId;
  final String blogId;
  final AuthService authService;

  const StoryCommentsSheet({super.key, required this.authorId, required this.blogId, required this.authService});

  @override
  State<StoryCommentsSheet> createState() => _StoryCommentsSheetState();
}

class _StoryCommentsSheetState extends State<StoryCommentsSheet> {
  static const _accent = Color(0xFF0D9488);
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