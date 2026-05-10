import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'profile_page.dart';

class SavedStoriesPage extends StatelessWidget {
  const SavedStoriesPage({super.key});

  static const _accent = Color(0xFFFF6B6B);
  static const _warmGray = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('Saved Stories', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w800, fontSize: 20, color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: user == null
          ? Center(child: Text('Please login', style: GoogleFonts.inter(color: Colors.grey)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('saved_blogs')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Something went wrong', style: GoogleFonts.inter(color: _warmGray)));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _accent));
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: _accent.withAlpha(15), shape: BoxShape.circle),
                          child: Icon(Icons.bookmark_border_rounded, size: 48, color: _accent.withAlpha(150)),
                        ),
                        const SizedBox(height: 20),
                        Text('No saved stories', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey[700])),
                        const SizedBox(height: 8),
                        Text('Bookmark stories to find them here', style: GoogleFonts.inter(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final blog = docs[index].data() as Map<String, dynamic>;
                    final authorName = blog['authorName'] ?? 'Traveller';
                    final authorPhotoUrl = blog['authorPhotoUrl'] ?? '';
                    final authorId = blog['authorId'] ?? '';
                    final city = blog['city'] ?? '';
                    final country = blog['country'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            leading: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(userId: authorId))),
                              child: CircleAvatar(
                                backgroundColor: _accent.withAlpha(30),
                                backgroundImage: authorPhotoUrl.isNotEmpty ? NetworkImage(authorPhotoUrl) : null,
                                child: authorPhotoUrl.isEmpty
                                    ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : 'T', style: const TextStyle(color: _accent, fontWeight: FontWeight.bold))
                                    : null,
                              ),
                            ),
                            title: Text(authorName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              [city, country].where((s) => s.isNotEmpty).join(', '),
                              style: GoogleFonts.inter(color: _accent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.bookmark_remove_rounded, color: _accent),
                              onPressed: () {
                                final blogId = blog['blogId'] ?? '';
                                authService.unsaveBlog(authorId, blogId);
                              },
                            ),
                          ),
                          if (blog['imageUrl'] != null)
                            ClipRRect(
                              child: Image.network(
                                blog['imageUrl'],
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) => const SizedBox.shrink(),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              blog['content'] ?? '',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : const Color(0xFF1F2937)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
