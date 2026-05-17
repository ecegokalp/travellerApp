import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';
import '../models/review_model.dart';

// Top-level function for isolate JSON parsing
List<Map<String, dynamic>> _parseOverpassResponse(String body) {
  final data = json.decode(body);
  final elements = data['elements'] as List;
  return elements.cast<Map<String, dynamic>>();
}

class PlaceService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  // Search cities using Nominatim (any city worldwide)
  Future<List<CityData>> searchCities(String query) async {
    if (query.trim().length < 2) return [];

    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json'
          '&featuretype=city'
          '&limit=8'
          '&addressdetails=1',
        ),
        headers: {'User-Agent': 'WanderApp/1.0'},
      );

      if (response.statusCode != 200) return [];

      final List results = json.decode(response.body);
      return results.map((r) {
        final bbox = r['boundingbox'] as List;
        final lat = double.parse(r['lat']);
        final lon = double.parse(r['lon']);
        final address = r['address'] as Map<String, dynamic>? ?? {};
        final country = address['country'] as String? ?? '';

        return CityData(
          name: r['display_name'].toString().split(',').first.trim(),
          country: country,
          south: double.parse(bbox[0]),
          north: double.parse(bbox[1]),
          west: double.parse(bbox[2]),
          east: double.parse(bbox[3]),
          centerLat: lat,
          centerLng: lon,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Callback to notify UI when Wikidata info finishes loading in background
  VoidCallback? onWikidataLoaded;

  // Fetch places from Overpass API
  Future<List<PlaceModel>> fetchPlacesFromOverpass(CityData city) async {
    final query = '''
[out:json][timeout:30];
(
  nwr["tourism"~"attraction|museum|viewpoint|artwork|gallery|zoo|theme_park"](${city.bbox});
  nwr["historic"~"monument|castle|memorial|ruins|archaeological_site|fort|church|palace|building"](${city.bbox});
  nwr["man_made"~"tower|bridge|lighthouse"](${city.bbox});
  nwr["building"~"cathedral|church|mosque|temple|synagogue|palace|castle"](${city.bbox});
  nwr["amenity"~"place_of_worship|theatre|cinema"]["wikidata"](${city.bbox});
  nwr["amenity"~"cafe|restaurant|bar|pub|nightclub|ice_cream"](${city.bbox});
  nwr["leisure"~"park|garden|marina|beach_resort|stadium"](${city.bbox});
);
out center 150;
''';

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        headers: {
          'User-Agent': 'WanderApp/1.0',
          'Accept': '*/*',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'data=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) return [];

      // Parse JSON in isolate to avoid blocking UI thread
      final elements = await compute(_parseOverpassResponse, response.body);

      final places = elements
          .where((e) {
            final tags = e['tags'] as Map<String, dynamic>?;
            if (tags == null || (tags['name'] == null && tags['name:en'] == null)) return false;
            return true;
          })
          .map((e) => PlaceModel.fromOverpassJson(e, city.name, city.country))
          .toList();

      // Return places immediately, fetch Wikidata in background
      _fetchWikidataInBackground(places);

      return places;
    } catch (_) {
      return [];
    }
  }

  // Fetch Wikidata info without blocking - UI updates when done
  void _fetchWikidataInBackground(List<PlaceModel> places) {
    _fetchWikidataInfo(places).then((_) {
      // Sort after wikidata loads
      places.sort((a, b) => b.wikidataSitelinks.compareTo(a.wikidataSitelinks));
      onWikidataLoaded?.call();
    }).catchError((_) {});
  }

  // Batch fetch images + popularity rating from Wikidata API
  Future<void> _fetchWikidataInfo(List<PlaceModel> places) async {
    final placesWithWikidata = places.where((p) => p.wikidataId != null).toList();
    if (placesWithWikidata.isEmpty) return;

    for (var i = 0; i < placesWithWikidata.length; i += 50) {
      final batch = placesWithWikidata.skip(i).take(50).toList();
      final ids = batch.map((p) => p.wikidataId!).join('|');

      try {
        final response = await http.get(
          Uri.parse(
            'https://www.wikidata.org/w/api.php'
            '?action=wbgetentities'
            '&ids=$ids'
            '&props=claims|sitelinks'
            '&format=json'
            '&origin=*',
          ),
          headers: {'User-Agent': 'WanderApp/1.0'},
        );

        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final entities = data['entities'] as Map<String, dynamic>? ?? {};

        for (final place in batch) {
          final entity = entities[place.wikidataId] as Map<String, dynamic>?;
          if (entity == null) continue;

          // Image from P18
          final claims = entity['claims'] as Map<String, dynamic>? ?? {};
          final imagesClaim = claims['P18'] as List?;
          if (imagesClaim != null && imagesClaim.isNotEmpty && place.imageUrl == null) {
            final mainsnak = imagesClaim[0]['mainsnak'] as Map<String, dynamic>?;
            final filename = mainsnak?['datavalue']?['value'] as String?;
            if (filename != null) {
              place.imageUrl = 'https://commons.wikimedia.org/wiki/Special:FilePath/${filename.replaceAll(' ', '_')}?width=600';
            }
          }

          // Rating from sitelinks count (more Wikipedia articles = more popular)
          final sitelinks = entity['sitelinks'] as Map<String, dynamic>? ?? {};
          final linkCount = sitelinks.length;
          // 1-5 scale: 1-5 links=2.5, 6-15=3.0, 16-30=3.5, 31-60=4.0, 61-100=4.5, 100+=5.0
          if (place.avgRating == 0 && linkCount > 0) {
            double rating;
            if (linkCount > 100) {
              rating = 5.0;
            } else if (linkCount > 60) {
              rating = 4.5;
            } else if (linkCount > 30) {
              rating = 4.0;
            } else if (linkCount > 15) {
              rating = 3.5;
            } else if (linkCount > 5) {
              rating = 3.0;
            } else {
              rating = 2.5;
            }
            place.wikidataRating = rating;
            place.wikidataSitelinks = linkCount;
          }
        }
      } catch (_) {}
    }
  }

  Future<List<PlaceModel>> fetchUserPlaces(String city) async {
    try {
      final snapshot = await _firestore
          .collection('places')
          .where('city', isEqualTo: city)
          .where('isUserGenerated', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<PlaceModel>> getPlacesForCity(CityData city) async {
    final results = await Future.wait([
      fetchPlacesFromOverpass(city),
      fetchUserPlaces(city.name),
    ]);
    return [...results[0], ...results[1]];
  }

  Future<void> likePlace(PlaceModel place) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_places')
        .doc(place.id)
        .set({
      'name': place.name,
      'category': place.category,
      'city': place.city,
      'country': place.country,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'imageUrl': place.imageUrl,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unlikePlace(String placeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_places')
        .doc(placeId)
        .delete();
  }

  Stream<List<Map<String, dynamic>>> getLikedPlacesStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_places')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  Future<List<ReviewModel>> getReviews(String placeId) async {
    try {
      final snapshot = await _firestore
          .collection('places')
          .doc(placeId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => ReviewModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addReview(String placeId, double rating, String comment) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('places')
        .doc(placeId)
        .collection('reviews')
        .add({
      'userId': user.uid,
      'userName': user.displayName ?? 'Anonymous',
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final reviewsSnap = await _firestore
        .collection('places')
        .doc(placeId)
        .collection('reviews')
        .get();

    if (reviewsSnap.docs.isNotEmpty) {
      double total = 0;
      for (final doc in reviewsSnap.docs) {
        total += (doc.data()['rating'] as num).toDouble();
      }
      final avg = total / reviewsSnap.docs.length;

      await _firestore.collection('places').doc(placeId).set({
        'avgRating': avg,
        'reviewCount': reviewsSnap.docs.length,
      }, SetOptions(merge: true));
    }
  }

  // Upload place photo to Firebase Storage
  Future<String?> uploadPlacePhoto(File photo) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage.ref('place_photos/$uid/$ts.jpg');
      await ref.putFile(photo);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  // Add a user-created place
  Future<PlaceModel?> addUserPlace({
    required String name,
    required String category,
    required String city,
    required String country,
    required double latitude,
    required double longitude,
    String? description,
    File? photo,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    String? photoUrl;
    if (photo != null) {
      photoUrl = await uploadPlacePhoto(photo);
    }

    final doc = await _firestore.collection('places').add({
      'name': name,
      'description': description,
      'category': category,
      'city': city,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': photoUrl,
      'avgRating': 0.0,
      'reviewCount': 0,
      'isUserGenerated': true,
      'createdBy': user.uid,
      'createdByName': user.displayName ?? 'Anonymous',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return PlaceModel(
      id: doc.id,
      name: name,
      description: description,
      category: category,
      latitude: latitude,
      longitude: longitude,
      imageUrl: photoUrl,
      city: city,
      country: country,
      isUserGenerated: true,
    );
  }
}
