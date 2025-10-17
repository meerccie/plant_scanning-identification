import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../config/app_theme.dart';
import '../providers/plant_provider.dart';
import '../services/supabase_service.dart';
import '../services/supabase_database_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_page.dart';
import 'unified_store_dashboard.dart';

class PlantDetailsPage extends StatefulWidget {
  final String plantId;
  final bool hideStoreNavigation;

  const PlantDetailsPage({
    super.key,
    required this.plantId,
    this.hideStoreNavigation = false,
  });

  @override
  State<PlantDetailsPage> createState() => _PlantDetailsPageState();
}

class _PlantDetailsPageState extends State<PlantDetailsPage> {
  late Future<Map<String, dynamic>?> _plantDetailsFuture;

  @override
  void initState() {
    super.initState();
    _plantDetailsFuture = SupabaseDatabaseService.getPlantById(widget.plantId);
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.backgroundColor,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _plantDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return const Center(
                child: Text('Error: Could not load plant details.'));
          }

          final plant = snapshot.data!;
          final store = plant['stores'];
          final sellerId = store?['user_id'];
          final isOwner = sellerId == SupabaseService.currentUser?.id;
          final quantity = plant['quantity'] ?? 0;

          return CustomScrollView(
            slivers: [
              _buildSliverAppBar(context, plant, isOwner),
              SliverList(
                delegate: SliverChildListDelegate([
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plant['scientific_name'] ?? 'Species Unknown',
                          style: AppTheme.lato(
                            fontStyle: FontStyle.italic,
                            color: AppColors.primaryColor
                                .withOpacity(0.8),
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailCard(
                          context,
                          title: 'Description',
                          content: plant['description'] ??
                              'No detailed description provided.',
                          icon: Icons.info_outline,
                        ),
                        _buildDetailCard(
                            context,
                            title: 'Price Range',
                            content:
                                '₱${plant['price_range'] ?? 'Price unavailable'}',
                            icon: Icons.money,
                            contentStyle: AppTheme.lato(
                                fontSize: 22, color: AppColors.secondaryColor)),
                        _buildDetailCard(
                          context,
                          title: 'Stock',
                          content: '$quantity available',
                          icon: Icons.inventory_2_outlined,
                          contentStyle: AppTheme.lato(
                              fontSize: 18, color: AppColors.primaryColor),
                        ),
                        if (!widget.hideStoreNavigation &&
                            store != null &&
                            !isOwner)
                          _buildStoreSection(context, store, sellerId),
                      ],
                    ),
                  ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, Map<String, dynamic> plant, bool isOwner) {
    final plantId = plant['id'].toString();

    return SliverAppBar(
      expandedHeight: 300.0,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: FlexibleSpaceBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            plant['name'] ?? 'Plant Details',
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        centerTitle: true,
        background: plant['image_url'] != null
            ? CachedNetworkImage(
                imageUrl: plant['image_url'],
                fit: BoxFit.cover,
                color: Colors.black.withAlpha(77),
                colorBlendMode: BlendMode.darken,
                errorWidget: (context, url, error) =>
                    Container(color: AppColors.primaryColor.withOpacity(0.5)),
              )
            : Container(color: AppColors.primaryColor.withOpacity(0.5)),
      ),
      actions: [
        if (!isOwner)
          Consumer<PlantProvider>(
            builder: (context, plantProvider, child) {
              final isFavorite = plantProvider.isFavorite(plantId);
              return IconButton(
                icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white),
                onPressed: () => plantProvider.toggleFavorite(plant),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    TextStyle? contentStyle,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.secondaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTheme.pacifico(
                    color: AppColors.primaryColor,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const Divider(height: 16, thickness: 1),
            Text(
              content,
              style: contentStyle ??
                  AppTheme.lato(
                      fontSize: 16,
                      color: AppColors.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreSection(
      BuildContext context, Map<String, dynamic> store, String? sellerId) {
    final storeName = store['name'] ?? 'Store details unavailable';
    final storeAddress = store['address'] ?? 'Tap for directions';
    final storeId = store['id']?.toString() ?? '';
    final isFavorited = context.watch<PlantProvider>().isStoreFavorited(storeId);

    return AbsorbPointer(
      absorbing: isFavorited,
      child: Opacity(
        opacity: isFavorited ? 0.5 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Available At',
                  style: AppTheme.pacifico(
                    color: AppColors.primaryColor,
                    fontSize: 24,
                  ),
                ),
                if (isFavorited)
                  Text(
                    'Already in Favorites',
                    style: AppTheme.lato(
                      color: AppColors.secondaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
            const Divider(thickness: 1),
            _buildStoreTile(
              icon: Icons.storefront_outlined,
              title: storeName,
              subtitle: 'View Store Dashboard',
              onTap: () {
                if (sellerId != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => UnifiedStoreDashboard(
                              sellerId: sellerId, isViewOnly: true)));
                }
              },
            ),
            _buildStoreTile(
              icon: Icons.person_outline,
              title: 'Seller Profile',
              subtitle: 'View seller contact information',
              onTap: () {
                if (sellerId != null) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ProfilePage(userId: sellerId)));
                }
              },
            ),
            _buildStoreTile(
              icon: Icons.directions_bus,
              title: 'Get Directions',
              subtitle: storeAddress,
              onTap: () => _launchMaps(
                  store['latitude'] as double?, store['longitude'] as double?),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      elevation: 1,
      child: ListTile(
        leading: Icon(icon, color: AppColors.secondaryColor, size: 28),
        title: Text(title,
            style: AppTheme.lato(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryColor,
                fontSize: 16)),
        subtitle: Text(subtitle,
            style: AppTheme.lato(
                color: AppColors.primaryColor
                    .withOpacity(0.7))),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primaryColor),
        onTap: onTap,
      ),
    );
  }
}