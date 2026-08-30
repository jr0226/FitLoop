import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
