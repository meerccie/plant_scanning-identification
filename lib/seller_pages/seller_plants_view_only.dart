// lib/seller_pages/seller_plants_view_only.dart
import 'package:flutter/material.dart';
import 'package:my_plant/components/app_colors.dart';
import '../pages/plant_details_page.dart';

class SellerPlantsViewOnly extends StatelessWidget {
  final List<Map<String, dynamic>> plants;

  const SellerPlantsViewOnly({super.key, required this.plants});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('My Plants'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: plants.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_florist_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No plants uploaded yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Upload your first plant to get started!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: plants.length,
              itemBuilder: (context, index) {
                final plant = plants[index];
                return _buildPlantCard(context, plant);
              },
            ),
    );
  }

  Widget _buildPlantCard(BuildContext context, Map<String, dynamic> plant) {
    final isAvailableValue = plant['is_available'];
    bool isAvailable;

    if (isAvailableValue is String) {
      isAvailable = isAvailableValue.toLowerCase() == 'true';
    } else if (isAvailableValue is bool) {
      isAvailable = isAvailableValue;
    } else {
      isAvailable = false;
    }

    final isFeaturedValue = plant['is_featured'];
    bool isFeatured;

    if (isFeaturedValue is String) {
      isFeatured = isFeaturedValue.toLowerCase() == 'true';
    } else if (isFeaturedValue is bool) {
      isFeatured = isFeaturedValue;
    } else {
      isFeatured = false;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToPlantDetails(context, plant),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  image: plant['image_url'] != null
                      ? DecorationImage(
                          image: NetworkImage(plant['image_url']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: plant['image_url'] == null
                    ? const Icon(
                        Icons.local_florist,
                        color: AppColors.primaryColor,
                        size: 30,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant['name'] ?? 'Unnamed Plant',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (plant['scientific_name'] != null)
                      Text(
                        plant['scientific_name'],
                        style: const TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (plant['price_range'] != null)
                      Text(
                        '₱${plant['price_range']}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAvailable ? 'Available' : 'Not Available',
                            style: TextStyle(
                              color: isAvailable
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Featured',
                              style: TextStyle(
                                color: Colors.purple,
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
              const Icon(
                Icons.chevron_right,
                color: AppColors.primaryColor,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPlantDetails(
      BuildContext context, Map<String, dynamic> plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailsPage(
          plantId: plant['id'],
          hideStoreNavigation: true,
        ),
      ),
    );
  }
}