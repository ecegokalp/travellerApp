import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/place_model.dart';
import '../models/review_model.dart';
import '../services/place_service.dart';
import 'place_swipe_card.dart';
import 'blog_page.dart';

class MapExplorePage extends StatefulWidget {
  const MapExplorePage({super.key});
  @override
  State<MapExplorePage> createState() => _MapExplorePageState();
}

class _MapExplorePageState extends State<MapExplorePage> {
  final _placeService = PlaceService();
  final _mapController = MapController();
  final _swiperController = CardSwiperController();
  final _searchCtrl = TextEditingController();

  CityData? _selectedCity;
  List<PlaceModel> _allPlaces = [];
  List<PlaceModel> _filtered = [];
  List<Map<String, dynamic>> _liked = [];
  List<CityData> _searchResults = [];
  StreamSubscription? _likedSub;
  bool _loading = false, _searching = false, _showSwiper = true, _showSearch = false;
  LatLng? _userLoc;
  int _cardIdx = 0;
  String _filter = 'All';
  Timer? _debounce;

  static const _coral = Color(0xFF0D9488);
  static const _orange = Color(0xFF2DD4BF);

  static const _filters = ['All', 'Tourist', 'Cafes', 'Food', 'Bars', 'Historic', 'Parks'];
  static const _filterIcons = [
    Icons.apps_rounded, Icons.tour_rounded, Icons.coffee_rounded,
    Icons.restaurant_rounded, Icons.local_bar_rounded, Icons.account_balance_rounded, Icons.park_rounded,
  ];
  static const _filterCats = {
    'Tourist': ['attraction', 'museum', 'viewpoint', 'artwork', 'gallery', 'zoo', 'theme_park', 'tower', 'bridge', 'lighthouse'],
    'Cafes': ['cafe', 'ice_cream'],
    'Food': ['restaurant'],
    'Bars': ['bar', 'pub', 'nightclub'],
    'Historic': ['monument', 'castle', 'memorial', 'ruins', 'archaeological_site', 'fort', 'cathedral', 'church', 'mosque', 'temple', 'synagogue', 'palace', 'place_of_worship', 'theatre', 'stadium'],
    'Parks': ['park', 'garden', 'marina', 'beach_resort'],
  };

  @override
  void initState() {
    super.initState();
    _initLocation();
    // When Wikidata finishes loading in background, refresh cards with images/ratings
    _placeService.onWikidataLoaded = () {
      if (mounted) setState(() {});
    };
    _likedSub = _placeService.getLikedPlacesStream().listen((newLiked) {
      if (!mounted) return;
      // Only rebuild if liked places actually changed
      final oldIds = _liked.map((p) => p['id']).toSet();
      final newIds = newLiked.map((p) => p['id']).toSet();
      if (oldIds.length != newIds.length || !oldIds.containsAll(newIds)) {
        setState(() => _liked = newLiked);
      }
    }, onError: (e) {
      debugPrint('Liked places stream error: $e');
    });
  }

