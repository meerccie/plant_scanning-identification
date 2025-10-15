// lib/services/supabase_database_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Centralized database service for all Supabase database operations
class SupabaseDatabaseService {
  static SupabaseClient get _client => SupabaseService.client;

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Generic error handler for PostgrestException
  static Never _handlePostgrestError(PostgrestException e, String operation) {
    debugPrint('Postgrest error during $operation: ${e.message} (Code: ${e.code})');
    throw Exception('Database error during $operation: ${e.message}');
  }

  /// Generic select query with error handling
  static Future<List<Map<String, dynamic>>> _selectList({
    required String table,
    String select = '*',
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = false,
    int? limit,
  }) async {
    try {
      dynamic query = _client.from(table).select(select);

      // Apply filters
      if (filters != null) {
        filters.forEach((key, value) {
          query = query.eq(key, value);
        });
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      final result = await query;
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'select from $table');
    }
  }

  /// Generic single row select with error handling
  static Future<Map<String, dynamic>?> _selectSingle({
    required String table,
    String select = '*',
    required String filterKey,
    required dynamic filterValue,
  }) async {
    try {
      final result = await _client
          .from(table)
          .select(select)
          .eq(filterKey, filterValue)
          .maybeSingle();
      return result;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null; // Not found
      _handlePostgrestError(e, 'select single from $table');
    }
  }

