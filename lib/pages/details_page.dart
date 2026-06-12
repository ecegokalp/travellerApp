import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'blog_page.dart';

class DestinationDetailPage extends StatelessWidget {
  final Map<String, String> destination;

  const DestinationDetailPage({super.key, required this.destination});

  static const _accent = Color(0xFFFF6B6B);
  static const _darkText = Color(0xFF1F2937);
  static const _warmGray = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : _darkText;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero image with glassmorphism controls
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      child: CachedNetworkImage(
                        imageUrl: destination['image']!,
                        height: 420,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(height: 420, color: isDark ? Colors.grey[800] : Colors.grey[200]),
                        errorWidget: (_, _, _) => Container(height: 420, color: Colors.grey[300], child: const Icon(Icons.image_not_supported, size: 48)),
                      ),
                    ),
                    // 4-stop gradient overlay
                    Container(
                      height: 420,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.3, 0.6, 1.0],
                          colors: [
                            Colors.black.withAlpha(60),
                            Colors.transparent,
                            Colors.black.withAlpha(30),
                            Colors.black.withAlpha(180),
                          ],
                        ),
                      ),
                    ),
                    // Top glassmorphism buttons
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _glassBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                            Row(children: [
                              _glassBtn(Icons.edit_note_rounded, () {
                                final parts = destination['title']!.split(', ');
                                final city = parts[0];
                                final country = parts.length > 1 ? parts[1] : '';
                                showCreateStorySheet(context, initialCity: city, initialCountry: country);
                              }),
                              const SizedBox(width: 10),
                              _glassBtn(Icons.ios_share_rounded, () {}),
                              const SizedBox(width: 10),
                              _glassBtn(Icons.favorite_rounded, () {}),
                            ]),
                          ],
                        ),
                      ),
                    ),
                    // Title on image
                    Positioned(
                      left: 20, right: 80, bottom: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination['title'] ?? 'Destination',
                            style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white, height: 1.15),
                          ),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.location_on_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(destination['category'] ?? '', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white70),
                          ]),
                        ],
                      ),
                    ),
                    // Rating circle
                    Positioned(
                      right: 20, bottom: 30,
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: cardColor,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          Text(destination['rating'] ?? '', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: textColor)),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Location tag
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    Icon(Icons.diamond_outlined, size: 14, color: _accent),
                    const SizedBox(width: 6),
                    Text(
                      (destination['category'] ?? 'DESTINATION').toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: _warmGray, letterSpacing: 2),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    destination['subtitle'] ?? '',
                    style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.w700, color: textColor),
                  ),
                ),
                const SizedBox(height: 20),

                // Info pills row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    _infoPill(Icons.location_on_outlined, destination['category'] ?? '', isDark, cardColor, textColor),
                    const SizedBox(width: 10),
                    _infoPill(Icons.star_rounded, destination['rating'] ?? '', isDark, cardColor, textColor),
                    const SizedBox(width: 10),
                    _infoPill(Icons.calendar_today_rounded, '10 days', isDark, cardColor, textColor),
                  ]),
                ),
                const SizedBox(height: 24),

                // Amenity cards
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(children: [
                    _amenityCard(Icons.wifi_rounded, 'Free Wi-Fi', isDark, textColor),
                    const SizedBox(width: 12),
                    _amenityCard(Icons.restaurant_rounded, 'Dinner', isDark, textColor),
                    const SizedBox(width: 12),
                    _amenityCard(Icons.flight_rounded, 'Transport', isDark, textColor),
                    const SizedBox(width: 12),
                    _amenityCard(Icons.map_rounded, 'Guide', isDark, textColor),
                  ]),
                ),
                const SizedBox(height: 24),

                // About section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('About', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '${destination['subtitle']}. Experience the unique atmosphere of this destination. Whether you are looking for adventure or relaxation, this place has everything to offer for an unforgettable journey.',
                    style: GoogleFonts.inter(color: isDark ? Colors.white60 : _warmGray, fontSize: 14, height: 1.7),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _infoPill(IconData icon, String text, bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: _warmGray),
        const SizedBox(width: 5),
        Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
      ]),
    );
  }

  Widget _amenityCard(IconData icon, String label, bool isDark, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : _accent.withAlpha(18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _accent.withAlpha(isDark ? 40 : 25), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: _accent),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: textColor), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