  @override
  void dispose() {
    _placeService.onWikidataLoaded = null;
    _likedSub?.cancel();
    _swiperController.dispose();
    _mapController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) setState(() => _userLoc = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final r = await _placeService.searchCities(q);
      if (mounted) setState(() { _searchResults = r; _searching = false; });
    });
  }

  Future<void> _selectCity(CityData city) async {
    setState(() {
      _selectedCity = city;
      _loading = true;
      _allPlaces = [];
      _filtered = [];
      _cardIdx = 0;
      _showSwiper = true;
      _showSearch = false;
      _searchResults = [];
      _searchCtrl.text = '${city.name}, ${city.country}';
      _filter = 'All';
    });
    _mapController.move(LatLng(city.centerLat, city.centerLng), 13.0);
    final places = await _placeService.getPlacesForCity(city);
    if (mounted) {
      setState(() { _allPlaces = places; _filtered = places; _loading = false; });
      _focusCurrentCard();
    }
  }

  void _applyFilter(String f) {
    setState(() {
      _filter = f;
      _cardIdx = 0;
      _showSwiper = true;
      _filtered = f == 'All' ? List.from(_allPlaces) : _allPlaces.where((p) => _filterCats[f]!.contains(p.category)).toList();
    });
    _focusCurrentCard();
  }

  void _onSwipe(int prev, int? cur, CardSwiperDirection dir) {
    if (prev >= _filtered.length) return;
    if (dir == CardSwiperDirection.right) {
      final place = _filtered[prev];
      _placeService.likePlace(place).then((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${place.name} saved!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 1),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        ));
      }).catchError((e) {
        debugPrint('Like place error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save ${place.name}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        ));
      });
    }
    setState(() => _cardIdx = cur ?? _filtered.length);
    _focusCurrentCard();
  }

  void _focusCurrentCard() {
    if (_cardIdx >= _filtered.length) return;
    final place = _filtered[_cardIdx];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const zoom = 16.0;
      final screenH = MediaQuery.of(context).size.height;
      final cardTop = screenH * 0.5 - 140;
      final targetY = cardTop * 0.72;
      final pixelsAboveCentre = (screenH * 0.5) - targetY;
      final latDelta = _pixelsToLatDelta(pixelsAboveCentre, zoom, place.latitude);
      _mapController.move(LatLng(place.latitude - latDelta, place.longitude), zoom);
    });
  }

  double _pixelsToLatDelta(double pixels, double zoom, double lat) {
    final metersPerPixel = 156543.03392 * math.cos(lat * math.pi / 180) / math.pow(2, zoom);
    return (pixels * metersPerPixel) / 111320.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCards = _showSwiper && _filtered.isNotEmpty && _cardIdx < _filtered.length;

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(child: _map(isDark)),
          _searchBar(isDark),
          if (_selectedCity != null && !_showSearch) _filterChips(isDark),
          if (hasCards) _swiper(),
          if (hasCards) _actionButtons(),
          if (_loading) _loadingWidget(isDark),
          if (!_loading && _selectedCity != null && _filtered.isEmpty) _emptyState(isDark),
          if (_selectedCity == null && !_loading) _welcomeState(isDark),
          _floatingBtns(isDark),
          if (_showSearch && (_searchResults.isNotEmpty || _searching)) _searchDropdown(isDark),
        ],
      ),
    );
  }

  // ── Map ──
  Widget _map(bool isDark) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _userLoc ?? const LatLng(41.0082, 28.9784),
        initialZoom: 12,
        onTap: (_, _) {
          if (_showSearch) setState(() => _showSearch = false);
        },
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.traveller_app',
        ),
        if (_userLoc != null)
          MarkerLayer(markers: [
            Marker(point: _userLoc!, width: 22, height: 22, child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9), shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: const Color(0xFF4A90D9).withAlpha(80), blurRadius: 10, spreadRadius: 3)],
              ),
            )),
          ]),
        if (_liked.isNotEmpty)
          MarkerLayer(markers: _liked.map((p) {
            return Marker(
              point: LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()),
              width: 36, height: 36,
              child: GestureDetector(
                onTap: () => _showLikedSheet(p),
                child: Container(
                  decoration: BoxDecoration(
                    color: _coral, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: _coral.withAlpha(80), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 16),
                ),
              ),
            );
          }).toList()),
        if (_showSwiper && _filtered.isNotEmpty && _cardIdx < _filtered.length)
          MarkerLayer(markers: [_currentPlaceMarker(_filtered[_cardIdx])]),
      ],
    );
  }

  Marker _currentPlaceMarker(PlaceModel place) {
    return Marker(
      point: LatLng(place.latitude, place.longitude),
      width: 240,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 82,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(45), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_rounded, size: 14, color: _coral),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
                  ),
                ),
              ]),
            ),
          ),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_coral, _orange]),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(color: _coral.withAlpha(120), blurRadius: 10, spreadRadius: 1)],
            ),
            child: const Icon(Icons.place_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  // ── Search bar ──
  Widget _searchBar(bool isDark) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txt = isDark ? Colors.white : const Color(0xFF1F2937);
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 50 : 15), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          const SizedBox(width: 16),
          const Icon(Icons.search_rounded, color: _coral, size: 22),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _searchCtrl,
            onTap: () => setState(() => _showSearch = true),
            onChanged: _onSearch,
            style: GoogleFonts.inter(fontSize: 14, color: txt, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Search any city...',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: isDark ? Colors.white38 : Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          )),
          if (_selectedCity != null) GestureDetector(
            onTap: () { _searchCtrl.clear(); setState(() { _selectedCity = null; _allPlaces = []; _filtered = []; _showSearch = false; }); },
            child: Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white54 : Colors.grey)),
          ) else const SizedBox(width: 12),
        ]),
      ),
    ));
  }

  // ── Search dropdown ──
  Widget _searchDropdown(bool isDark) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txt = isDark ? Colors.white : const Color(0xFF1F2937);
    return SafeArea(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 62, 16, 0),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 60 : 20), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: _searching
            ? const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: _coral))))
            : ListView.separated(
                shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => Divider(height: 1, indent: 56, color: Colors.grey.withAlpha(20)),
                itemBuilder: (_, i) {
                  final c = _searchResults[i];
                  return ListTile(
                    leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: _coral.withAlpha(20), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.location_city_rounded, color: _coral, size: 18)),
                    title: Text(c.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: txt)),
                    subtitle: Text(c.country, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
                    onTap: () => _selectCity(c),
                  );
                },
              ),
      ),
    ));
  }

  // ── Filter chips ──
  Widget _filterChips(bool isDark) {
    return SafeArea(child: Padding(
      padding: const EdgeInsets.only(top: 64),
      child: SizedBox(height: 42, child: ListView.builder(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final sel = _filter == _filters[i];
          return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () => _applyFilter(_filters[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? _coral : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 6)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_filterIcons[i], size: 15, color: sel ? Colors.white : Colors.grey),
                const SizedBox(width: 5),
                Text(_filters[i], style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey)),
              ]),
            ),
          ));
        },
      )),
    ));
  }

  // ── Swiper ──
  Widget _swiper() {
    return Positioned(
      left: 20, right: 20, bottom: 140,
      height: MediaQuery.of(context).size.height * 0.50,
      child: CardSwiper(
        controller: _swiperController,
        cardsCount: _filtered.length,
        initialIndex: _cardIdx,
        allowedSwipeDirection: const AllowedSwipeDirection.symmetric(horizontal: true),
        numberOfCardsDisplayed: _filtered.length.clamp(1, 3),
        scale: 0.92,
        backCardOffset: const Offset(0, -28),
        padding: EdgeInsets.zero,
        onSwipe: (prev, cur, dir) { _onSwipe(prev, cur, dir); return true; },
        onEnd: () {
          setState(() => _showSwiper = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('All places explored in ${_selectedCity?.name}!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            backgroundColor: _coral, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          ));
        },
        cardBuilder: (_, index, rawX, _) {
          final tx = rawX.toDouble() / 100.0;
          final place = _filtered[index];
          return GestureDetector(
            onTap: () => _showPlaceDetail(place),
            child: Stack(children: [
              PlaceSwipeCard(place: place),
              if (tx < -0.05) _swipeOverlay('NOPE', Colors.red, tx, Alignment.topRight, 0.3),
              if (tx > 0.05) _swipeOverlay('LIKE', Colors.green, tx, Alignment.topLeft, -0.3),
              Positioned(
                top: 60,
                right: 14,
                child: FloatingActionButton.small(
                  heroTag: 'share_${place.id}',
                  backgroundColor: Colors.white.withAlpha(200),
                  onPressed: () => _shareStory(place),
                  child: const Icon(Icons.edit_note_rounded, color: _coral),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _swipeOverlay(String text, Color color, double threshold, Alignment align, double angle) {
    final opacity = (threshold.abs() * 3).clamp(0.0, 1.0).toDouble();
    return Positioned.fill(child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: color.withAlpha((threshold.abs() * 120).toInt().clamp(0, 120)),
      ),
      child: Align(alignment: align, child: Padding(
        padding: const EdgeInsets.all(24),
        child: Opacity(opacity: opacity, child: Transform.rotate(angle: angle, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(8)),
          child: Text(text, style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ))),
      )),
    ));
  }

  // ── Action buttons ──
  Widget _actionButtons() {
    return Positioned(left: 0, right: 0, bottom: 90, child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _roundBtn(Icons.close_rounded, Colors.white, Colors.red.shade400, () => _swiperController.swipe(CardSwiperDirection.left)),
        const SizedBox(width: 40),
        _roundBtn(Icons.favorite_rounded, null, Colors.white, () => _swiperController.swipe(CardSwiperDirection.right), gradient: true),
      ],
    ));
  }

  Widget _roundBtn(IconData icon, Color? bg, Color iconColor, VoidCallback onTap, {bool gradient = false}) {
    return GestureDetector(onTap: onTap, child: Container(
      width: 58, height: 58,
      decoration: BoxDecoration(
        color: gradient ? null : bg, shape: BoxShape.circle,
        gradient: gradient ? const LinearGradient(colors: [_coral, _orange]) : null,
        boxShadow: [BoxShadow(color: (gradient ? _coral : Colors.red).withAlpha(40), blurRadius: 12, spreadRadius: 2)],
      ),
      child: Icon(icon, color: iconColor, size: 30),
    ));
  }

  // ── Floating buttons ──
  Widget _floatingBtns(bool isDark) {
    return Positioned(right: 16, bottom: 90, child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Add place button
      if (_selectedCity != null) ...[
        FloatingActionButton.small(
          heroTag: 'add', backgroundColor: Colors.green,
          onPressed: () => _showAddPlaceSheet(),
          child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 10),
      ],
      if (_userLoc != null) FloatingActionButton.small(
        heroTag: 'loc', backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        onPressed: () => _mapController.move(_userLoc!, 14), child: const Icon(Icons.my_location_rounded, color: _coral, size: 20),
      ),
      if (_filtered.isNotEmpty) ...[
        const SizedBox(height: 10),
        FloatingActionButton.small(
          heroTag: 'toggle', backgroundColor: _coral,
          onPressed: () => setState(() => _showSwiper = !_showSwiper),
          child: Icon(_showSwiper ? Icons.map_rounded : Icons.style_rounded, color: Colors.white, size: 20),
        ),
      ],
    ]));
  }

  // ── States ──
  Widget _loadingWidget(bool isDark) => Center(child: Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: (isDark ? const Color(0xFF1E1E2E) : Colors.white).withAlpha(240), borderRadius: BorderRadius.circular(20)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: _coral)),
      const SizedBox(height: 14),
      Text('Discovering places...', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF1F2937))),
    ]),
  ));

  Widget _emptyState(bool isDark) => Center(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 40), padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: (isDark ? const Color(0xFF1E1E2E) : Colors.white).withAlpha(240), borderRadius: BorderRadius.circular(20)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.search_off_rounded, size: 44, color: _coral),
      const SizedBox(height: 10),
      Text('No places found', style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 4),
      Text(_filter != 'All' ? 'Try a different filter' : 'Try another city', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
    ]),
  ));

  Widget _welcomeState(bool isDark) => Center(child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 32), padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(color: (isDark ? const Color(0xFF1E1E2E) : Colors.white).withAlpha(240), borderRadius: BorderRadius.circular(20)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_coral, _orange]), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.explore_rounded, color: Colors.white, size: 32)),
      const SizedBox(height: 16),
      Text('Discover Places', style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1F2937))),
      const SizedBox(height: 6),
      Text('Search any city to explore tourist spots,\ncafes, restaurants and more!', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, height: 1.4)),
    ]),
  ));

  // ── Place detail bottom sheet (reviews here) ──
  void _showPlaceDetail(PlaceModel place) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaceDetailSheet(place: place, placeService: _placeService),
    );
  }

  void _shareStory(PlaceModel place) {
    showCreateStorySheet(context, initialCity: place.city, initialCountry: place.country);
  }

  void _showLikedSheet(Map<String, dynamic> p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final txt = isDark ? Colors.white : const Color(0xFF1F2937);
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_coral, _orange]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name'] ?? '', style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.bold, color: txt)),
            Text('${p['city'] ?? ''} · ${p['category'] ?? ''}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
          ])),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () { _mapController.move(LatLng((p['latitude'] as num).toDouble(), (p['longitude'] as num).toDouble()), 16); Navigator.pop(context); setState(() => _showSwiper = false); },
            icon: const Icon(Icons.center_focus_strong_rounded, size: 16), label: const Text('Focus'),
            style: OutlinedButton.styleFrom(foregroundColor: _coral, side: const BorderSide(color: _coral), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: () { _placeService.unlikePlace(p['id']); Navigator.pop(context); },
            icon: const Icon(Icons.delete_outline_rounded, size: 16), label: const Text('Remove'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
          )),
        ]),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showAddPlaceSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _AddPlaceSheet(
        city: _selectedCity!,
        placeService: _placeService,
        onPlaceAdded: (place) {
          setState(() {
            _allPlaces.insert(0, place);
            _applyFilter(_filter);
          });
        },
      ),
    );
  }
}