  /// Generic insert with error handling
  static Future<Map<String, dynamic>> _insert({
    required String table,
    required Map<String, dynamic> data,
  }) async {
    try {
      final result = await _client.from(table).insert(data).select().single();
      return result;
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'insert into $table');
    }
  }

  /// Generic update with error handling
  static Future<void> _update({
    required String table,
    required Map<String, dynamic> updates,
    required String filterKey,
    required dynamic filterValue,
  }) async {
    try {
      await _client.from(table).update(updates).eq(filterKey, filterValue);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'update $table');
    }
  }

  /// Generic delete with error handling
  static Future<void> _delete({
    required String table,
    required String filterKey,
    required dynamic filterValue,
  }) async {
    try {
      await _client.from(table).delete().eq(filterKey, filterValue);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'delete from $table');
    }
  }

  // ============================================================================
  // USER PROFILE METHODS
  // ============================================================================

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return _selectSingle(
      table: 'user_profiles',
      filterKey: 'user_id',
      filterValue: userId,
    );
  }

  static Future<Map<String, dynamic>?> getCompleteUserProfile(String userId) async {
    return getUserProfile(userId);
  }

  static Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    await _update(
      table: 'user_profiles',
      updates: updates,
      filterKey: 'user_id',
      filterValue: userId,
    );
  }

  static Future<Map<String, dynamic>?> createUserProfile({
    required String userId,
    required String email,
    required String userType,
  }) async {
    try {
      return await _insert(
        table: 'user_profiles',
        data: {
          'user_id': userId,
          'email': email,
          'user_type': userType,
        },
      );
    } on Exception catch (e) {
      // If duplicate (23505), return existing profile
      if (e.toString().contains('23505')) {
        return getUserProfile(userId);
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getSellerProfile(String userId) async {
    try {
      final result = await _client
          .rpc('get_seller_profile', params: {'seller_user_id': userId})
          .maybeSingle();
      return result;
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get seller profile');
    }
  }

  // ============================================================================
  // PLANT METHODS
  // ============================================================================

  static Future<List<Map<String, dynamic>>> getFeaturedPlants() async {
    try {
      // Get featured plant IDs
      final idResult = await _selectList(
        table: 'plants',
        select: 'id',
        filters: {'is_available': true, 'is_featured': true},
        orderBy: 'created_at',
        ascending: false,
      );

      final ids = idResult.map((p) => p['id'] as String).toList();
      if (ids.isEmpty) return [];

      // Shuffle and take random 10
      ids.shuffle();
      final randomIds = ids.take(10).toList();

      // Fetch full plant data with store info
      final result = await _client
          .from('plants')
          .select('*, stores!inner(*)')
          .inFilter('id', randomIds);

      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get featured plants');
    }
  }

  static Future<Map<String, dynamic>?> getPlantById(String plantId) async {
    try {
      final result = await _client
          .from('plants')
          .select('*, stores!inner(*)')
          .eq('id', plantId)
          .single();
      return result;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116') return null;
      _handlePostgrestError(e, 'get plant by ID');
    }
  }

  static Future<List<Map<String, dynamic>>> getAllStorePlants(String storeId) async {
    try {
      final result = await _client
          .from('plants')
          .select('*, stores!inner(*)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get all store plants');
    }
  }

  static Future<List<Map<String, dynamic>>> getFeaturedStorePlants(
    String storeId, {
    int limit = 5,
  }) async {
    return _selectList(
      table: 'plants',
      select: '*, stores!inner(*)',
      filters: {'store_id': storeId, 'is_featured': true},
      orderBy: 'created_at',
      ascending: false,
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>> createPlant(Map<String, dynamic> plantData) async {
    final result = await _insert(table: 'plants', data: plantData);

    // Create ledger entry (don't block on failure)
    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      _createLedgerEntryAsync(
        userId: userId,
        plantId: result['id'] as String,
        plantName: result['name'] as String,
        action: 'UPLOADED',
        plantImageUrl: result['image_url'] as String?,
      );
    }

    return result;
  }

  static Future<void> updatePlant(String plantId, Map<String, dynamic> updates) async {
    await _update(
      table: 'plants',
      updates: updates,
      filterKey: 'id',
      filterValue: plantId,
    );
  }

  static Future<void> deletePlant(String plantId, Map<String, dynamic> plantDetails) async {
    // FIX: Removed the duplicate ledger entry creation here. 
    // The calling widget (_deletePlant in seller_my_plants.dart) now handles the ledger entry exclusively 
    // to ensure it happens before the plant record is deleted.

    await _delete(table: 'plants', filterKey: 'id', filterValue: plantId);
  }

  static Future<List<Map<String, dynamic>>> getPlantsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final result = await _client.from('plants').select().inFilter('id', ids);
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get plants by IDs');
    }
  }

  static Future<List<Map<String, dynamic>>> searchPlants(String query) async {
    try {
      final result = await _client
          .from('plants')
          .select('*, stores!inner(*)')
          .or('name.ilike.%$query%,scientific_name.ilike.%$query%')
          .eq('is_available', true);
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'search plants');
    }
  }

// ============================================================================
  // PLANT LEDGER METHODS (UPDATED TO PREVENT DUPLICATES)
  // ============================================================================

  /// Check if a ledger entry already exists for this plant and action
  static Future<bool> _ledgerEntryExists({
    required String userId,
    required String plantId,
    required String action,
  }) async {
    try {
      // Check for entries created within the last 5 minutes
      final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
      
      final result = await _client
          .from('plant_ledger')
          .select('id')
          .eq('user_id', userId)
          .eq('plant_id', plantId)
          .eq('action', action)
          .gte('created_at', fiveMinutesAgo)
          .limit(1);
      
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Warning: Could not check for duplicate ledger entry: $e');
      return false; // If check fails, allow creation to proceed
    }
  }

  static Future<void> createLedgerEntry({
    required String userId,
    required String plantId,
    required String plantName,
    required String action,
    String? plantImageUrl,
  }) async {
    try {
      // Check for duplicates first
      final exists = await _ledgerEntryExists(
        userId: userId,
        plantId: plantId,
        action: action,
      );
      
      if (exists) {
        debugPrint('⚠️ Ledger: Duplicate entry prevented for $action on $plantName');
        return;
      }
      
      await _insert(
        table: 'plant_ledger',
        data: {
          'user_id': userId,
          'plant_id': plantId,
          'plant_name': plantName,
          'plant_image_url': plantImageUrl,
          'action': action,
        },
      );
      debugPrint('✅ Ledger: $action for $plantName');
    } catch (e) {
      debugPrint('⚠️ Failed to create ledger entry: $e');
      // Don't rethrow - ledger entries shouldn't block main operations
    }
  }

  /// Async wrapper to avoid blocking on ledger creation
  static void _createLedgerEntryAsync({
    required String userId,
    required String plantId,
    required String plantName,
    required String action,
    String? plantImageUrl,
  }) {
    createLedgerEntry(
      userId: userId,
      plantId: plantId,
      plantName: plantName,
      action: action,
      plantImageUrl: plantImageUrl,
    ).catchError((e) {
      debugPrint('⚠️ Failed to create ledger entry: $e');
    });
  }

  static Future<void> createDeletedPlantLedgerEntry({
    required String userId,
    required String plantId,
    required String plantName,
    String? plantImageUrl,
  }) async {
    await createLedgerEntry(
      userId: userId,
      plantId: plantId,
      plantName: plantName,
      action: 'DELETED',
      plantImageUrl: plantImageUrl,
    );
  }

  static Future<List<Map<String, dynamic>>> getPlantLedgerHistory(String userId) async {
    return _selectList(
      table: 'plant_ledger',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  /// Optional: Method to clean up duplicate entries (run manually if needed)
  static Future<void> cleanupDuplicateLedgerEntries(String userId) async {
    try {
      // This would require a database function to be created
      await _client.rpc('cleanup_duplicate_ledger_entries', params: {
        'target_user_id': userId,
      });
      debugPrint('✅ Cleaned up duplicate ledger entries for user $userId');
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup duplicate entries: $e');
    }
  }

  // ============================================================================
  // STORE METHODS
  // ============================================================================

  static Future<List<Map<String, dynamic>>> getStoresByUser(String userId) async {
    return _selectList(
      table: 'stores',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  static Future<Map<String, dynamic>> createStore(Map<String, dynamic> storeData) async {
    return _insert(table: 'stores', data: storeData);
  }

  static Future<void> updateStore(String storeId, Map<String, dynamic> updates) async {
    await _update(
      table: 'stores',
      updates: updates,
      filterKey: 'id',
      filterValue: storeId,
    );
  }

  static Future<List<Map<String, dynamic>>> getStoresByIds(List<String> storeIds) async {
    if (storeIds.isEmpty) return [];
    try {
      final result = await _client.from('stores').select().inFilter('id', storeIds);
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get stores by IDs');
    }
  }

  static Future<List<Map<String, dynamic>>> getNearbyStoresWithPlant({
    required double latitude,
    required double longitude,
    required String plantName,
    double radiusInKm = 10.0,
  }) async {
    try {
      final result = await _client.rpc('get_nearby_stores_with_plant', params: {
        'lat': latitude,
        'long': longitude,
        'search_term': plantName,
        'radius_km': radiusInKm,
      });
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get nearby stores with plant');
    }
  }

  // ============================================================================
  // FAVORITE METHODS
  // ============================================================================

  static Future<List<String>> getFavoritePlants(String userId) async {
    final result = await _selectList(
      table: 'favorite_plants',
      select: 'plant_id',
      filters: {'user_id': userId},
    );
    return result.map((e) => e['plant_id'].toString()).toList();
  }

  static Future<void> addFavoritePlant(String userId, String plantId) async {
    await _insert(
      table: 'favorite_plants',
      data: {'user_id': userId, 'plant_id': plantId},
    );
  }

  static Future<void> removeFavoritePlant(String userId, String plantId) async {
    try {
      await _client
          .from('favorite_plants')
          .delete()
          .eq('user_id', userId)
          .eq('plant_id', plantId);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'remove favorite plant');
    }
  }

  static Future<List<String>> getFavoriteStores(String userId) async {
    final result = await _selectList(
      table: 'favorite_stores',
      select: 'store_id',
      filters: {'user_id': userId},
    );
    return result.map((e) => e['store_id'].toString()).toList();
  }

  static Future<void> addFavoriteStore(String userId, String storeId) async {
    await _insert(
      table: 'favorite_stores',
      data: {'user_id': userId, 'store_id': storeId},
    );
  }

  static Future<void> removeFavoriteStore(String userId, String storeId) async {
    try {
      await _client
          .from('favorite_stores')
          .delete()
          .eq('user_id', userId)
          .eq('store_id', storeId);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'remove favorite store');
    }
  }

  static Future<List<Map<String, dynamic>>> getPlantsFromFavoriteStores(
    List<String> storeIds, {
    int limit = 7,
  }) async {
    if (storeIds.isEmpty) return [];
    try {
      final result = await _client
          .from('plants')
          .select('*, stores!inner(*)')
          .inFilter('store_id', storeIds)
          .eq('is_available', true);

      final plants = List<Map<String, dynamic>>.from(result);
      plants.shuffle();
      return plants.take(limit).toList();
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get plants from favorite stores');
    }
  }

  // ============================================================================
  // NOTIFICATION METHODS
  // ============================================================================

  static Future<List<Map<String, dynamic>>> getNotifications(String userId) async {
    return _selectList(
      table: 'notifications',
      filters: {'recipient_user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  static Future<void> markNotificationAsRead(String notificationId) async {
    await _update(
      table: 'notifications',
      updates: {'is_read': true},
      filterKey: 'id',
      filterValue: notificationId,
    );
  }

  static Future<void> deleteAllNotifications(String userId) async {
    await _delete(
      table: 'notifications',
      filterKey: 'recipient_user_id',
      filterValue: userId,
    );
  }

  static Future<void> createNotification({
    required String recipientId,
    required String actorId,
    required String message,
    String? plantId,
    String type = 'general',
  }) async {
    await _insert(
      table: 'notifications',
      data: {
        'recipient_user_id': recipientId,
        'actor_user_id': actorId,
        'message': message,
        'plant_id': plantId,
        'type': type,
      },
    );
  }

  // ============================================================================
  // PLANT SCAN HISTORY METHODS
  // ============================================================================

  static Future<void> createPlantScan(Map<String, dynamic> scanData) async {
    // Trigger cleanup asynchronously (don't wait)
    _client.rpc('delete_old_plant_scans').then((_) {
      debugPrint('✅ Triggered old scan cleanup');
    }).catchError((e) {
      debugPrint('⚠️ Failed to trigger scan cleanup: $e');
    });

    // Insert new scan
    await _insert(table: 'plant_scans', data: scanData);
  }

  static Future<List<Map<String, dynamic>>> getScanHistory(String userId) async {
    return _selectList(
      table: 'plant_scans',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
  }
}