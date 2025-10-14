import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../components/app_colors.dart';
import '../../providers/plant_provider.dart';
import '../../services/supabase_service.dart';
import '../plant_details_page.dart';

class FavoriteStoreListings extends StatelessWidget {
  const FavoriteStoreListings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (plantProvider.isLoading && plantProvider.recommendedPlants.isEmpty) {
          return const SizedBox(
              height: 150, child: Center(child: CircularProgressIndicator()));
        }
        if (plantProvider.recommendedPlants.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFavoriteStorePlaceholder(),
          );
        }

        final plants = plantProvider.recommendedPlants;
        final String? currentUserId = SupabaseService.currentUser?.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Recommended from Your Favorite Stores',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: plants.length,
                padding: const EdgeInsets.only(left: 20),
                itemBuilder: (context, index) {
                  return _buildHorizontalFavoritePlantCard(
                      context, plants[index], currentUserId);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHorizontalFavoritePlantCard(
      BuildContext context, Map<String, dynamic> plant, String? currentUserId) {
    final plantId = plant['id'].toString();
    final isOwner = plant['stores']?['user_id'] == currentUserId;
    final priceDisplay = '₱${plant['price_range'] ?? 'N/A'}';

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PlantDetailsPage(plantId: plantId))),
      child: Container(
        width: 320,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.secondaryColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
              child: SizedBox(
                width: 120,
                height: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: plant['image_url'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const Center(
                      child: Icon(Icons.local_florist,
                          color: AppColors.primaryColor)),
                  errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.local_florist,
                          color: AppColors.primaryColor)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      plant['name'] ?? 'Unknown Plant',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plant['description'] ?? 'No description.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white.withAlpha(178)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          priceDisplay,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        if (!isOwner)
                          Consumer<PlantProvider>(
                            builder: (context, plantProvider, child) {
                              final isFavorite =
                                  plantProvider.isFavorite(plantId);
                              return IconButton(
                                icon: Icon(
                                  isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.red
                                      : Colors.white.withAlpha(178),
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    plantProvider.toggleFavorite(plant),
                              );
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteStorePlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Discover Plants from Your Favorite Stores',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.primaryColor),
        ),
        const SizedBox(height: 16),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storefront, size: 40, color: AppColors.primaryColor),
                  SizedBox(height: 8),
                  Text(
                    'Favorite a store to see plant recommendations here!',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppColors.primaryColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
