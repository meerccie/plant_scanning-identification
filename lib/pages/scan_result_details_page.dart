// lib/pages/scan_result_details_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
    
    print('📍 Starting store search for: "${widget.plantName}"');
    
    final hasLocation = await locationProvider.getCurrentLocationForScanning(context: context);

    if (!hasLocation || locationProvider.currentPosition == null) {
      print('❌ No location available for store search');
      if (mounted) setState(() => _isSearching = false);
      return [];
    }

    final currentPosition = locationProvider.currentPosition!;
    print('📍 Current location: ${currentPosition.latitude}, ${currentPosition.longitude}');

    try {
      // Try exact match first with larger radius
      List<Map<String, dynamic>> stores = await SupabaseDatabaseService.getNearbyStoresWithPlant(
        plantName: widget.plantName,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        radiusInKm: 50.0, // Increased radius
      );

      print('🏪 Found ${stores.length} stores with exact match');

      // If no exact matches found, try with search terms
      if (stores.isEmpty) {
        print('🔄 No exact matches, trying search terms...');
        final searchTerms = _extractSearchTerms(widget.plantName);
        
        for (final term in searchTerms) {
          if (term.length > 2) { // Only search meaningful terms
            print('🔍 Searching for term: "$term"');
            final termStores = await SupabaseDatabaseService.getNearbyStoresWithPlant(
              plantName: term,
              latitude: currentPosition.latitude,
              longitude: currentPosition.longitude,
              radiusInKm: 50.0,
            );
            
            if (termStores.isNotEmpty) {
              print('🏪 Found ${termStores.length} stores with term: "$term"');
              stores.addAll(termStores);
              
              // If we found enough results, break early
              if (stores.length >= 10) break;
            }
          }
        }
      }

      // Remove duplicates and sort by distance
      final uniqueStores = _removeDuplicateStores(stores);
      uniqueStores.sort((a, b) {
        final distA = a['distance_km'] as double? ?? a['distance'] as double? ?? double.maxFinite;
        final distB = b['distance_km'] as double? ?? b['distance'] as double? ?? double.maxFinite;
        return distA.compareTo(distB);
      });

      print('🎯 Final result: ${uniqueStores.length} unique stores');
      
      return uniqueStores;
    } catch (e) {
      print('❌ Error fetching stores: $e');
      return [];
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // Improved search term extraction
  List<String> _extractSearchTerms(String plantName) {
    // Remove common prefixes and extract key words
    final cleanedName = plantName
        .replaceAll(RegExp(r'^common\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^wild\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\(.*\)'), '') // Remove text in parentheses
        .trim();
    
    final words = cleanedName.split(RegExp(r'[\s\-_,.;]+'));
    
    // Filter and prioritize longer, more specific terms
    final meaningfulWords = words
        .where((word) => word.length > 2)
        .where((word) => !_isCommonWord(word))
        .toList();
    
    // If no meaningful words found, use original words (excluding very short ones)
    if (meaningfulWords.isEmpty) {
      return words.where((word) => word.length > 2).toList();
    }
    
    return meaningfulWords;
  }

  bool _isCommonWord(String word) {
    final commonWords = {
      'plant', 'flower', 'tree', 'leaf', 'green', 'red', 'blue', 
      'yellow', 'white', 'large', 'small', 'common', 'wild'
    };
    return commonWords.contains(word.toLowerCase());
  }

  List<Map<String, dynamic>> _removeDuplicateStores(List<Map<String, dynamic>> stores) {
    final seen = <String>{};
    return stores.where((store) {
      final storeId = store['id']?.toString() ?? store['store_id']?.toString();
      if (storeId != null && !seen.contains(storeId)) {
        seen.add(storeId);
        return true;
      }
      return false;
    }).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // in kilometers
  }

  void _launchMaps(double? lat, double? long) async {
    if (lat != null && long != null) {
      final uri = Uri.parse('google.navigation:q=$lat,$long&mode=d');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Fallback to web maps
        final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$long');
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
    final locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.store_mall_directory, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No Nearby Stores Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      'We couldn\'t find any stores near you selling "${widget.plantName}". '
                      'Try searching with a more general term or check back later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _retrySearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search Again'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Results header
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[50],
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      'Found ${stores.length} store${stores.length == 1 ? '' : 's'} nearby',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              // Stores list
              Expanded(
                child: ListView.builder(
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    final storeData = store['store'] ?? store;
                    final storeLat = storeData['latitude'];
                    final storeLng = storeData['longitude'];
                    final isActive = storeData['is_active'] ?? true;
                    final matchingPlants = store['matching_plants'] ?? [];
                    double? distance = store['distance_km'] as double?;

                    // Calculate distance if not provided
                    if (distance == null && locationProvider.currentPosition != null && 
                        storeLat != null && storeLng != null) {
                      distance = _calculateDistance(
                        locationProvider.currentPosition!.latitude,
                        locationProvider.currentPosition!.longitude,
                        storeLat,
                        storeLng,
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Store icon with plant count
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
                            // Store details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeData['name'] ?? 'Unknown Store',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
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
                                  // Show matching plants
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
                            // Actions
                            Column(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.blue),
                                  onPressed: () => _launchMaps(storeLat, storeLng),
                                  tooltip: 'Get Directions',
                                ),
                                if (storeData['user_id'] != null)
                                  IconButton(
                                    icon: const Icon(Icons.visibility, color: Colors.green),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UnifiedStoreDashboard(
                                            sellerId: storeData['user_id'],
                                            isViewOnly: true,
                                          ),
                                        ),
                                      );
                                    },
                                    tooltip: 'View Store',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}