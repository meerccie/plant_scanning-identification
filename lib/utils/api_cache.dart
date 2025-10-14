// lib/utils/api_cache.dart
import 'dart:async';

class ApiCache {
  static final ApiCache _instance = ApiCache._internal();
  factory ApiCache() => _instance;
  ApiCache._internal();

  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  
  // Maximum number of entries to hold in the cache
  static const int _maxCacheSize = 100;

  // Cache durations for different data types
  static const Duration _plantDetailsCacheDuration = Duration(hours: 24);
  static const Duration _plantSearchCacheDuration = Duration(hours: 6);
  static const Duration _dailyGuideCacheDuration = Duration(hours: 12);
  // ADDED: Cache duration for plant scan results
  static const Duration _plantScanCacheDuration = Duration(hours: 1);

  // Rate limiting
  DateTime? _lastRequestTime;
  final Duration _minRequestInterval = const Duration(seconds: 2);

  dynamic get(String key) {
    _cleanExpiredEntries(); // Periodically clean up
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null && DateTime.now().difference(timestamp) < _getCacheDuration(key)) {
      return _cache[key];
    }
    
    // If not found or expired, ensure it's removed
    _cache.remove(key);
    _cacheTimestamps.remove(key);
    return null;
  }

  void set(String key, dynamic value) {
    // Before adding a new entry, clean up and manage cache size
    _cleanExpiredEntries();
    if (_cache.length >= _maxCacheSize) {
      _removeOldestEntry();
    }

    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  // --- Specific Cache Management Methods ---
  
  // Keys now include versioning to easily invalidate old cache structures
  void setPlantDetails(String plantId, dynamic value) => set('details_v1_$plantId', value);
  dynamic getPlantDetails(String plantId) => get('details_v1_$plantId');
  
  void setPlantSearch(String query, List<dynamic> results) => set('search_v1_${query.toLowerCase()}', results);
  List<dynamic>? getPlantSearch(String query) => get('search_v1_${query.toLowerCase()}');

  void setDailyGuide(String dateKey, Map<String, dynamic> guide) => set('daily_guide_v1_$dateKey', guide);
  Map<String, dynamic>? getDailyGuide(String dateKey) => get('daily_guide_v1_$dateKey');

  // ADDED: Methods for caching plant scanner results.
  // The 'imageHash' would be a unique identifier generated from the image file's content (e.g., a SHA256 hash)
  // before making the API call in your plant_scanner_service.dart.
  void setPlantScan(String imageHash, dynamic value) => set('scan_v1_$imageHash', value);
  dynamic getPlantScan(String imageHash) => get('scan_v1_$imageHash');

  // --- Cache Maintenance ---

  void _cleanExpiredEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];
    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) >= _getCacheDuration(entry.key)) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  void _removeOldestEntry() {
    if (_cacheTimestamps.isEmpty) return;

    // Find the oldest entry by sorting the timestamps
    final sortedEntries = _cacheTimestamps.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
      
    final oldestKey = sortedEntries.first.key;
    _cache.remove(oldestKey);
    _cacheTimestamps.remove(oldestKey);
  }

  Duration _getCacheDuration(String key) {
    if (key.startsWith('details_')) return _plantDetailsCacheDuration;
    if (key.startsWith('search_')) return _plantSearchCacheDuration;
    if (key.startsWith('daily_guide_')) return _dailyGuideCacheDuration;
    // ADDED: Return the correct duration for scan results
    if (key.startsWith('scan_')) return _plantScanCacheDuration;
    return const Duration(hours: 1); // Default duration for any other keys
  }

  Future<void> waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  // --- Public Cleanup Methods ---

  void clearAll() {
    _cache.clear();
    _cacheTimestamps.clear();
    _lastRequestTime = null;
  }

  // --- Diagnostics ---
  
  Map<String, dynamic> getCacheStats() {
    _cleanExpiredEntries(); // Ensure stats are accurate
    return {
      'current_size': _cache.length,
      'max_size': _maxCacheSize,
    };
  }
}

