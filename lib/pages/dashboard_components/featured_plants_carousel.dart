import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/app_colors.dart';
import '../../components/plant_card.dart';
import '../../providers/plant_provider.dart';
import '../../services/supabase_service.dart';
import '../plant_details_page.dart';
import 'no_featured_plants_placeholder.dart'; // ADDED

class FeaturedPlantsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> featuredPlants;
  final bool isLoading;

  const FeaturedPlantsCarousel({
    super.key,
    required this.featuredPlants,
    required this.isLoading,
  });

  @override
  State<FeaturedPlantsCarousel> createState() => _FeaturedPlantsCarouselState();
}

class _FeaturedPlantsCarouselState extends State<FeaturedPlantsCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 5000, viewportFraction: 0.85);
    _startCarouselTimer();
  }

  @override
  void didUpdateWidget(covariant FeaturedPlantsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.featuredPlants.length != oldWidget.featuredPlants.length) {
      _startCarouselTimer();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (widget.featuredPlants.length <= 1) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    // MODIFIED: This widget now always returns a Column with the title.
    // The content inside is conditional.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Featured Plants',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 20, color: AppColors.primaryColor),
          ),
        ),
        const SizedBox(height: 16),
        // ADDED: Conditional logic to show either the carousel or the placeholder.
        if (widget.featuredPlants.isEmpty)
          const NoFeaturedPlantsPlaceholder()
        else
          _buildCarousel(),
      ],
    );
  }

  // ADDED: Extracted the carousel and dots into a separate build method for clarity.
  Widget _buildCarousel() {
    final String? currentUserId = SupabaseService.currentUser?.id;

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: PageView.builder(
            controller: _pageController,
            itemCount: 10000, // Infinite scroll effect
            onPageChanged: (int index) {
              if (widget.featuredPlants.isNotEmpty) {
                setState(
                    () => _currentPage = index % widget.featuredPlants.length);
              }
            },
            itemBuilder: (context, index) {
              if (widget.featuredPlants.isEmpty) return const SizedBox.shrink();
              final plant =
                  widget.featuredPlants[index % widget.featuredPlants.length];
              final plantId = plant['id'].toString();
              final isOwner = plant['stores']?['user_id'] == currentUserId;
              final priceDisplay = '₱${plant['price_range'] ?? 'N/A'}';

              double scale = 1.0;
              if (_pageController.position.haveDimensions) {
                double page = _pageController.page ?? 5000;
                double pageDifference = (page - index).abs();
                scale = (1 - pageDifference * 0.15).clamp(0.85, 1.0);
              }

              return Transform.scale(
                scale: scale,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: PlantCard(
                    title: plant['name'] ?? 'No Name',
                    imageUrl: plant['image_url'],
                    subtitle: priceDisplay,
                    isFavorite:
                        context.watch<PlantProvider>().isFavorite(plantId),
                    onFavoritePressed: isOwner
                        ? null
                        : () =>
                            context.read<PlantProvider>().toggleFavorite(plant),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PlantDetailsPage(plantId: plantId),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.featuredPlants.length >
            1) // Only show dots if there's more than one plant
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.featuredPlants.length, (index) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(
                    vertical: 10.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryColor.withAlpha(
                      (255 * (_currentPage == index ? 0.9 : 0.4)).round()),
                ),
              );
            }),
          ),
      ],
    );
  }
}
