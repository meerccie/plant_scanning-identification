import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../components/app_colors.dart';
import '../../components/plant_card.dart';
import '../../providers/plant_provider.dart';
import '../../services/supabase_service.dart';
import '../plant_details_page.dart';
import 'all_store_listings_page.dart';

class StoreFeaturedPlants extends StatefulWidget {
  final Map<String, dynamic>? store;
  final List<Map<String, dynamic>> featuredPlants;
  final List<Map<String, dynamic>> allPlants;
  final bool isOwner;

  const StoreFeaturedPlants({
    super.key,
    required this.store,
    required this.featuredPlants,
    required this.allPlants,
    required this.isOwner,
  });

  @override
  State<StoreFeaturedPlants> createState() => _StoreFeaturedPlantsState();
}

class _StoreFeaturedPlantsState extends State<StoreFeaturedPlants> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.featuredPlants.length * 100, viewportFraction: 0.9);
    if (widget.featuredPlants.length > 1) {
      _startCarouselTimer();
    }
  }

  @override
  void didUpdateWidget(StoreFeaturedPlants oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the number of featured plants changes, re-evaluate the carousel timer.
    if (oldWidget.featuredPlants.length != widget.featuredPlants.length) {
      if (widget.featuredPlants.length > 1) {
        // If we now have enough plants for a carousel, start it.
        _startCarouselTimer();
      } else {
        // Otherwise, make sure the timer is stopped.
        _carouselTimer?.cancel();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel(); // Cancel any existing timer
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final nonFeaturedPlants = widget.allPlants.where((p) {
      final isFeatured = _toBool(p['is_featured']);
      final isAvailable = _toBool(p['is_available']);
      return !isFeatured && isAvailable;
    }).toList();

    final hasMoreListings = nonFeaturedPlants.isNotEmpty;
    final featuredCount = widget.featuredPlants.length;
    final currentUserId = SupabaseService.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Featured Plants',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.primaryColor),
                ),
                if (hasMoreListings)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AllStoreListingsPage(
                            storeName: widget.store?['name'] ?? 'Store',
                            nonFeaturedPlants: nonFeaturedPlants,
                          ),
                        ),
                      );
                    },
                    child: const Text('View All',
                        style: TextStyle(color: AppColors.secondaryColor)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (featuredCount == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Column(
                  children: [
                    const Icon(Icons.star_border,
                        size: 50, color: AppColors.passiveText),
                    const SizedBox(height: 10),
                    Text(
                      widget.isOwner
                          ? 'No plants marked as featured.'
                          : 'This store has no featured plants.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.featuredPlants.isEmpty ? 0 : widget.featuredPlants.length * 200, // "Infinite" scroll
                onPageChanged: (int index) {
                  if(featuredCount > 0){
                    setState(() {
                      _currentPage = index % featuredCount;
                    });
                  }
                },
                itemBuilder: (context, index) {
                  final plant = widget.featuredPlants[index % featuredCount];
                  final plantId = plant['id']?.toString() ?? '';
                  final isFavorite =
                      context.watch<PlantProvider>().isFavorite(plantId);
                  final isPlantOwner = widget.isOwner;

                  double scale = 1.0;
                  if (_pageController.position.haveDimensions) {
                    double page = _pageController.page ?? 0.0;
                    double pageDifference = (page - index).abs();
                    scale = (1 - pageDifference * 0.15).clamp(0.85, 1.0);
                  }

                  return Transform.scale(
                    scale: scale,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: PlantCard(
                        title: plant['name'] ?? 'No Name',
                        subtitle: '₱${plant['price_range'] ?? 'N/A'}',
                        imageUrl: plant['image_url'],
                        isFavorite: isFavorite,
                        onFavoritePressed: isPlantOwner
                            ? null
                            : () => context
                                .read<PlantProvider>()
                                .toggleFavorite(plant),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PlantDetailsPage(plantId: plantId)),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (featuredCount > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(featuredCount, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin:
                      const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                  height: 8,
                  width: _currentPage == index ? 24 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.secondaryColor
                        : AppColors.secondaryColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