// ── Place Detail Sheet (reviews/ratings) ──
class _PlaceDetailSheet extends StatefulWidget {
  final PlaceModel place;
  final PlaceService placeService;
  const _PlaceDetailSheet({required this.place, required this.placeService});

  @override
  State<_PlaceDetailSheet> createState() => _PlaceDetailSheetState();
}

class _PlaceDetailSheetState extends State<_PlaceDetailSheet> {
  List<ReviewModel> _reviews = [];
  bool _loading = true, _submitting = false;
  final _commentCtrl = TextEditingController();
  double _rating = 5;

  static const _coral = Color(0xFF0D9488);

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final r = await widget.placeService.getReviews(widget.place.id);
    if (mounted) setState(() { _reviews = r; _loading = false; });
  }

  Future<void> _submit() async {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    await widget.placeService.addReview(widget.place.id, _rating, _commentCtrl.text.trim());
    _commentCtrl.clear();
    await _loadReviews();
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txt = isDark ? Colors.white : const Color(0xFF1F2937);
    final p = widget.place;

    return DraggableScrollableSheet(
      initialChildSize: 0.55, maxChildSize: 0.85, minChildSize: 0.3,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: [
          // Handle
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // Place info
          Text(p.name, style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: txt)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text('${p.city}, ${p.country} · ${p.category.replaceAll('_', ' ')}',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
              ),
              TextButton.icon(
                onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  showCreateStorySheet(nav.context, initialCity: p.city, initialCountry: p.country);
                },
                icon: const Icon(Icons.edit_note_rounded, size: 20, color: _coral),
                label: Text('Share Story',
                    style: GoogleFonts.inter(color: _coral, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          if (p.description != null) ...[const SizedBox(height: 10), Text(p.description!, style: GoogleFonts.inter(fontSize: 13, color: txt, height: 1.4))],
          const SizedBox(height: 20),

          // Reviews header
          Text('Reviews', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: txt)),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: _coral)))
          else ...[
            if (_reviews.isEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: Text('No reviews yet. Be the first!', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey, fontStyle: FontStyle.italic))),
            ..._reviews.map((r) => _reviewTile(r, txt)),
          ],

          // Add review
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _coral.withAlpha(10), borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Rate', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: txt)),
                const SizedBox(width: 10),
                ...List.generate(5, (i) => GestureDetector(
                  onTap: () => setState(() => _rating = i + 1.0),
                  child: Icon(i < _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFD700), size: 24),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(
                  controller: _commentCtrl,
                  style: GoogleFonts.inter(fontSize: 13, color: txt),
                  decoration: InputDecoration(
                    hintText: 'Share your experience...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
                    isDense: true, filled: true,
                    fillColor: isDark ? Colors.white.withAlpha(8) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                )),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_coral, Color(0xFF2DD4BF)]), borderRadius: BorderRadius.circular(12)),
                    child: _submitting
                        ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _reviewTile(ReviewModel r, Color txt) {
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: txt.withAlpha(8), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 12, backgroundColor: _coral.withAlpha(40), child: Text(r.userName.isNotEmpty ? r.userName[0].toUpperCase() : '?', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: _coral))),
          const SizedBox(width: 8),
          Expanded(child: Text(r.userName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: txt))),
          ...List.generate(5, (i) => Icon(i < r.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: const Color(0xFFFFD700), size: 14)),
        ]),
        const SizedBox(height: 4),
        Text(r.comment, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey, height: 1.3)),
      ]),
    ));
  }
}

