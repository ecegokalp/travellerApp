import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../services/auth_service.dart';
import '../services/gemini_service.dart';

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
  double _rating = 0;

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
                  // Rating
                  Row(
                    children: [
                      Text('Rate this place', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.grey[600])),
                      const SizedBox(width: 12),
                      ...List.generate(5, (i) => GestureDetector(
                        onTap: () => setState(() => _rating = i + 1.0),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: i < _rating ? Colors.amber : (isDark ? Colors.white30 : Colors.grey[400]),
                            size: 28,
                          ),
                        ),
                      )),
                    ],
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
        'rating': _rating > 0 ? _rating : null,
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

/// Opens the "share your story" composer sheet from anywhere.
void showCreateStorySheet(BuildContext context, {String? initialCity, String? initialCountry}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreatePostSheet(initialCity: initialCity, initialCountry: initialCountry),
  );
}
