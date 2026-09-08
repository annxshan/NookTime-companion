import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gapis;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/database_service.dart';
import '../../sync/services/cloud_sync_service.dart';

/// Service managing OAuth2 authentication via Google Sign-In (v7.2+) and
/// providing authenticated HTTP clients for Google APIs and Cloud Sync.
///
/// Extends [ChangeNotifier] so UI widgets reactively rebuild whenever
/// sign-in state or cloud sync hydration completes.
class AuthService extends ChangeNotifier {
  static const String _prefKeyIsSignedIn = 'is_google_signed_in';
  static const String _prefKeyUserEmail = 'user_email';
  static const String _prefKeyDisplayName = 'user_display_name';
  static const String _prefKeyPhotoUrl = 'user_photo_url';

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar',
    'https://www.googleapis.com/auth/calendar.events',
  ];

  final GoogleSignIn _googleSignIn;
  final DatabaseService? _databaseService;
  final CloudSyncService? _cloudSyncService;

  GoogleSignInAccount? _currentUser;
  bool _isSessionRestored = false;
  bool _isExplicitSignOut = false;
  String? _cachedEmail;
  String? _cachedDisplayName;
  String? _cachedPhotoUrl;

  late final ValueNotifier<GoogleSignInAccount?> currentUserNotifier;

  AuthService({
    GoogleSignIn? googleSignIn,
    DatabaseService? databaseService,
    CloudSyncService? cloudSyncService,
  })  : _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _databaseService = databaseService,
        _cloudSyncService = cloudSyncService {
    currentUserNotifier = ValueNotifier<GoogleSignInAccount?>(_currentUser);

    // Listen only for sign-out events from the Google Sign-In SDK.
    // SignIn events are intentionally NOT processed here to prevent the SDK
    // from auto-signing the user in at startup via Google Play Services.
    // All sign-in logic is handled explicitly via signIn() (user-initiated)
    // and initSilentSignIn() (silent restore for returning users only).
    _googleSignIn.authenticationEvents.listen((event) async {
      if (event is GoogleSignInAuthenticationEventSignOut) {
        _currentUser = null;
        currentUserNotifier.value = null;
        if (_isExplicitSignOut) {
          await _signOutFromFirebaseAuth();
          await _saveSignInState(false);
          notifyListeners();
        }
      }
    });
  }

  /// Currently signed-in Google account, or `null` if unauthenticated.
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Cached user email for display when offline or before token refresh.
  String? get cachedEmail => _currentUser?.email ?? _cachedEmail;

  /// Cached user display name.
  String? get cachedDisplayName => _currentUser?.displayName ?? _cachedDisplayName;

  /// Cached user photo URL.
  String? get cachedPhotoUrl => _currentUser?.photoUrl ?? _cachedPhotoUrl;

  /// Stream listening to user sign-in state changes.
  Stream<GoogleSignInAccount?> get onCurrentUserChanged async* {
    yield _currentUser;
    await for (final event in _googleSignIn.authenticationEvents) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        yield event.user;
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        yield null;
      }
    }
  }

  /// Returns `true` if a user is currently signed in or has a persistent restored session.
  bool get isSignedIn {
    if (_currentUser != null || _isSessionRestored) return true;
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Initializes the Google Sign-In SDK. Must be called before authentication.
  Future<void> initialize({String? clientId, String? serverClientId}) async {
    await _googleSignIn.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  /// Exchanges Google Sign-In credentials for a Firebase Auth session.
  /// This is required so Firestore security rules (request.auth.uid) pass.
  /// Note: google_sign_in v7.x `authentication` is a synchronous getter;
  /// `idToken` alone is sufficient for Firebase Auth credential.
  Future<void> _signInToFirebaseAuth(GoogleSignInAccount account) async {
    try {
      final googleAuth = account.authentication; // synchronous in v7.x, no await
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Firebase Auth sign-in notice: $e');
    }
  }

  /// Signs out of Firebase Auth, clearing the Firestore auth session.
  Future<void> _signOutFromFirebaseAuth() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('Firebase Auth sign-out notice: $e');
    }
  }

  /// Helper to persist sign-in state and user info in SharedPreferences.
  Future<void> _saveSignInState(bool isSignedIn, [GoogleSignInAccount? user]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyIsSignedIn, isSignedIn);
      if (isSignedIn) {
        _isSessionRestored = true;
        if (user != null) {
          _cachedEmail = user.email;
          _cachedDisplayName = user.displayName;
          _cachedPhotoUrl = user.photoUrl;

          await prefs.setString(_prefKeyUserEmail, user.email);
          if (user.displayName != null) {
            await prefs.setString(_prefKeyDisplayName, user.displayName!);
          }
          if (user.photoUrl != null) {
            await prefs.setString(_prefKeyPhotoUrl, user.photoUrl!);
          }
        }
      } else {
        _isSessionRestored = false;
        _cachedEmail = null;
        _cachedDisplayName = null;
        _cachedPhotoUrl = null;

        await prefs.remove(_prefKeyUserEmail);
        await prefs.remove(_prefKeyDisplayName);
        await prefs.remove(_prefKeyPhotoUrl);
      }
    } catch (_) {}
  }

  /// Triggers full cloud synchronization and backup-and-restore pipeline using [CloudSyncService].
  /// Checks if cloud data exists for current user, executes restoreFromCloud(), merges local tasks, and notifies listeners.
  Future<void> syncCloudRoutines() async {
    final cloud = _cloudSyncService ?? CloudSyncService();
    final db = _databaseService;
    if (isSignedIn) {
      try {
        final cloudDataExists = await cloud.hasCloudData();
        if (cloudDataExists) {
          await cloud.restoreFromCloud();
        } else {
          await cloud.restoreUserDataFromCloud(databaseService: db);
        }
        await cloud.backupToCloud();
        notifyListeners();
      } catch (e) {
        debugPrint('Cloud sync error on login: $e');
      }
    }
  }

  /// Restores persistent user session from SharedPreferences on app startup.
  /// Auto-fetches and hydrates routines from Cloud Firestore when session is restored.
  Future<GoogleSignInAccount?> initSilentSignIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasSignedIn = prefs.getBool(_prefKeyIsSignedIn) ?? false;
      final firebaseUser = FirebaseAuth.instance.currentUser;

      if (wasSignedIn || firebaseUser != null) {
        _isSessionRestored = true;
        _cachedEmail = prefs.getString(_prefKeyUserEmail) ?? firebaseUser?.email;
        _cachedDisplayName = prefs.getString(_prefKeyDisplayName) ?? firebaseUser?.displayName;
        _cachedPhotoUrl = prefs.getString(_prefKeyPhotoUrl) ?? firebaseUser?.photoURL;

        // Attempt lightweight re-auth to restore the Google account object.
        try {
          final account = await _googleSignIn.attemptLightweightAuthentication();
          if (account != null) {
            _currentUser = account;
            currentUserNotifier.value = account;
            await _signInToFirebaseAuth(account);
          }
        } catch (_) {}

        await syncCloudRoutines();
        notifyListeners();
      }
      return _currentUser;
    } catch (e) {
      debugPrint('Session restore notice: $e');
      return _currentUser;
    }
  }

  /// Alias for [initSilentSignIn].
  Future<GoogleSignInAccount?> signInSilently() => initSilentSignIn();

  /// Initiates interactive Google Sign-In flow.
  /// Auto-restores routines from Cloud Firestore upon successful login.
  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.authenticate(scopeHint: scopes);
      _currentUser = account;
      currentUserNotifier.value = account;
      await _signInToFirebaseAuth(account);
      await _saveSignInState(true, account);
      await syncCloudRoutines();
      notifyListeners();
      return account;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs out the current user and clears local cached credentials without deleting offline tasks.
  Future<void> signOut() async {
    _isExplicitSignOut = true;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _signOutFromFirebaseAuth();
    _currentUser = null;
    currentUserNotifier.value = null;
    await _saveSignInState(false);
    _isExplicitSignOut = false;
    notifyListeners();
  }

  /// Obtains an authenticated [gapis.AuthClient] to construct `googleapis` services.
  Future<gapis.AuthClient> getAuthenticatedClient() async {
    var account = _currentUser;
    if (account == null) {
      account = await _googleSignIn.attemptLightweightAuthentication();
      if (account != null) {
        _currentUser = account;
        currentUserNotifier.value = account;
      }
    }

    if (account == null) {
      throw StateError('Cannot acquire auth client: User is not signed in.');
    }

    final clientAuth =
        await account.authorizationClient.authorizeScopes(scopes);
    return clientAuth.authClient(scopes: scopes);
  }
}
