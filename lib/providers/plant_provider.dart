// lib/providers/plant_provider.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/plant_scanner_service.dart';
import '../services/supabase_service.dart';
import '../services/supabase_database_service.dart';
import 'location_provider.dart';

class PlantProvider with ChangeNotifier {
  bool _isScanning = false;
  PlantIdentification? _lastIdentification;
  String? _error;
  bool _isLoading = false;

  List<Map<String, dynamic>> _favoritePlants = [];
  List<Map<String, dynamic>> _favoriteStores = [];
  Set<String> _favoritePlantIds = <String>{};
  List<String> _favoriteStoreIds = [];
  List<Map<String, dynamic>> _recommendedPlants = [];

  bool get isScanning => _isScanning;
  PlantIdentification? get lastIdentification => _lastIdentification;
  String? get error => _error;
  bool get isLoading => _isLoading;
  List<Map<String, dynamic>> get favoritePlants => _favoritePlants;
  List<Map<String, dynamic>> get favoriteStores => _favoriteStores;
  List<Map<String, dynamic>> get recommendedPlants => _recommendedPlants;

  Future<void> loadFavorites() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    _isLoading = true;
    try {
      final favoriteIds =
          await SupabaseDatabaseService.getFavoritePlants(user.id);
      _favoritePlantIds = favoriteIds.toSet();
      if (favoriteIds.isNotEmpty) {
        _favoritePlants =
            await SupabaseDatabaseService.getPlantsByIds(favoriteIds);
      } else {
        _favoritePlants = [];
      }
    } catch (e) {
      _error = 'Failed to load favorite plants: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Map<String, dynamic> plant) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final plantId = plant['id'].toString();
    final isCurrentlyFavorite = isFavorite(plantId);

    try {
      if (isCurrentlyFavorite) {
        await SupabaseDatabaseService.removeFavoritePlant(user.id, plantId);
      } else {
        await SupabaseDatabaseService.addFavoritePlant(user.id, plantId);
      }
      await loadFavorites();
    } catch (e) {
      _error = 'Failed to update favorites: $e';
    }
    notifyListeners();
  }

  Future<void> loadFavoriteStores() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      final favoriteIds =
          await SupabaseDatabaseService.getFavoriteStores(user.id);
      _favoriteStoreIds = favoriteIds;
      if (favoriteIds.isNotEmpty) {
        _favoriteStores =
            await SupabaseDatabaseService.getStoresByIds(favoriteIds);
        await loadRecommendedPlants(); // Call the new method here
      } else {
        _favoriteStores = [];
        _recommendedPlants = []; // Clear recommendations if no favorite stores
      }
    } catch (e) {
      _error = 'Failed to load favorite stores: $e';
    }
    notifyListeners();
  }

  Future<void> loadRecommendedPlants() async {
    if (_favoriteStoreIds.isEmpty) {
      _recommendedPlants = [];
      notifyListeners();
      return;
    }
    try {
      _recommendedPlants = await SupabaseDatabaseService
          .getPlantsFromFavoriteStores(_favoriteStoreIds);
    } catch (e) {
      _error = 'Failed to load recommended plants: $e';
    }
    notifyListeners();
  }

  Future<void> toggleFavoriteStore(String storeId) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    final isCurrentlyFavorite = isStoreFavorited(storeId);

    try {
      if (isCurrentlyFavorite) {
        await SupabaseDatabaseService.removeFavoriteStore(user.id, storeId);
      } else {
        await SupabaseDatabaseService.addFavoriteStore(user.id, storeId);
      }
      await loadFavoriteStores();
    } catch (e) {
      _error = 'Failed to update favorite stores: $e';
    }
    notifyListeners();
  }

  bool isStoreFavorited(String storeId) {
    return _favoriteStoreIds.contains(storeId);
  }

  void removeFavoriteStoreLocally(String storeId) {
    _favoriteStores.removeWhere((store) => store['id'].toString() == storeId);
    _favoriteStoreIds.remove(storeId);
    notifyListeners();
  }

  void addFavoriteStoreLocally(Map<String, dynamic> store) {
    if (!_favoriteStoreIds.contains(store['id'].toString())) {
      _favoriteStores.add(store);
      _favoriteStoreIds.add(store['id'].toString());
      notifyListeners();
    }
  }

  bool isFavorite(String plantId) {
    return _favoritePlantIds.contains(plantId);
  }

  void clearAllFavorites() {
    _favoritePlants = [];
    _favoriteStores = [];
    _favoritePlantIds.clear();
    _favoriteStoreIds = [];
    notifyListeners();
  }

  Future<bool> scanPlant(
      File imageFile, LocationProvider locationProvider) async {
    _isScanning = true;
    _error = null;
    notifyListeners();
    try {
      final identification =
          await PlantScannerService.identifyPlantEnhanced(imageFile);
      _lastIdentification = identification;

      // --- ADDED: Save successful scan to history ---
      if (identification.results.isNotEmpty) {
        final user = SupabaseService.currentUser;
        final topResult = identification.results.first;
        if (user != null) {
          final scanData = {
            'user_id': user.id,
            'plant_name': topResult.species.commonNames.isNotEmpty
                ? topResult.species.commonNames.first
                : 'Unknown',
            'scientific_name': topResult.species.scientificNameWithoutAuthor,
            'image_url':
                topResult.images.isNotEmpty ? topResult.images.first.url : null,
            'latitude': locationProvider.currentPosition?.latitude,
            'longitude': locationProvider.currentPosition?.longitude,
          };
          // Do not wait for this, let it run in the background
          SupabaseDatabaseService.createPlantScan(scanData).catchError((e) {
            debugPrint("Failed to save scan history: $e");
          });
        }
      }
      // --- END ADDED SECTION ---

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }
}

