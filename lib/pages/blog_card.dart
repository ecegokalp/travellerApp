import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import 'story_detail_page.dart';
import 'profile_page.dart';

/// A reusable "Wander Feed" post card with full interactions
/// (like, comment, save, share, multi-image, rating, edit/delete for own posts).
class BlogCard extends StatefulWidget {
  final Map<String, dynamic> blog;
  final String blogId;
  final AuthService authService;

  const BlogCard({super.key, required this.blog, required this.blogId, required this.authService});

  @override
  State<BlogCard> createState() => _BlogCardState();
}

class _BlogCardState extends State<BlogCard> {
  static const _accent = Color(0xFF0D9488);
  static const _warmGray = Color(0xFF6B7280);

  bool _liked = false;
  bool _saved = false;
  late int _likeCount;

  String get _authorId => widget.blog['authorId'] ?? '';

  @override
  void initState() {
    super.initState();
    _likeCount = (widget.blog['likeCount'] ?? 0) as int;
    widget.authService.isLikedOnce(_authorId, widget.blogId).then((v) {
      if (mounted) setState(() => _liked = v);
    });
    widget.authService.isBlogSavedOnce(_authorId, widget.blogId).then((v) {
      if (mounted) setState(() => _saved = v);
    });
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
      if (_likeCount < 0) _likeCount = 0;
    });
    widget.authService.toggleLike(_authorId, widget.blogId);
  }

  void _toggleSave() {
    final nowSaved = !_saved;
    setState(() => _saved = nowSaved);
    if (nowSaved) {
      widget.authService.saveBlog(_authorId, widget.blogId, widget.blog);
    } else {
      widget.authService.unsaveBlog(_authorId, widget.blogId);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nowSaved ? 'Story saved!' : 'Story removed from saved', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      backgroundColor: nowSaved ? const Color(0xFF2ECC71) : _warmGray,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoryCommentsSheet(authorId: _authorId, blogId: widget.blogId, authService: widget.authService),
    );
  }

  void _share() {
    final authorName = widget.blog['authorName'] ?? 'Traveller';
    final city = widget.blog['city'] ?? '';
    final country = widget.blog['country'] ?? '';
    final content = widget.blog['content'] ?? '';
    final location = [city, country].where((s) => s.toString().isNotEmpty).join(', ');
    final buffer = StringBuffer();
    if (location.isNotEmpty) buffer.writeln('$authorName - $location\n');
    buffer.writeln(content);
    buffer.write('\nShared via Wander');
    Share.share(buffer.toString());
  }

  void _openDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryDetailPage(authorId: _authorId, blogId: widget.blogId, blog: widget.blog, authService: widget.authService),
      ),
    );
  }

  void _showOwnerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: _accent),
              title: Text('Edit Story', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _openEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.redAccent),
              title: Text('Delete Story', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
            onPressed: () {
              Navigator.pop(ctx);
              widget.authService.deleteBlog(widget.blogId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openEdit() {
    final contentCtrl = TextEditingController(text: widget.blog['content'] ?? '');
    final cityCtrl = TextEditingController(text: widget.blog['city'] ?? '');
    final countryCtrl = TextEditingController(text: widget.blog['country'] ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                Expanded(child: _editField(cityCtrl, 'City', Icons.location_city_rounded, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _editField(countryCtrl, 'Country', Icons.public_rounded, isDark)),
              ]),
              const SizedBox(height: 12),
              _editField(contentCtrl, 'Your story...', Icons.notes_rounded, isDark, maxLines: 5),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    await widget.authService.updateBlog(widget.blogId, {
                      'content': contentCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                      'country': countryCtrl.text.trim(),
                    });
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

  Widget _editField(TextEditingController c, String hint, IconData icon, bool isDark, {int maxLines = 1}) {
    return TextField(
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final blog = widget.blog;
    final authorName = blog['authorName'] ?? 'Traveller';
    final authorPhoto = blog['authorPhotoUrl'] ?? '';
    final city = blog['city'] ?? '';
    final country = blog['country'] ?? '';
    final rating = (blog['rating'] as num?)?.toDouble() ?? 0;
    final commentCount = blog['commentCount'] ?? 0;
    final isOwner = _authorId == widget.authService.currentUser?.uid;
    final images = (blog['imageUrls'] as List?)?.cast<String>() ?? (blog['imageUrl'] != null ? <String>[blog['imageUrl'] as String] : <String>[]);

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 30 : 12), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author
            ListTile(
              leading: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: _authorId))),
                child: CircleAvatar(
                  backgroundColor: _accent.withAlpha(30),
                  backgroundImage: authorPhoto.isNotEmpty ? NetworkImage(authorPhoto) : null,
                  child: authorPhoto.isEmpty ? Text(authorName[0].toUpperCase(), style: const TextStyle(color: _accent, fontWeight: FontWeight.bold)) : null,
                ),
              ),
              title: Text(authorName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: textColor)),
              subtitle: Row(children: [
                Flexible(child: Text('$city${country.isNotEmpty ? ', $country' : ''}', style: GoogleFonts.inter(color: _accent, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                if (rating > 0) ...[
                  const SizedBox(width: 8),
                  ...List.generate(5, (i) => Icon(i < rating.round() ? Icons.star_rounded : Icons.star_border_rounded, size: 12, color: i < rating.round() ? Colors.amber : Colors.grey[400])),
                ],
              ]),
              trailing: isOwner ? GestureDetector(onTap: _showOwnerOptions, child: Icon(Icons.more_horiz, color: textColor)) : null,
            ),
            // Images
            if (images.length == 1)
              Image.network(images.first, width: double.infinity, fit: BoxFit.fitWidth,
                errorBuilder: (_, _, _) => Container(height: 200, color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey)))
            else if (images.length > 1)
              Container(
                height: 340,
                color: isDark ? Colors.black : const Color(0xFFF0ECE4),
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, i) => Stack(children: [
                    Positioned.fill(child: Image.network(images[i], fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(color: isDark ? Colors.grey[800] : Colors.grey[200], child: const Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey)))),
                    Positioned(
                      bottom: 8, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                        child: Text('${i + 1}/${images.length}', style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),
            // Content + actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(blog['content'] ?? '', style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : const Color(0xFF1F2937))),
                  const SizedBox(height: 14),
                  Row(children: [
                    _action(_liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, '$_likeCount', _toggleLike, color: _liked ? _accent : _warmGray),
                    const SizedBox(width: 18),
                    _action(Icons.chat_bubble_outline_rounded, '$commentCount', _openComments),
                    const SizedBox(width: 18),
                    _action(Icons.send_rounded, '', _share),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleSave,
                      child: Icon(_saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: _saved ? _accent : _warmGray),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String count, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 22, color: color ?? _warmGray),
        if (count.isNotEmpty) ...[
          const SizedBox(width: 4),
          Text(count, style: GoogleFonts.inter(fontSize: 13, color: color ?? _warmGray, fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }
}
