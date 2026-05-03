import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';

class SavedTripsPage extends StatelessWidget {
  const SavedTripsPage({super.key});

  static const _accent = Color(0xFFFF6B6B);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Adventures',
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: authService.getSavedTrips(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }

          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border_rounded, size: 64, color: _warmGray.withAlpha(120)),
                  const SizedBox(height: 16),
                  Text(
                    'No saved trips yet',
                    style: GoogleFonts.inter(color: _warmGray, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildTripCard(
                  context,
                  data['title'] ?? '',
                  data['subtitle'] ?? '',
                  data['image'] ?? '',
                  data['rating'] ?? '0.0',
                  isDark,
                  cardColor,
                  textColor,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    String title,
    String subtitle,
    String imageUrl,
    String rating,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 180,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 180,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.image_not_supported_outlined, color: _warmGray),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.favorite, color: _accent, size: 20),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : _warmGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}