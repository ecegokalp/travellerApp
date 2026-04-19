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
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);

    // Save/update user data in Firestore
    if (userCredential.user != null) {
      final userDoc = _firestore
          .collection('users')
          .doc(userCredential.user!.uid);

      final docSnapshot = await userDoc.get();
      if (!docSnapshot.exists) {
        await userDoc.set({
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email ?? '',
          'fullName': userCredential.user!.displayName ?? '',
          'username': '',
          'createdAt': FieldValue.serverTimestamp(),
          'photoUrl': userCredential.user!.photoURL ?? '',
        });
      }
    }

    return userCredential;
  }

  /// Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.data();
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
}
