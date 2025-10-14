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

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetchStores();
  }

  Future<List<Map<String, dynamic>>> _fetchStores() async {
    final locationProvider = context.read<LocationProvider>();
    final hasLocation = await locationProvider.getCurrentLocationForScanning(context: context);

    if (hasLocation && locationProvider.currentPosition != null) {
      return SupabaseDatabaseService.getNearbyStoresWithPlant(
        plantName: widget.plantName,
        latitude: locationProvider.currentPosition!.latitude,
        longitude: locationProvider.currentPosition!.longitude,
      );
    } else {
      return Future.value([]);
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // in kilometers
  }

  void _launchMaps(double? lat, double? long) async {
    if (lat != null && long != null) {
      final uri = Uri.parse('google.navigation:q=$lat,$long&mode=d');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = Provider.of<LocationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Stores with ${widget.plantName}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _storesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final stores = snapshot.data!;
          if (stores.isEmpty) {
            return const Center(child: Text('No nearby stores found with this plant.'));
          }

          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              final storeLat = store['latitude'];
              final storeLng = store['longitude'];
              final isAvailable = store['is_available'] ?? false;
              double? distance;

              if (locationProvider.currentPosition != null && storeLat != null && storeLng != null) {
                distance = _calculateDistance(
                  locationProvider.currentPosition!.latitude,
                  locationProvider.currentPosition!.longitude,
                  storeLat,
                  storeLng,
                );
              }

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text(store['name'] ?? 'Unknown Store'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Price: ₱${store['price_range'] ?? 'N/A'}'),
                            Text('Location: ${store['address'] ?? 'N/A'}'),
                            if (distance != null) Text('Distance: ${distance.toStringAsFixed(1)} km'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAvailable ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isAvailable ? 'Available' : 'Unavailable',
                                style: TextStyle(
                                  color: isAvailable ? Colors.green.shade700 : Colors.red.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (store['user_id'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UnifiedStoreDashboard(
                                  sellerId: store['user_id'],
                                  isViewOnly: true,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.directions),
                      onPressed: () => _launchMaps(storeLat, storeLng),
                      tooltip: 'Get Directions',
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}