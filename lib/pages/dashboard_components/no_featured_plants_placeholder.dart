// lib/pages/dashboard_components/no_featured_plants_placeholder.dart
import 'package:flutter/material.dart';
import '../../components/app_colors.dart';

class NoFeaturedPlantsPlaceholder extends StatelessWidget {
  const NoFeaturedPlantsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondaryColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.grass,
              size: 50,
              color: AppColors.secondaryColor.withOpacity(0.8),
            ),
            const SizedBox(height: 16),
            Text(
              'No Featured Plants... Yet!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primaryColor,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sellers are busy cultivating their best plants. Check back soon for beautiful new features!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
