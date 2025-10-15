// lib/services/supabase_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

class SupabaseService {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('Supabase not initialized. Call SupabaseService.initialize() first.');
    }
    return Supabase.instance.client;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await EnvConfig.load();
      final url = EnvConfig.supabaseUrl;
      final anonKey = EnvConfig.supabaseAnonKey;

      if (url.isEmpty || anonKey.isEmpty) {
        throw Exception('Supabase credentials are not configured');
      }

      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: kDebugMode,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialization failed: $e');
      rethrow;
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  static User? get currentUser {
    return _isInitialized ? client.auth.currentUser : null;
  }
}