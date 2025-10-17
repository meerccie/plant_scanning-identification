import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class SupabaseDatabaseService {
  static SupabaseClient get _client => SupabaseService.client;

  static Never _handlePostgrestError(PostgrestException e, String operation) {
    debugPrint('Postgres error during $operation: ${e.message}');
    throw Exception('Database error during $operation: ${e.message}');
  }

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
      if (filters != null) {
        filters.forEach((key, value) {
          query = query.eq(key, value);
        });
      }
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }
      if (limit != null) {
        query = query.limit(limit);
      }
      final result = await query;
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'select from $table');
    }
  }

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
      if (e.code == 'PGRST116') return null;
      _handlePostgrestError(e, 'select single from $table');
    }
  }

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

  static Future<void> _delete({
    required String table,
    required String filterKey,
    required dynamic filterValue,
    Map<String, dynamic>? additionalFilter,
  }) async {
    try {
      dynamic query = _client.from(table).delete().eq(filterKey, filterValue);
      if (additionalFilter != null) {
        additionalFilter.forEach((key, value) {
          query = query.eq(key, value);
        });
      }
      await query;
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'delete from $table');
    }
  }

  static Future<List<Map<String, dynamic>>> getNearbyStoresWithPlant({
    required double latitude,
    required double longitude,
    required String plantName,
    double radiusInKm = 50.0,
  }) async {
    try {
      final result =
          await _client.rpc('get_nearby_stores_with_similar_plants', params: {
        'p_lat': latitude,
        'p_long': longitude,
        'p_plant_name': plantName,
        'p_radius_km': radiusInKm,
        'similarity_threshold': 0.2,
      });
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Search error: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return _selectSingle(
      table: 'user_profiles',
      filterKey: 'user_id',
      filterValue: userId,
    );
  }

  static Future<Map<String, dynamic>?> getCompleteUserProfile(
      String userId) async {
    return getUserProfile(userId);
  }

  static Future<void> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
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

  static Future<List<Map<String, dynamic>>> getFeaturedPlants() async {
    return _selectList(
      table: 'plants',
      filters: {'is_available': true, 'is_featured': true},
      orderBy: 'created_at',
      ascending: false,
      limit: 10,
    );
  }

  static Future<Map<String, dynamic>?> getPlantById(String plantId) async {
    return _selectSingle(
      table: 'plants',
      select: '*, stores(*)',
      filterKey: 'id',
      filterValue: plantId,
    );
  }

  static Future<List<Map<String, dynamic>>> getAllStorePlants(
      String storeId) async {
    return _selectList(
      table: 'plants',
      filters: {'store_id': storeId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  static Future<Map<String, dynamic>> createPlant(
      Map<String, dynamic> plantData) async {
    final result = await _insert(table: 'plants', data: plantData);
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

  static Future<void> updatePlant(
      String plantId, Map<String, dynamic> updates) async {
    await _update(
      table: 'plants',
      updates: updates,
      filterKey: 'id',
      filterValue: plantId,
    );
  }

  static Future<void> deletePlant(String plantId) async {
    await _delete(table: 'plants', filterKey: 'id', filterValue: plantId);
  }

  static Future<List<Map<String, dynamic>>> getPlantsByIds(
      List<String> ids) async {
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

  static Future<List<Map<String, dynamic>>> getStoresByUser(
      String userId) async {
    return _selectList(
      table: 'stores',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  static Future<Map<String, dynamic>> createStore(
      Map<String, dynamic> storeData) async {
    return _insert(table: 'stores', data: storeData);
  }

  static Future<void> updateStore(
      String storeId, Map<String, dynamic> updates) async {
    await _update(
      table: 'stores',
      updates: updates,
      filterKey: 'id',
      filterValue: storeId,
    );
  }

  static Future<List<Map<String, dynamic>>> getStoresByIds(
      List<String> storeIds) async {
    if (storeIds.isEmpty) return [];
    try {
      final result =
          await _client.from('stores').select().inFilter('id', storeIds);
      return List<Map<String, dynamic>>.from(result);
    } on PostgrestException catch (e) {
      _handlePostgrestError(e, 'get stores by IDs');
    }
  }

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
    await _delete(
      table: 'favorite_plants',
      filterKey: 'user_id',
      filterValue: userId,
      additionalFilter: {'plant_id': plantId},
    );
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
    await _delete(
      table: 'favorite_stores',
      filterKey: 'user_id',
      filterValue: userId,
      additionalFilter: {'store_id': storeId},
    );
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

  static Future<List<Map<String, dynamic>>> getNotifications(
      String userId) async {
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

  static Future<List<Map<String, dynamic>>> getPlantLedgerHistory(
      String userId) async {
    return _selectList(
      table: 'plant_ledger',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
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

  // ADDED: New function to specifically log quantity updates
  static Future<void> createQuantityUpdateLedgerEntry({
    required String userId,
    required String plantId,
    required String plantName,
    required int newQuantity,
    String? plantImageUrl,
  }) async {
    // The action 'UPDATED' will now be saved in the database
    await createLedgerEntry(
      userId: userId,
      plantId: plantId,
      plantName: 'Stock for $plantName updated to $newQuantity',
      action: 'UPDATED',
      plantImageUrl: plantImageUrl,
    );
  }

  static Future<void> createLedgerEntry({
    required String userId,
    required String plantId,
    required String plantName,
    required String action,
    String? plantImageUrl,
  }) async {
    try {
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
    } catch (e) {
      debugPrint('⚠️ Failed to create ledger entry: $e');
    }
  }

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

  static Future<void> createPlantScan(Map<String, dynamic> scanData) async {
    await _insert(table: 'plant_scans', data: scanData);
  }

  static Future<List<Map<String, dynamic>>> getScanHistory(
      String userId) async {
    return _selectList(
      table: 'plant_scans',
      filters: {'user_id': userId},
      orderBy: 'created_at',
      ascending: false,
    );
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}