// lib/services/supabase_auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class SupabaseAuthService {
  static SupabaseClient get _client => SupabaseService.client;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String userType,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: {'user_type': userType},
      );
    } on AuthException catch (e) {
      debugPrint('Auth error during sign up: ${e.message}');
      rethrow;
    }
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      debugPrint('Auth error during sign in: ${e.message}');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      debugPrint('Auth error during sign out: ${e.message}');
      rethrow;
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'plantitao://auth-callback',
      );
    } on AuthException catch (e) {
      debugPrint('Auth error during password reset: ${e.message}');
      rethrow;
    }
  }

  static Future<bool> updatePassword(String newPassword) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      throw Exception('No valid session found. Please restart the password reset process.');
    }
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return true;
    } on AuthException catch (e) {
      debugPrint('Auth error updating password: ${e.message}');
      rethrow;
    }
  }
}