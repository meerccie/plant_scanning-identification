// lib/pages/favorites.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../providers/location_provider.dart';
import '../providers/plant_provider.dart';
import 'plant_details_page.dart';
import 'unified_store_dashboard.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // State for Plants Tab
  final TextEditingController _plantSearchController = TextEditingController();
  String _plantSortOrder = 'newest';

  // State for Stores Tab
  final TextEditingController _storeSearchController = TextEditingController();
  String _storeSortOrder = 'a-z';

  @override
  void initState() {
    super.initState();
    // Add listeners to rebuild the UI on text changes
    _plantSearchController.addListener(() => setState(() {}));
    _storeSearchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _plantSearchController.dispose();
    _storeSearchController.dispose();
    super.dispose();
  }

  // --- Helper to calculate distance ---
  double? _calculateDistance(
      Position? userPosition, Map<String, dynamic> store) {
    final lat = (store['latitude'] as num?)?.toDouble();
    final long = (store['longitude'] as num?)?.toDouble();

    if (userPosition != null && lat != null && long != null) {
      return Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            lat,
            long,
          ) /
          1000; // Convert to kilometers
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          elevation: 0,
          title: const Text('Favorites'),
          centerTitle: false,
          bottom: const TabBar(
            indicatorColor: AppColors.primaryColor,
            labelColor: AppColors.primaryColor,
            unselectedLabelColor: AppColors.passiveText,
            tabs: [
              Tab(icon: Icon(Icons.local_florist), text: 'Plants'),
              Tab(icon: Icon(Icons.store), text: 'Stores'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFavoritePlantsList(),
            _buildFavoriteStoresList(),
          ],
        ),
      ),
    );
  }

  // --- Widget for Favorite Plants Tab ---
  Widget _buildFavoritePlantsList() {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (plantProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // --- Filtering and Sorting Logic ---
        List<Map<String, dynamic>> displayedPlants =
            List.from(plantProvider.favoritePlants);
        final plantQuery = _plantSearchController.text.toLowerCase();
        if (plantQuery.isNotEmpty) {
          displayedPlants = displayedPlants.where((plant) {
            final name = (plant['name'] as String? ?? '').toLowerCase();
            final sciName =
                (plant['scientific_name'] as String? ?? '').toLowerCase();
            return name.contains(plantQuery) || sciName.contains(plantQuery);
          }).toList();
        }

        // Apply sort
        switch (_plantSortOrder) {
          case 'a-z':
            displayedPlants.sort((a, b) => (a['name'] as String? ?? '')
                .compareTo(b['name'] as String? ?? ''));
            break;
          case 'z-a':
            displayedPlants.sort((a, b) => (b['name'] as String? ?? '')
                .compareTo(a['name'] as String? ?? ''));
            break;
          case 'oldest':
            displayedPlants.sort((a, b) => DateTime.parse(a['created_at'])
                .compareTo(DateTime.parse(b['created_at'])));
            break;
          case 'newest':
          default:
            displayedPlants.sort((a, b) => DateTime.parse(b['created_at'])
                .compareTo(DateTime.parse(a['created_at'])));
            break;
        }
        // --- End Logic ---

        if (plantProvider.favoritePlants.isEmpty) {
          return const Center(
              child: Text('You haven\'t added any favorite plants yet.'));
        }

        return Column(
          children: [
            _buildSearchAndFilterBar(
              controller: _plantSearchController,
              sortOrder: _plantSortOrder,
              onSortChanged: (value) => setState(() => _plantSortOrder = value),
              sortOptions: const {
                'newest': 'Newest First',
                'oldest': 'Oldest First',
                'a-z': 'A-Z',
                'z-a': 'Z-A',
              },
            ),
            Expanded(
              child: displayedPlants.isEmpty
                  ? const Center(child: Text('No plants match your search.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: displayedPlants.length,
                      itemBuilder: (context, index) {
                        final plant = displayedPlants[index];
                        return Card(
                          color: AppColors.accentColor,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: plant['image_url'] != null
                                ? Image.network(plant['image_url'],
                                    width: 60, height: 60, fit: BoxFit.cover)
                                : const Icon(Icons.local_florist,
                                    size: 50, color: AppColors.primaryColor),
                            title: Text(plant['name'] ?? 'Unknown Plant',
                                style: const TextStyle(
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(plant['scientific_name'] ?? '',
                                style: const TextStyle(
                                    color: AppColors.secondaryColor)),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () =>
                                  plantProvider.toggleFavorite(plant),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => PlantDetailsPage(
                                      plantId: plant['id'].toString())),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // --- Widget for Favorite Stores Tab ---
  Widget _buildFavoriteStoresList() {
    return Consumer2<PlantProvider, LocationProvider>(
      builder: (context, plantProvider, locationProvider, child) {
        if (plantProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // --- Filtering and Sorting Logic ---
        List<Map<String, dynamic>> displayedStores =
            List.from(plantProvider.favoriteStores);
        final storeQuery = _storeSearchController.text.toLowerCase();
        if (storeQuery.isNotEmpty) {
          displayedStores = displayedStores.where((store) {
            final name = (store['name'] as String? ?? '').toLowerCase();
            final address = (store['address'] as String? ?? '').toLowerCase();
            return name.contains(storeQuery) || address.contains(storeQuery);
          }).toList();
        }

        // Apply sort
        final userPosition = locationProvider.currentPosition;
        if ((_storeSortOrder == 'nearest' || _storeSortOrder == 'furthest') &&
            userPosition != null) {
          for (var store in displayedStores) {
            store['distance'] = _calculateDistance(userPosition, store);
          }
          displayedStores.sort((a, b) {
            final distA = a['distance'] as double? ?? double.infinity;
            final distB = b['distance'] as double? ?? double.infinity;
            return _storeSortOrder == 'nearest'
                ? distA.compareTo(distB)
                : distB.compareTo(distA);
          });
        } else {
          // Default alphabetical sort
          displayedStores.sort((a, b) => (_storeSortOrder == 'a-z')
              ? (a['name'] as String? ?? '')
                  .compareTo(b['name'] as String? ?? '')
              : (b['name'] as String? ?? '')
                  .compareTo(a['name'] as String? ?? ''));
        }
        // --- End Logic ---

        if (plantProvider.favoriteStores.isEmpty) {
          return const Center(
              child: Text('You haven\'t added any favorite stores yet.'));
        }

        return Column(
          children: [
            _buildSearchAndFilterBar(
              controller: _storeSearchController,
              sortOrder: _storeSortOrder,
              onSortChanged: (value) async {
                if ((value == 'nearest' || value == 'furthest') &&
                    locationProvider.currentPosition == null) {
                  final hasPermission = await locationProvider
                      .requestLocationPermission(context: context);
                  if (hasPermission) {
                    await locationProvider.getCurrentLocation(context: context);
                  }
                }
                setState(() => _storeSortOrder = value);
              },
              sortOptions: const {
                'a-z': 'A-Z',
                'z-a': 'Z-A',
                'nearest': 'Nearest',
                'furthest': 'Furthest',
              },
            ),
            Expanded(
              child: displayedStores.isEmpty
                  ? const Center(child: Text('No stores match your search.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: displayedStores.length,
                      itemBuilder: (context, index) {
                        final store = displayedStores[index];
                        final distance = store['distance'] as double?;
                        String subtitle = store['address'] ?? 'No address';
                        if (distance != null) {
                          subtitle =
                              '$subtitle • ${distance.toStringAsFixed(1)} km away';
                        }
                        return Card(
                          color: AppColors.accentColor,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: store['image_url'] != null
                                ? Image.network(store['image_url'],
                                    width: 60, height: 60, fit: BoxFit.cover)
                                : const Icon(Icons.store,
                                    size: 50, color: AppColors.primaryColor),
                            title: Text(store['name'] ?? 'Unknown Store',
                                style: const TextStyle(
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(subtitle,
                                style: const TextStyle(
                                    color: AppColors.secondaryColor)),
                            trailing: IconButton(
                              icon: const Icon(Icons.favorite, color: Colors.red),
                              onPressed: () => plantProvider
                                  .toggleFavoriteStore(store['id'].toString()),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => UnifiedStoreDashboard(
                                      sellerId: store['user_id'],
                                      isViewOnly: true)),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // --- Reusable Search and Filter Widget ---
  Widget _buildSearchAndFilterBar({
    required TextEditingController controller,
    required String sortOrder,
    required Function(String) onSortChanged,
    required Map<String, String> sortOptions,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Material(
              elevation: 2.0,
              borderRadius: BorderRadius.circular(12.0),
              shadowColor: Colors.black.withOpacity(0.1),
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            color: AppColors.accentColor,
            onSelected: onSortChanged,
            itemBuilder: (context) => sortOptions.entries.map((entry) {
              return PopupMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    fontFamily:
                        Theme.of(context).textTheme.bodyLarge?.fontFamily,
                  ),
                ),
              );
            }).toList(),
            icon: const Icon(Icons.sort, color: AppColors.primaryColor),
          ),
        ],
      ),
    );
  }
}


