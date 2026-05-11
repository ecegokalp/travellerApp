import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Current user
  User? get currentUser => _auth.currentUser;

  /// Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email & password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (credential.user != null) {
      await _ensureUserDoc(credential.user!);
    }

    return credential;
  }

  /// Create account with email & password and save profile to Firestore
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
  }) async {
    debugPrint('DEBUG: signUp metodu tetiklendi. Email: $email');
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('DEBUG: FirebaseAuth hesabı oluşturuldu: ${credential.user?.uid}');

      if (credential.user != null) {
        debugPrint('DEBUG: Firestore\'a yazılıyor...');
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'fullName': fullName,
          'username': username,
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': '',
          'followerCount': 0,
          'followingCount': 0,
        });
        debugPrint('DEBUG: Firestore kaydı başarılı!');
        await credential.user!.updateDisplayName(fullName);
      }
      return credential;
    } catch (e) {
      debugPrint('DEBUG: AuthService signUp Hatası: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('DEBUG: Google Sign-In starting...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('DEBUG: Google Sign-In cancelled.');
        return null;
      }

      debugPrint('DEBUG: Google user retrieved: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('DEBUG: accessToken: ${googleAuth.accessToken != null}, idToken: ${googleAuth.idToken != null}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('DEBUG: Firebase signed in: ${userCredential.user?.uid}');

      if (userCredential.user != null) {
        await _ensureUserDoc(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint('DEBUG: Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
  }

  Future<void> _ensureUserDoc(User user) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();

    final baseData = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!snap.exists) {
      await ref.set({
        ...baseData,
        'fullName': user.displayName ?? '',
        'username': '',
        'createdAt': FieldValue.serverTimestamp(),
        'followerCount': 0,
        'followingCount': 0,
      });
      return;
    }

    await ref.set(baseData, SetOptions(merge: true));

    final currentFullName = (snap.data()?['fullName'] ?? '').toString().trim();
    final authDisplayName = (user.displayName ?? '').trim();
    if (currentFullName.isEmpty && authDisplayName.isNotEmpty) {
      await ref.set({'fullName': authDisplayName}, SetOptions(merge: true));
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Save a trip to Firestore
  Future<void> saveTrip(Map<String, String> trip) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_trips')
        .add({
      ...trip,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get saved trips from Firestore
  Stream<QuerySnapshot> getSavedTrips() {
    final user = currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_trips')
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  /// Delete a saved trip
  Future<void> deleteSavedTrip(String docId) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_trips')
        .doc(docId)
        .delete();
  }

  // --- Follow Feature ---

  Future<void> followUser(String targetUid) async {
    final myUid = currentUser?.uid;
    if (myUid == null || myUid == targetUid) return;

    final batch = _firestore.batch();

    // Add to my following
    batch.set(
      _firestore.collection('users').doc(myUid).collection('following').doc(targetUid),
      {'timestamp': FieldValue.serverTimestamp()},
    );

    // Add to target's followers
    batch.set(
      _firestore.collection('users').doc(targetUid).collection('followers').doc(myUid),
      {'timestamp': FieldValue.serverTimestamp()},
    );

    // Update counts
    batch.update(_firestore.collection('users').doc(myUid), {
      'followingCount': FieldValue.increment(1),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followerCount': FieldValue.increment(1),
    });

    await batch.commit();
  }

  Future<void> unfollowUser(String targetUid) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    final batch = _firestore.batch();

    // Remove from my following
    batch.delete(_firestore.collection('users').doc(myUid).collection('following').doc(targetUid));

    // Remove from target's followers
    batch.delete(_firestore.collection('users').doc(targetUid).collection('followers').doc(myUid));

    // Update counts
    batch.update(_firestore.collection('users').doc(myUid), {
      'followingCount': FieldValue.increment(-1),
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'followerCount': FieldValue.increment(-1),
    });

    await batch.commit();
  }

  Stream<bool> isFollowing(String targetUid) {
    final myUid = currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Search users by username
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    
    final snap = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snap.docs.map((doc) => doc.data()).toList();
  }

  /// Get suggested users (random or recent)
  Future<List<Map<String, dynamic>>> getSuggestedUsers() async {
    final snap = await _firestore
        .collection('users')
        .limit(10)
        .get();

    final myUid = currentUser?.uid;
    return snap.docs
        .map((doc) => doc.data())
        .where((user) => user['uid'] != myUid)
        .toList();
  }

  /// Get all blogs from all users (Community Feed)
  Stream<QuerySnapshot> getCommunityFeed() {
    return _firestore
        .collectionGroup('blogs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get blogs only from users I follow
  Stream<QuerySnapshot> getFollowingFeed(List<String> followingIds) {
    if (followingIds.isEmpty) {
      // Return an empty stream or a specific way to handle no followers
      return _firestore.collectionGroup('blogs').where('authorId', isEqualTo: 'NON_EXISTENT').snapshots();
    }
    
    // Firestore whereIn limit is 30 (previously 10). 
    // For more complex feeds, a different architecture is needed.
    return _firestore
        .collectionGroup('blogs')
        .where('authorId', whereIn: followingIds.take(30).toList())
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Get followers of a user
  Stream<QuerySnapshot> getFollowers(String uid) {
    return _firestore.collection('users').doc(uid).collection('followers').snapshots();
  }

  /// Get following of a user
  Stream<QuerySnapshot> getFollowing(String uid) {
    return _firestore.collection('users').doc(uid).collection('following').snapshots();
  }

  /// Get list of UIDs the user is following
  Stream<List<String>> getFollowingUids(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  // --- Like & Comment Feature ---

  Future<void> toggleLike(String authorId, String blogId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(authorId)
        .collection('blogs')
        .doc(blogId);

    final likeRef = docRef.collection('likes').doc(myUid);
    final likeDoc = await likeRef.get();

    final batch = _firestore.batch();

    if (likeDoc.exists) {
      batch.delete(likeRef);
      batch.update(docRef, {'likeCount': FieldValue.increment(-1)});
    } else {
      batch.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
      batch.update(docRef, {'likeCount': FieldValue.increment(1)});
    }

    await batch.commit();
  }

  Stream<bool> isLiked(String authorId, String blogId) {
    final myUid = currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(authorId)
        .collection('blogs')
        .doc(blogId)
        .collection('likes')
        .doc(myUid)
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<bool> isLikedOnce(String authorId, String blogId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return false;

    final snap = await _firestore
        .collection('users')
        .doc(authorId)
        .collection('blogs')
        .doc(blogId)
        .collection('likes')
        .doc(myUid)
        .get();
    return snap.exists;
  }

  Future<void> addComment(String authorId, String blogId, String text) async {
    final myUid = currentUser?.uid;
    if (myUid == null || text.trim().isEmpty) return;

    final userDoc = await getUserProfile(myUid);

    final docRef = _firestore
        .collection('users')
        .doc(authorId)
        .collection('blogs')
        .doc(blogId);

    await _firestore.runTransaction((transaction) async {
      transaction.set(docRef.collection('comments').doc(), {
        'uid': myUid,
        'username': userDoc?['username'] ?? 'Traveller',
        'fullName': userDoc?['fullName'] ?? 'Traveller',
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(docRef, {'commentCount': FieldValue.increment(1)});
    });
  }

  Stream<QuerySnapshot> getComments(String authorId, String blogId) {
    return _firestore
        .collection('users')
        .doc(authorId)
        .collection('blogs')
        .doc(blogId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // --- Blog Edit/Delete Feature ---

  Future<void> deleteBlog(String blogId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('blogs')
        .doc(blogId)
        .delete();
  }

  Future<void> updateBlog(String blogId, Map<String, dynamic> data) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('blogs')
        .doc(blogId)
        .update(data);
  }

  // --- Blog Save/Bookmark Feature ---

  Future<void> saveBlog(String authorId, String blogId, Map<String, dynamic> blogData) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('saved_blogs')
        .doc('${authorId}_$blogId')
        .set({
      'authorId': authorId,
      'blogId': blogId,
      'authorName': blogData['authorName'] ?? '',
      'authorPhotoUrl': blogData['authorPhotoUrl'] ?? '',
      'content': blogData['content'] ?? '',
      'imageUrl': blogData['imageUrl'],
      'city': blogData['city'] ?? '',
      'country': blogData['country'] ?? '',
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unsaveBlog(String authorId, String blogId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return;

    await _firestore
        .collection('users')
        .doc(myUid)
        .collection('saved_blogs')
        .doc('${authorId}_$blogId')
        .delete();
  }

  Stream<bool> isBlogSaved(String authorId, String blogId) {
    final myUid = currentUser?.uid;
    if (myUid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(myUid)
        .collection('saved_blogs')
        .doc('${authorId}_$blogId')
        .snapshots()
        .map((snap) => snap.exists);
  }

  Future<bool> isBlogSavedOnce(String authorId, String blogId) async {
    final myUid = currentUser?.uid;
    if (myUid == null) return false;

    final snap = await _firestore
        .collection('users')
        .doc(myUid)
        .collection('saved_blogs')
        .doc('${authorId}_$blogId')
        .get();
    return snap.exists;
  }

  Future<void> updateProfilePicture(String url) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({'photoUrl': url});
    await user.updatePhotoURL(url);
  }

  Future<void> updateUsername(String username) async {
    final user = currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({'username': username});
  }
}
