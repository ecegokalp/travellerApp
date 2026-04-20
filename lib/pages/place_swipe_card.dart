import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/place_model.dart';

class PlaceSwipeCard extends StatelessWidget {
  final PlaceModel place;
  const PlaceSwipeCard({super.key, required this.place});

  static const _coral = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            CachedNetworkImage(
              imageUrl: place.displayImage,
              fit: BoxFit.cover,
              placeholder: (_, __) => _gradient(),
              errorWidget: (_, __, ___) => _gradient(),
            ),

            // Dark gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.6, 1.0],
                  colors: [
                    Colors.black.withAlpha(20),
                    Colors.transparent,
                    Colors.black.withAlpha(60),
                    Colors.black.withAlpha(210),
                  ],
                ),
              ),
            ),

            // Top badges
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  _badge('${_emoji(place.category)} ${_label(place.category)}'),
                  const Spacer(),
                  if (place.effectiveRating > 0)
                    _badge('⭐ ${place.ratingLabel}'),
                ],
              ),
            ),

            // Bottom info
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    place.name,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Colors.white.withAlpha(200), size: 13),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${place.city}, ${place.country}',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withAlpha(200)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (place.description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      place.description!,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withAlpha(160), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }

  Widget _gradient() {
    final colors = _gradients[place.category] ?? [_coral, const Color(0xFFFF8E53)];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Center(
        child: Text(_emoji(place.category), style: const TextStyle(fontSize: 72)),
      ),
    );
  }

  static String _emoji(String c) => const {
    'attraction': '🏛️', 'viewpoint': '🌅', 'museum': '🖼️',
    'tower': '🗼', 'bridge': '🌉', 'lighthouse': '🏠',
    'cathedral': '⛪', 'church': '⛪', 'mosque': '🕌', 'temple': '🛕',
    'synagogue': '🕍', 'palace': '🏰', 'place_of_worship': '⛪',
    'theatre': '🎭', 'cinema': '🎬', 'stadium': '🏟️',
    'cafe': '☕', 'restaurant': '🍽️', 'bar': '🍸', 'pub': '🍺',
    'nightclub': '🎶', 'ice_cream': '🍦',
    'monument': '🗿', 'castle': '🏰', 'memorial': '🕊️',
    'ruins': '🏛️', 'archaeological_site': '⛏️', 'fort': '🏰',
    'artwork': '🎨', 'gallery': '🎨', 'zoo': '🦁', 'theme_park': '🎢',
    'park': '🌳', 'garden': '🌺', 'marina': '⛵', 'beach_resort': '🏖️',
  }[c] ?? '📍';

  static String _label(String c) =>
      c.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  static const _gradients = {
    'attraction': [Color(0xFF667eea), Color(0xFF764ba2)],
    'museum': [Color(0xFFf093fb), Color(0xFFf5576c)],
    'cafe': [Color(0xFFc79081), Color(0xFFdfa579)],
    'restaurant': [Color(0xFFa18cd1), Color(0xFFfbc2eb)],
    'bar': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    'park': [Color(0xFF0ba360), Color(0xFF3cba92)],
    'castle': [Color(0xFFfccb90), Color(0xFFd57eeb)],
  };
}
