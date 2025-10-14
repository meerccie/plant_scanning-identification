import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../components/app_colors.dart';
import '../../providers/plant_provider.dart';

class StoreHeader extends StatefulWidget {
  final Map<String, dynamic>? store;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onToggleFavorite;

  const StoreHeader({
    super.key,
    required this.store,
    required this.isOwner,
    required this.onEdit,
    required this.onToggleFavorite,
  });

  @override
  State<StoreHeader> createState() => _StoreHeaderState();
}

class _StoreHeaderState extends State<StoreHeader> {
  Timer? _statusUpdateTimer;
  PageController? _pageController;
  int _currentPage = 0;
  Timer? _carouselTimer;
  List<String> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    _startStatusUpdateTimer();
    _setupCarousel();
  }

  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    _carouselTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _setupCarousel() {
    if (widget.store?['image_urls'] != null) {
      final images = List<dynamic>.from(widget.store!['image_urls']);
      if (images.isNotEmpty) {
        _imageUrls = images.map((e) => e.toString()).toList();
        if (_imageUrls.length > 1) {
          _pageController = PageController(initialPage: _imageUrls.length * 100);
          _startCarouselTimer();
        }
      }
    }
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController != null && _pageController!.hasClients) {
        _pageController!.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startStatusUpdateTimer() {
    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  bool _isStoreOpen() {
    final openTimeStr = widget.store?['opening_time'] as String?;
    final closeTimeStr = widget.store?['closing_time'] as String?;

    if (openTimeStr == null ||
        closeTimeStr == null ||
        openTimeStr.isEmpty ||
        closeTimeStr.isEmpty) {
      return false;
    }

    try {
      final now = DateTime.now();
      final nowInMinutes = now.hour * 60 + now.minute;
      final openParts = openTimeStr.split(':').map(int.parse).toList();
      final openInMinutes = openParts[0] * 60 + openParts[1];
      final closeParts = closeTimeStr.split(':').map(int.parse).toList();
      final closeInMinutes = closeParts[0] * 60 + closeParts[1];

      if (openInMinutes <= closeInMinutes) {
        return nowInMinutes >= openInMinutes && nowInMinutes < closeInMinutes;
      } else {
        return nowInMinutes >= openInMinutes || nowInMinutes < closeInMinutes;
      }
    } catch (e) {
      debugPrint('Error parsing store times: $e');
      return false;
    }
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _isStoreOpen();
    final statusText = isOpen ? 'Open' : 'Closed';
    final statusColor = isOpen ? AppColors.success : AppColors.error;

    String formatDisplayTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return 'N/A';
      try {
        final parts = timeStr.split(':').map(int.parse).toList();
        final time = TimeOfDay(hour: parts[0], minute: parts[1]);
        return time.format(context);
      } catch (_) {
        return timeStr.substring(0, 5);
      }
    }

    final openTimeDisplay = formatDisplayTime(widget.store?['opening_time']);
    final closeTimeDisplay = formatDisplayTime(widget.store?['closing_time']);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Card with Carousel
            _buildImageCarousel(),
            const SizedBox(height: 16),
            // Store Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.store?['description'] ?? 'No description available.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withAlpha(128)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.phone_outlined,
              text: widget.store?['phone_number'] ?? 'Phone number not set',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.location_on_outlined,
              text: widget.store?['address'] ?? 'No address set',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.schedule,
              text: '$openTimeDisplay - $closeTimeDisplay',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Stack(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: AppColors.accentColor,
              child: _imageUrls.isEmpty
                  ? const Icon(Icons.storefront, size: 48)
                  : _imageUrls.length == 1
                      ? _buildCarouselImage(_imageUrls.first)
                      : PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index % _imageUrls.length;
                            });
                          },
                          itemBuilder: (context, index) {
                            final imageUrl = _imageUrls[index % _imageUrls.length];
                            return _buildCarouselImage(imageUrl);
                          },
                        ),
            ),
          ),
        ),
        if (_imageUrls.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_imageUrls.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
          ),
        Positioned(
          top: 8,
          right: 8,
          child: widget.isOwner
              ? IconButton(
                  icon: const Icon(Icons.edit_note, color: AppColors.primaryColor),
                  tooltip: 'Edit Store',
                  onPressed: widget.onEdit,
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.8)),
                )
              : Consumer<PlantProvider>(
                  builder: (context, plantProvider, child) {
                    final isFavorited = plantProvider.isStoreFavorited(
                        widget.store?['id']?.toString() ?? '');
                    return IconButton(
                      icon: Icon(
                        isFavorited ? Icons.favorite : Icons.favorite_border,
                        color: isFavorited
                            ? Colors.redAccent
                            : AppColors.primaryColor,
                      ),
                      tooltip: 'Favorite Store',
                      onPressed: widget.onToggleFavorite,
                      style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8)),
                    );
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildCarouselImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(imageUrl),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) =>
            const Icon(Icons.storefront, size: 48),
      ),
    );
  }


  Widget _buildInfoRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

