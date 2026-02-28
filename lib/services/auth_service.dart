import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'push_notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Check if a username is already taken
  Future<bool> isUsernameAvailable(String username) async {
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    return snap.docs.isEmpty;
  }

  /// Resolve a username to an email address for login
  Future<String?> resolveUsernameToEmail(String username) async {
    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase().trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data()['email'] as String?;
  }

  /// Sign up with email + password
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Send email verification
    await cred.user?.sendEmailVerification();

    // Create minimal user profile
    final user = UserModel(
      uid: cred.user!.uid,
      email: email,
    );
    await _firestoreService.createUser(user);
    await PushNotificationService.saveToken(cred.user!.uid);
    return cred;
  }

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Check if current session is valid (user exists + not suspended)
  Future<bool> validateSession() async {
    final user = currentUser;
    if (user == null) return false;
    final profile = await _firestoreService.getUser(user.uid);
    if (profile == null) return false;
    if (profile.accountStatus == 'suspended') return false;
    if (profile.accountStatus == 'deleted') return false;
    return true;
  }

  /// Complete user profile after signup/Google login
  Future<void> completeProfile({
    required String uid,
    required String username,
    required String displayName,
    int age = 0,
    String gender = '',
    String bio = '',
  }) async {
    await _firestoreService.updateUser(uid, {
      'username': username.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'age': age,
      'gender': gender,
      'bio': bio,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    final gUser = await _googleSignIn.signIn();
    if (gUser == null) throw Exception('Google sign-in cancelled');

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);

    // Check if user doc exists
    final existingUser = await _firestoreService.getUser(cred.user!.uid);
    if (existingUser == null) {
      final user = UserModel(
        uid: cred.user!.uid,
        email: cred.user!.email ?? '',
        displayName: cred.user!.displayName ?? '',
        profilePicUrl: cred.user!.photoURL ?? '',
      );
      await _firestoreService.createUser(user);
      await PushNotificationService.saveToken(cred.user!.uid);
    } else {
      // Check account status
      if (existingUser.accountStatus == 'suspended') {
        await _auth.signOut();
        throw Exception('Your account has been suspended. Contact support.');
      }
      if (existingUser.accountStatus == 'deleted') {
        await _auth.signOut();
        throw Exception('This account has been deleted.');
      }
      // Track device
      await _trackDevice(existingUser.uid);
      await PushNotificationService.saveToken(existingUser.uid);
    }

    return cred;
  }

  /// Check if user profile is complete (has username set)
  Future<bool> isProfileComplete() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    final user = await _firestoreService.getUser(uid);
    return user != null && user.isProfileComplete;
  }

  /// Login with email + password — with suspension check
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Check account status after auth
    final profile = await _firestoreService.getUser(cred.user!.uid);
    if (profile != null) {
      if (profile.accountStatus == 'suspended') {
        await _auth.signOut();
        throw Exception('Your account has been suspended. Contact support.');
      }
      if (profile.accountStatus == 'deleted') {
        await _auth.signOut();
        throw Exception('This account has been deleted.');
      }
      // Track device
      await _trackDevice(profile.uid);
      await PushNotificationService.saveToken(cred.user!.uid);
    }

    return cred;
  }

  /// Track device ID on login
  Future<void> _trackDevice(String uid) async {
    try {
      final deviceId = '${defaultTargetPlatform.name}_${DateTime.now().millisecondsSinceEpoch}';
      await _firestoreService.updateUser(uid, {
        'deviceIds': FieldValue.arrayUnion([deviceId]),
        'lastLoginAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Device tracking error: $e');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> logout() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await PushNotificationService.removeToken(uid);
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
