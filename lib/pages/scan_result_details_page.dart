// lib/pages/scan_result_details_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/app_colors.dart';
import '../services/supabase_database_service.dart';
import '../providers/location_provider.dart';
import 'unified_store_dashboard.dart';

class ScanResultDetailsPage extends StatefulWidget {
  final String plantName;

  const ScanResultDetailsPage({super.key, required this.plantName});

  @override
  State<ScanResultDetailsPage> createState() => _ScanResultDetailsPageState();
}

class _ScanResultDetailsPageState extends State<ScanResultDetailsPage> {
  late Future<List<Map<String, dynamic>>> _storesFuture;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetchStores();
  }

  Future<List<Map<String, dynamic>>> _fetchStores() async {
    if (!mounted) return [];
    
    setState(() => _isSearching = true);
    
    final locationProvider = context.read<LocationProvider>();
    
    debugPrint('📍 Starting store search for: "${widget.plantName}"');
    
    final hasLocation = await locationProvider.getCurrentLocationForScanning(context: context);

    if (!hasLocation || locationProvider.currentPosition == null) {
      debugPrint('❌ No location available for store search');
      if (mounted) setState(() => _isSearching = false);
      return [];
    }

    final currentPosition = locationProvider.currentPosition!;
    debugPrint('📍 Current location: ${currentPosition.latitude}, ${currentPosition.longitude}');

    try {
      final stores = await SupabaseDatabaseService.getNearbyStoresWithPlant(
        plantName: widget.plantName,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        radiusInKm: 100.0,
      );

      debugPrint('🎯 Final result: ${stores.length} stores found');
      
      return stores;
    } catch (e) {
      debugPrint('❌ Error fetching stores: $e');
      return [];
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  List<Map<String, dynamic>> _getNearbyStores(List<Map<String, dynamic>> stores) {
    return stores.where((store) {
      final distance = store['distance_km'] as double? ?? double.maxFinite;
      return distance <= 50.0;
    }).toList();
  }

  List<Map<String, dynamic>> _getFarStores(List<Map<String, dynamic>> stores) {
    return stores.where((store) {
      final distance = store['distance_km'] as double? ?? double.maxFinite;
      return distance > 50.0;
    }).toList();
  }

  Widget _buildMatchTypeBadge(String matchType) {
    final colors = {
      'exact_match': Colors.green,
      'similar_match': Colors.blue,
    };
    
    final labels = {
      'exact_match': 'Exact Match',
      'similar_match': 'Similar Plant',
    };
    
    final color = colors[matchType] ?? Colors.grey;
    final label = labels[matchType] ?? 'Match';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDistanceWarning(double distance) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, size: 16, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This store is ${distance.toStringAsFixed(1)}km away - consider shipping',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Row(
        children: [
          Icon(
            title.contains('Nearby') ? Icons.near_me : Icons.pin_drop,
            color: title.contains('Nearby') ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: title.contains('Nearby') ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED: The list builder now uses a tappable InkWell ---
  Widget _buildStoreList(List<Map<String, dynamic>> stores, {bool showDistanceWarning = false}) {
    return ListView.builder(
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        final storeData = store['store'] ?? store;
        final storeLat = storeData['latitude'];
        final storeLng = storeData['longitude'];
        final isActive = storeData['is_active'] ?? true;
        final matchingPlants = store['matching_plants'] ?? [];
        final searchStrategy = store['search_strategy'] ?? 'similar_match';
        double? distance = store['distance_km'] as double?;
        final sellerId = storeData['user_id'];

        return Card(
          color: AppColors.accentColor,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.all(8.0),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: sellerId != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UnifiedStoreDashboard(
                          sellerId: sellerId,
                          isViewOnly: true,
                        ),
                      ),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.store, color: Colors.green, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              '${matchingPlants.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    storeData['name'] ?? 'Unknown Store',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                _buildMatchTypeBadge(searchStrategy),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (storeData['address'] != null)
                              Text(
                                storeData['address']!,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            if (matchingPlants.isNotEmpty)
                              SizedBox(
                                height: 20,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    for (final plant in matchingPlants.take(3))
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[100],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          plant['name'] ?? 'Plant',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    if (matchingPlants.length > 3)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Text(
                                          '+${matchingPlants.length - 3} more',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${(distance ?? 0).toStringAsFixed(1)} km',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isActive 
                                      ? Colors.green.shade100 
                                      : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? 'Open' : 'Closed',
                                    style: TextStyle(
                                      color: isActive 
                                        ? Colors.green.shade700 
                                        : Colors.red.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.directions, color: Colors.blue),
                            onPressed: () => _launchMaps(storeLat, storeLng),
                            tooltip: 'Get Directions',
                          ),
                          // Replaced visibility icon with a chevron to indicate tappability
                          if (sellerId != null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Icon(Icons.chevron_right, color: Colors.grey),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (showDistanceWarning && distance != null && distance > 50)
                    _buildDistanceWarning(distance),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoStoresFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.store_mall_directory, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No Stores Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'We couldn\'t find any stores selling "${widget.plantName}" near your location. '
              'Try scanning again or check back later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _retrySearch,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _launchMaps(double? lat, double? long) async {
    if (lat != null && long != null) {
      final uri = Uri.parse('google.navigation:q=$lat,$long&mode=d');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$long');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri);
        }
      }
    }
  }

  Future<void> _retrySearch() async {
    setState(() {
      _storesFuture = _fetchStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('Stores with ${widget.plantName}'),
        actions: [
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _retrySearch,
              tooltip: 'Refresh search',
            ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !_isSearching) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching for nearby stores...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error searching for stores',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _retrySearch,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final stores = snapshot.data ?? [];

          if (stores.isEmpty) {
            return _buildNoStoresFound();
          }

          final nearbyStores = _getNearbyStores(stores);
          final farStores = _getFarStores(stores);

          return Column(
            children: [
              if (nearbyStores.isNotEmpty) ...[
                _buildStoreSectionHeader('📍 Nearby Stores (within 50km)', nearbyStores.length),
                Expanded(
                  flex: nearbyStores.length,
                  child: _buildStoreList(nearbyStores, showDistanceWarning: false),
                ),
              ],
              
              if (farStores.isNotEmpty) ...[
                _buildStoreSectionHeader('🚗 Stores Further Away', farStores.length),
                Expanded(
                  flex: farStores.length,
                  child: _buildStoreList(farStores, showDistanceWarning: true),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}