// ── Add Place Sheet ──
class _AddPlaceSheet extends StatefulWidget {
  final CityData city;
  final PlaceService placeService;
  final ValueChanged<PlaceModel> onPlaceAdded;
  const _AddPlaceSheet({required this.city, required this.placeService, required this.onPlaceAdded});

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _photo;
  String _category = 'cafe';
  bool _submitting = false;

  static const _coral = Color(0xFF0D9488);
  static const _categories = {
    'cafe': '☕ Cafe',
    'restaurant': '🍽️ Restaurant',
    'bar': '🍸 Bar',
    'attraction': '🏛️ Tourist Spot',
    'museum': '🖼️ Museum',
    'park': '🌳 Park',
    'monument': '🗿 Monument',
    'viewpoint': '🌅 Viewpoint',
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 80);
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);

    final place = await widget.placeService.addUserPlace(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      category: _category,
      city: widget.city.name,
      country: widget.city.country,
      latitude: widget.city.centerLat,
      longitude: widget.city.centerLng,
      photo: _photo,
    );

    if (place != null && mounted) {
      widget.onPlaceAdded(place);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${place.name} added!', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      ));
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final txt = isDark ? Colors.white : const Color(0xFF1F2937);

    return DraggableScrollableSheet(
      initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 12, 20, 20), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Add a Place', style: GoogleFonts.playfairDisplay(fontSize: 22, fontWeight: FontWeight.bold, color: txt)),
          Text('in ${widget.city.name}, ${widget.city.country}', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 20),

          // Photo
          GestureDetector(
            onTap: () => _showPhotoOptions(),
            child: Container(
              height: 160, width: double.infinity,
              decoration: BoxDecoration(
                color: _coral.withAlpha(10), borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _coral.withAlpha(40), width: 1.5),
                image: _photo != null ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover) : null,
              ),
              child: _photo == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_a_photo_rounded, size: 36, color: _coral.withAlpha(150)),
                      const SizedBox(height: 8),
                      Text('Add Photo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: _coral.withAlpha(150))),
                    ])
                  : null,
            ),
          ),
          const SizedBox(height: 16),

          // Name
          _field(_nameCtrl, 'Place name *', Icons.place_rounded, txt, isDark),
          const SizedBox(height: 12),

          // Description
          _field(_descCtrl, 'Description (optional)', Icons.notes_rounded, txt, isDark, maxLines: 2),
          const SizedBox(height: 16),

          // Category
          Text('Category', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: txt)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _categories.entries.map((e) {
            final sel = _category == e.key;
            return GestureDetector(
              onTap: () => setState(() => _category = e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? _coral : (isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15)),
                  borderRadius: BorderRadius.circular(12),
                  border: sel ? null : Border.all(color: Colors.grey.withAlpha(30)),
                ),
                child: Text(e.value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : txt)),
              ),
            );
          }).toList()),
          const SizedBox(height: 24),

          // Submit
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _coral, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Add Place', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          )),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, Color txt, bool isDark, {int maxLines = 1}) {
    return TextField(
      controller: ctrl, maxLines: maxLines,
      style: GoogleFonts.inter(fontSize: 14, color: txt),
      decoration: InputDecoration(
        hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey),
        prefixIcon: Icon(icon, color: _coral, size: 20),
        filled: true, fillColor: isDark ? Colors.white.withAlpha(8) : Colors.grey.withAlpha(15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [
      ListTile(
        leading: const Icon(Icons.camera_alt_rounded, color: _coral),
        title: Text('Camera', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
      ),
      ListTile(
        leading: const Icon(Icons.photo_library_rounded, color: _coral),
        title: Text('Gallery', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
      ),
    ])));
  }
}
