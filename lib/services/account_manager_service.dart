import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/saved_account.dart';
import 'firestore_service.dart';
import 'cache_service.dart';
import 'push_notification_service.dart';

class AccountManagerService {
  static const _storageKey = 'saved_accounts';
  static const _passwordPrefix = 'account_pwd_';
  static const int maxAccounts = 5;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  /// Get all saved accounts
  Future<List<SavedAccount>> getSavedAccounts() async {
    final json = await _storage.read(key: _storageKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((m) => SavedAccount.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  /// Save an account after successful login
  Future<void> saveAccount({
    required String uid,
    required String email,
    required String password,
    String displayName = '',
    String profilePicUrl = '',
  }) async {
    final accounts = await getSavedAccounts();

    // Remove existing entry for this uid (to update it)
    accounts.removeWhere((a) => a.uid == uid);

    // Enforce max accounts
    if (accounts.length >= maxAccounts) {
      throw Exception(
        'Maximum $maxAccounts accounts reached. Remove one first.',
      );
    }

    accounts.add(
      SavedAccount(
        uid: uid,
        email: email,
        displayName: displayName,
        profilePicUrl: profilePicUrl,
      ),
    );

    // Save account list
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(accounts.map((a) => a.toMap()).toList()),
    );

    // Save password securely
    await _storage.write(key: '$_passwordPrefix$uid', value: password);
  }

  /// Remove a saved account
  Future<void> removeAccount(String uid) async {
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.uid == uid);
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(accounts.map((a) => a.toMap()).toList()),
    );
    await _storage.delete(key: '$_passwordPrefix$uid');
  }

  /// Switch to a different saved account
  Future<void> switchAccount(String uid) async {
    // Skip if already on this account
    if (_auth.currentUser?.uid == uid) return;

    final accounts = await getSavedAccounts();
    final account = accounts.firstWhere(
      (a) => a.uid == uid,
      orElse: () => throw Exception('Account not found'),
    );

    final password = await _storage.read(key: '$_passwordPrefix$uid');
    if (password == null) {
      throw Exception('Credentials not found. Please re-login.');
    }

    // Remove FCM token from current account before switching
    final oldUid = _auth.currentUser?.uid;
    if (oldUid != null) {
      await PushNotificationService.removeToken(oldUid);
    }

    // Clear all in-memory and disk caches before switching
    CacheService.instance.clearAll();
    await CacheService.instance.clearDiskCache();

    // Get new credential FIRST, then sign in (replaces current Firebase session)
    // Do NOT call _auth.signOut() beforehand — signInWithCredential and
    // signInWithEmailAndPassword automatically replace the active session.
    if (password == '__google__') {
      await _switchToGoogleAccount(account);
    } else {
      await _auth.signInWithEmailAndPassword(
        email: account.email,
        password: password,
      );
    }

    // Save FCM token to the new account
    await PushNotificationService.saveToken(uid);
  }

  Future<void> _switchToGoogleAccount(SavedAccount account) async {
    final gSignIn = GoogleSignIn();

    // Step 1: Try silent sign-in (no UI) — uses cached Google session
    GoogleSignInAccount? gUser = await gSignIn.signInSilently();

    if (gUser != null && gUser.email == account.email) {
      // Cached session matches target — sign in silently with no picker
      final gAuth = await gUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      return;
    }

    // Step 2: Cached session is wrong account or null — show picker
    // Do NOT call gSignIn.signOut() here — that would destroy the cache
    // for the currently cached account too. Just open the picker directly.
    gUser = await gSignIn.signIn();

    if (gUser == null) throw Exception('Google sign-in cancelled');
    if (gUser.email != account.email) {
      // User picked the wrong account — clean up and error
      await gSignIn.signOut();
      throw Exception('Please select the correct account (${account.email})');
    }

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  /// Update account display info (call after profile loads)
  Future<void> updateAccountInfo(String uid) async {
    final user = await _firestore.getUser(uid);
    if (user == null) return;

    final accounts = await getSavedAccounts();
    final index = accounts.indexWhere((a) => a.uid == uid);
    if (index == -1) return;

    accounts[index] = SavedAccount(
      uid: uid,
      email: accounts[index].email,
      displayName: user.displayName,
      profilePicUrl: user.profilePicUrl,
    );

    await _storage.write(
      key: _storageKey,
      value: jsonEncode(accounts.map((a) => a.toMap()).toList()),
    );
  }

  /// Get current user's uid
  String? get currentUid => _auth.currentUser?.uid;
}
