import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_plant/components/app_colors.dart';
import 'package:my_plant/providers/auth_provider.dart';
import 'package:my_plant/services/supabase_database_service.dart';
import 'package:provider/provider.dart';

class PlantHistorySection extends StatelessWidget {
  const PlantHistorySection({super.key});

  // Helper to determine icon and color based on the action
  Map<String, dynamic> _getActionStyle(String action) {
    switch (action) {
      case 'UPLOADED':
        return {
          'icon': Icons.add_circle_outline,
          'color': AppColors.success,
          'message': 'Uploaded',
        };
      case 'DELETED':
        return {
          'icon': Icons.delete_outline,
          'color': AppColors.error,
          'message': 'Deleted',
        };
      case 'UPDATED':
        return {
          'icon': Icons.edit_outlined,
          'color': AppColors.info,
          'message': 'Updated',
        };
      default:
        return {
          'icon': Icons.info_outline,
          'color': AppColors.info,
          'message': action,
        };
    }
  }

  // Helper to format timestamp
  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // If within last 24 hours, show relative time
      if (difference.inHours < 24) {
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes < 60) {
          return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
        } else {
          return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
        }
      }
      
      // If within last 7 days, show day of week
      if (difference.inDays < 7) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      }

      // Otherwise show full date
      return DateFormat('MMM d, y • h:mm a').format(dateTime);
    } catch (e) {
      return 'Unknown time';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'You must be logged in to see your inventory log.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDatabaseService.getPlantLedgerHistory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load inventory log',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
        
        final history = snapshot.data ?? [];
        
        // Remove duplicates based on plant_id and action, keeping the most recent
        final uniqueHistory = <String, Map<String, dynamic>>{};
        for (final entry in history) {
          final key = '${entry['plant_id']}_${entry['action']}';
          if (!uniqueHistory.containsKey(key)) {
            uniqueHistory[key] = entry;
          } else {
            // Keep the more recent entry
            final existingTimestamp = DateTime.parse(uniqueHistory[key]!['created_at']);
            final currentTimestamp = DateTime.parse(entry['created_at']);
            if (currentTimestamp.isAfter(existingTimestamp)) {
              uniqueHistory[key] = entry;
            }
          }
        }
        
        final deduplicatedHistory = uniqueHistory.values.toList()
          ..sort((a, b) => DateTime.parse(b['created_at'])
              .compareTo(DateTime.parse(a['created_at'])));
        
        if (deduplicatedHistory.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your inventory log is empty',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Upload, update, or delete plants to see activity here',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Activity',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${deduplicatedHistory.length}',
                        style: const TextStyle(
                          color: AppColors.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: deduplicatedHistory.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white12,
                  ),
                  itemBuilder: (context, index) {
                    final entry = deduplicatedHistory[index];
                    final imageUrl = entry['plant_image_url'] as String?;
                    final actionType = entry['action'] as String;
                    final style = _getActionStyle(actionType);
                    final formattedDate = _formatTimestamp(entry['created_at']);

                    return Container(
                      color: Colors.white.withOpacity(0.02),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        leading: Stack(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: style['color'].withOpacity(0.1),
                                border: Border.all(
                                  color: style['color'].withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: style['color'],
                                            ),
                                          ),
                                        ),
                                        errorWidget: (c, u, e) => Icon(
                                          style['icon'],
                                          color: style['color'],
                                          size: 24,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      style['icon'],
                                      color: style['color'],
                                      size: 24,
                                    ),
                            ),
                            // Action badge
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: style['color'],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  style['icon'],
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          entry['plant_name'] ?? 'Unnamed Plant',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: style['color'].withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  style['message'],
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    color: style['color'],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.white.withOpacity(0.3),
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}