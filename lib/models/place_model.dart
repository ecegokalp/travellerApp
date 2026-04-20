class PlaceModel {
  final String id;
  final String name;
  final String? description;
  final String category;
  final double latitude;
  final double longitude;
  String? imageUrl;
  final String? wikidataId;
  double wikidataRating;
  int wikidataSitelinks;
  final double avgRating;
  final int reviewCount;
  final String city;
  final String country;
  final bool isUserGenerated;

  PlaceModel({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.wikidataId,
    this.wikidataRating = 0.0,
    this.wikidataSitelinks = 0,
    this.avgRating = 0.0,
    this.reviewCount = 0,
    required this.city,
    required this.country,
    this.isUserGenerated = false,
  });

  factory PlaceModel.fromOverpassJson(Map<String, dynamic> json, String city, String country) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    final String category;
    if (tags.containsKey('tourism')) {
      category = tags['tourism'] as String;
    } else if (tags.containsKey('historic')) {
      category = tags['historic'] as String;
    } else if (tags.containsKey('man_made')) {
      category = tags['man_made'] as String;
    } else if (tags.containsKey('building') && const ['cathedral', 'church', 'mosque', 'temple', 'synagogue', 'palace', 'castle'].contains(tags['building'])) {
      category = tags['building'] as String;
    } else if (tags.containsKey('amenity')) {
      category = tags['amenity'] as String;
    } else if (tags.containsKey('leisure')) {
      category = tags['leisure'] as String;
    } else {
      category = 'other';
    }

    // node -> lat/lon doğrudan, way/relation -> center altında
    final double lat;
    final double lon;
    if (json.containsKey('lat')) {
      lat = (json['lat'] as num).toDouble();
      lon = (json['lon'] as num).toDouble();
    } else if (json.containsKey('center')) {
      lat = (json['center']['lat'] as num).toDouble();
      lon = (json['center']['lon'] as num).toDouble();
    } else {
      lat = 0;
      lon = 0;
    }

    return PlaceModel(
      id: 'osm_${json['type']}_${json['id']}',
      name: (tags['name'] ?? tags['name:en'] ?? 'Unknown Place') as String,
      description: (tags['description'] ?? tags['description:en']) as String?,
      category: category,
      latitude: lat,
      longitude: lon,
      imageUrl: tags['image'] as String?,
      wikidataId: tags['wikidata'] as String?,
      city: city,
      country: country,
    );
  }

  factory PlaceModel.fromFirestore(Map<String, dynamic> json, String docId) {
    return PlaceModel(
      id: docId,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
      avgRating: (json['avgRating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      city: json['city'] as String,
      country: json['country'] as String,
      isUserGenerated: json['isUserGenerated'] as bool? ?? true,
    );
  }

  /// Efektif rating: kullanıcı puanı varsa onu, yoksa Wikidata popülerlik puanını gösterir
  double get effectiveRating => avgRating > 0 ? avgRating : wikidataRating;

  /// Rating kaynağını gösterir
  String get ratingLabel {
    if (avgRating > 0) return '${avgRating.toStringAsFixed(1)} ($reviewCount)';
    if (wikidataRating > 0) return '${wikidataRating.toStringAsFixed(1)} popularity';
    return '';
  }

  /// Kategori bazlı gerçek fotoğraflar - her mekan farklı ama alakalı
  String get displayImage {
    if (imageUrl != null) return imageUrl!;
    final photos = _stockPhotos[category] ?? _stockPhotos['attraction']!;
    return photos[name.hashCode.abs() % photos.length];
  }

  // Grouped stock photos - similar categories share lists
  static const _cafe = ['https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1521017432531-fbd92d768814?w=600&h=400&fit=crop'];
  static const _restaurant = ['https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1550966871-3ed3cdb51f3a?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1466978913421-dad2ebd01d17?w=600&h=400&fit=crop'];
  static const _bar = ['https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1543007630-9710e4a00a20?w=600&h=400&fit=crop'];
  static const _landmark = ['https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1526129318478-62ed807ebdf9?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1555992336-fb0d29498b13?w=600&h=400&fit=crop'];
  static const _museum = ['https://images.unsplash.com/photo-1554907984-15263bfd63bd?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1566127444979-b3d2b654e3d7?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=600&h=400&fit=crop'];
  static const _nature = ['https://images.unsplash.com/photo-1519331379826-f10be5486c6f?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=600&h=400&fit=crop'];
  static const _castle = ['https://images.unsplash.com/photo-1533154683836-84ea7a0bc310?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=600&h=400&fit=crop'];
  static const _worship = ['https://images.unsplash.com/photo-1555992457-b8fefdd09069?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1548247416-ec66f4900b2e?w=600&h=400&fit=crop'];
  static const _ruins = ['https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=600&h=400&fit=crop','https://images.unsplash.com/photo-1564399580075-5dfe19c205f0?w=600&h=400&fit=crop'];

  static final _stockPhotos = <String, List<String>>{
    'cafe': _cafe, 'ice_cream': _cafe,
    'restaurant': _restaurant,
    'bar': _bar, 'pub': _bar, 'nightclub': _bar,
    'attraction': _landmark, 'monument': _landmark, 'memorial': _landmark, 'tower': _landmark, 'bridge': _landmark, 'lighthouse': _landmark,
    'museum': _museum, 'gallery': _museum, 'artwork': _museum, 'theatre': _museum,
    'viewpoint': _nature, 'park': _nature, 'garden': _nature, 'beach_resort': _nature, 'marina': _nature, 'stadium': _nature,
    'castle': _castle, 'palace': _castle, 'fort': _castle,
    'cathedral': _worship, 'church': _worship, 'mosque': _worship, 'temple': _worship, 'synagogue': _worship, 'place_of_worship': _worship,
    'ruins': _ruins, 'archaeological_site': _ruins,
    'zoo': _landmark, 'theme_park': _landmark,
  };

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'avgRating': avgRating,
      'reviewCount': reviewCount,
      'city': city,
      'country': country,
      'isUserGenerated': isUserGenerated,
    };
  }
}

class CityData {
  final String name;
  final String country;
  final double south;
  final double west;
  final double north;
  final double east;
  final double centerLat;
  final double centerLng;

  const CityData({
    required this.name,
    required this.country,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.centerLat,
    required this.centerLng,
  });

  String get bbox => '$south,$west,$north,$east';
}
