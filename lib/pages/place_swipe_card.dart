import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_model.dart';

class PlaceSwipeCard extends StatefulWidget {
  final PlaceModel place;
  const PlaceSwipeCard({super.key, required this.place});

  @override
  State<PlaceSwipeCard> createState() => _PlaceSwipeCardState();
}

class _PlaceSwipeCardState extends State<PlaceSwipeCard> {
  bool _showAerial = false;

  static const _coral = Color(0xFFFF6B6B);

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
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
            // Photo or Aerial view
            if (_showAerial)
              _aerialView(place)
            else
              CachedNetworkImage(
                imageUrl: place.displayImage,
                fit: BoxFit.cover,
                placeholder: (_, _) => _gradient(place),
                errorWidget: (_, _, _) => _gradient(place),
              ),

            // Dark gradient overlay
            if (!_showAerial)
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

            // Aerial view overlay gradient (lighter, for readability)
            if (_showAerial)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.6, 1.0],
                    colors: [
                      Colors.black.withAlpha(10),
                      Colors.black.withAlpha(40),
                      Colors.black.withAlpha(180),
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

            // Aerial view toggle button
            Positioned(
              top: 14,
              right: place.effectiveRating > 0 ? 14 : 14,
              bottom: null,
              child: Padding(
                padding: EdgeInsets.only(top: place.effectiveRating > 0 ? 38 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => _showAerial = !_showAerial),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showAerial ? _coral : Colors.black.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(60)),
                    ),
                    child: Icon(
                      _showAerial ? Icons.photo_rounded : Icons.satellite_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
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
                  if (place.description != null && !_showAerial) ...[
                    const SizedBox(height: 6),
                    Text(
                      place.description!,
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withAlpha(160), height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (_showAerial) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.satellite_alt_rounded, color: Colors.white70, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Aerial View',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
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

  Widget _aerialView(PlaceModel place) {
    return IgnorePointer(
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(place.latitude, place.longitude),
          initialZoom: 17,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.example.traveller_app',
          ),
          MarkerLayer(markers: [
            Marker(
              point: LatLng(place.latitude, place.longitude),
              width: 28,
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: _coral,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [BoxShadow(color: _coral.withAlpha(100), blurRadius: 8)],
                ),
                child: const Icon(Icons.place_rounded, color: Colors.white, size: 14),
              ),
            ),
          ]),
        ],
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

  Widget _gradient(PlaceModel place) {
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