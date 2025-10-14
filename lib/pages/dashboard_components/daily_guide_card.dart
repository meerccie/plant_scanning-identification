import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../components/app_colors.dart';
import '../../config/app_theme.dart';

class DailyGuideCard extends StatelessWidget {
  final Map<String, dynamic>? guide;
  final bool isLoading;

  const DailyGuideCard({
    super.key,
    required this.guide,
    required this.isLoading,
  });

  Map<String, dynamic> _getDefaultGuide() {
    return {
      'common_name': 'Plant Care Tip',
      'scientific_name': 'Did you know?',
      'primary_image': null,
      'summary':
          'Check your plant\'s soil moisture regularly to avoid over or under-watering. Different plants have different needs!',
      'full_guide':
          'Regularly checking the soil is crucial for plant health. For most houseplants, it\'s best to let the top 1-2 inches of soil dry out before watering again. This prevents root rot, a common issue caused by overwatering. Always check the specific needs of your plant variety.',
    };
  }

  void _showFullGuideDialog(BuildContext context, Map<String, dynamic> guideData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final imageUrl = guideData['primary_image'] as String?;
        
        // FIX: Handle both String and List types for scientific_name
        final scientificNameValue = guideData['scientific_name'];
        String scientificName = '';
        if (scientificNameValue is List && scientificNameValue.isNotEmpty) {
          scientificName = scientificNameValue.first.toString();
        } else if (scientificNameValue is String) {
          scientificName = scientificNameValue;
        }

        return AlertDialog(
          backgroundColor: AppColors.accentColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(guideData['common_name']!),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                        errorWidget: (context, url, error) => const SizedBox(
                            height: 150, child: Icon(Icons.error)),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    scientificName,
                    style: AppTheme.lato(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Divider(height: 24),
                  Text(
                    guideData['full_guide']!,
                    style: AppTheme.lato(fontSize: 15, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayGuide = guide ?? _getDefaultGuide();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.eco_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Daily Plant Guide",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayGuide['common_name']!,
                  style: AppTheme.lato(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  displayGuide['summary']!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.lato(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showFullGuideDialog(context, displayGuide),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      'Read More...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                )
              ],
            ),
        ],
      ),
    );
  }
}

