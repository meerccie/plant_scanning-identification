// lib/config/env_config.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Fallback values if env file can't be loaded
  static const String _fallbackUrl = 'https://cnckiqzooevhlggglonh.supabase.co';
  static const String _fallbackAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuY2tpcXpvb2V2aGxnZ2dsb25oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5MjI5NDksImV4cCI6MjA3MTQ5ODk0OX0.ARvH80x-B2uJIhXpxCURBMelToqLsW4VKQDY4-ZbVZ0';
  
  // Flag to track if dotenv has been loaded
  static bool _dotenvLoaded = false;
  
  // Load environment variables
  static Future<void> load() async {
    if (_dotenvLoaded) return;
    
    try {
      // UPDATED: Changed "my.env" to ".env"
      await dotenv.load(fileName: ".env");
      _dotenvLoaded = true;
      debugPrint('EnvConfig: Environment variables loaded from .env');
    } catch (e) {
      debugPrint('EnvConfig: Could not load .env file: $e');
      debugPrint('EnvConfig: Using fallback configuration');
      _dotenvLoaded = false;
    }
  }
  
  static String get supabaseUrl {
    if (_dotenvLoaded) {
      return dotenv.env['SUPABASE_URL'] ?? _fallbackUrl;
    }
    return _fallbackUrl;
  }

  static String get supabaseAnonKey {
    if (_dotenvLoaded) {
      return dotenv.env['SUPABASE_ANON_KEY'] ?? _fallbackAnonKey;
    }
    return _fallbackAnonKey;
  }

  static String get supabaseServiceRoleKey {
    if (_dotenvLoaded) {
      return dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
    }
    return '';
  }

  // Perenual API Key configuration
  static String get perenualApiKey {
    if (_dotenvLoaded) {
      return dotenv.env['PERENUAL_API_KEY'] ?? '';
    }
    return '';
  }

  // Trefle key is kept for reference
  static String get trefleApiKey {
    if (_dotenvLoaded) {
      return dotenv.env['TREFLE_API_KEY'] ?? '';
    }
    return '';
  }
  
  // ADDED: Gemini API Key for AI features
  static String get geminiApiKey {
    if (_dotenvLoaded) {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    }
    return '';
  }
  
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');
  static bool get isDotenvLoaded => _dotenvLoaded;
}

