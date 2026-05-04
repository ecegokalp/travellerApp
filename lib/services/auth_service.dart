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
}
