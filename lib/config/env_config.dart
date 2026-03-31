import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // Flag to track if dotenv has been loaded
  static bool _dotenvLoaded = false;
  
  /// Load environment variables from the .env file.
  /// Ensure ".env" is added to the assets section of your pubspec.yaml.
  static Future<void> load() async {
    if (_dotenvLoaded) return;
    
    try {
      await dotenv.load(fileName: ".env");
      _dotenvLoaded = true;
      debugPrint('EnvConfig: Configured successfully from .env');
    } catch (e) {
      // In a real app, you might want to show a UI error if this fails
      debugPrint('EnvConfig Error: Could not load .env file: $e');
      _dotenvLoaded = false;
    }
  }

  /// Helper method to retrieve keys and alert you if they are missing
  static String _get(String key) {
    if (!_dotenvLoaded) return '';
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      debugPrint('⚠️ EnvConfig Warning: $key is missing from your .env file');
      return '';
    }
    return value;
  }

  // --- SUPABASE CONFIG ---
  static String get supabaseUrl => _get('SUPABASE_URL');
  static String get supabaseAnonKey => _get('SUPABASE_ANON_KEY');

  // --- EXTERNAL APIS ---
  static String get perenualApiKey => _get('PERENUAL_API_KEY');
  static String get geminiApiKey => _get('GEMINI_API_KEY');

  // --- UTILS ---
  static bool get isProduction => kReleaseMode;
  static bool get isDotenvLoaded => _dotenvLoaded;

static String get plantNetApiKey => _get('PLANTNET_API_KEY');
  static String get plantNetProject {
    final project = _get('PLANTNET_PROJECT');
    return project.isEmpty ? 'all' : project; // Default to 'all' for broad search
  }
}