import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_food_image_service.dart';
import 'notification_service.dart';
import 'scan_draft_service.dart';
import 'scan_food_cache_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Complete Sign Out: Firebase Auth + Google Sign In session cleanup
  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Best effort Google sign out
    }
    await _auth.signOut();
  }

  /// Send password reset email to the provided email address
  static Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-email',
        message: 'Please enter your email address.',
      );
    }
    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  /// Change/Update password for currently authenticated user
  /// with re-authentication using current password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No authenticated user found. Please log in again.',
      );
    }

    if (newPassword.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'New password must be at least 6 characters long.',
      );
    }

    // 1. Re-authenticate credentials
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    // 2. Update password
    await user.updatePassword(newPassword);
  }

  /// Permanently deletes the user's account and all associated personal data.
  ///
  /// Steps executed:
  /// 1. Queries and batch-deletes all Firestore subcollections:
  ///    - `food_logs`
  ///    - `workout_logs`
  ///    - `routines`
  ///    - `measurements`
  ///    - `achievements`
  ///    - `favorite_exercises`
  ///    - `daily_logs`
  /// 2. Deletes the parent profile document `users/{uid}`
  /// 3. Clears local device caches (food image files, scan cache, offline drafts)
  /// 4. Cancels all scheduled local notifications
  /// 5. Permanently deletes the Firebase Auth user account
  ///
  /// Throws [FirebaseAuthException] with code `'requires-recent-login'` if re-authentication is required.
  static Future<void> deleteAccountAndUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No authenticated user found. Please log in again.',
      );
    }

    final String uid = user.uid;
    final firestore = FirebaseFirestore.instance;

    // 1. Delete all Firestore subcollections for this user
    final subcollections = [
      'food_logs',
      'workout_logs',
      'routines',
      'measurements',
      'achievements',
      'favorite_exercises',
      'daily_logs',
    ];

    for (final sub in subcollections) {
      try {
        final querySnapshot = await firestore
            .collection('users')
            .doc(uid)
            .collection(sub)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final docs = querySnapshot.docs;
          // Firestore batch write limit is 500 operations
          for (var i = 0; i < docs.length; i += 400) {
            final batch = firestore.batch();
            final end = (i + 400 < docs.length) ? i + 400 : docs.length;
            for (var j = i; j < end; j++) {
              batch.delete(docs[j].reference);
            }
            await batch.commit();
          }
        }
      } catch (e) {
        // Continue cleaning other collections even if one errors
      }
    }

    // 2. Delete parent user profile document
    try {
      await firestore.collection('users').doc(uid).delete();
    } catch (_) {}

    // 3. Clear local on-device caches & files
    try {
      await LocalFoodImageService.instance.clearAllImages();
      await ScanFoodCacheService.instance.clearAllCache();
      await ScanDraftService.instance.clearDraft();
      await NotificationService.instance.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (_) {}

    // 4. Delete Firebase Auth user account
    // This will throw FirebaseAuthException if reauthentication is required
    await user.delete();

    // 5. Google Sign In session cleanup
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  /// Helper to convert FirebaseAuthException code to user-friendly messages
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found registered with this email.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'The password provided is too weak (min 6 characters).';
      case 'requires-recent-login':
        return 'This operation is sensitive and requires recent authentication. Please log in again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes before trying again.';
      case 'network-request-failed':
        return 'Network connection error. Check your internet connection.';
      case 'empty-email':
        return e.message ?? 'Please enter your email address.';
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }
}
