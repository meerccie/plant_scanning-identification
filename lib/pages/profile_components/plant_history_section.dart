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
      default:
        return {
          'icon': Icons.update,
          'color': AppColors.info,
          'message': 'Updated',
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      return const Text('You must be logged in to see your inventory log.',
          style: TextStyle(color: Colors.white70));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDatabaseService.getPlantLedgerHistory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load inventory log: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
          );
        }
        
        final history = snapshot.data ?? [];
        if (history.isEmpty) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('Your inventory log is empty.',
                style: TextStyle(color: Colors.white70)),
          ));
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: history.length,
            itemBuilder: (context, index) {
              final entry = history[index];
              final imageUrl = entry['plant_image_url'] as String?;
              final actionType = entry['action'] as String;
              final style = _getActionStyle(actionType);
              
              final timestamp = DateTime.parse(entry['created_at']);
              final formattedDate = DateFormat.yMMMd().add_jm().format(timestamp);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.white.withOpacity(0.1),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: style['color'].withOpacity(0.2),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Icon(
                                  style['icon'],
                                  color: style['color']),
                            ),
                          )
                        : Icon(style['icon'], color: style['color']),
                  ),
                  // FIX: Use Theme.of(context).textTheme.bodyLarge for default font
                  title: Text(entry['plant_name'] ?? 'Unnamed Plant',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w500)),
                  // FIX: Use Theme.of(context).textTheme.bodyMedium for default font
                  subtitle: Text(
                      '${style['message']} on $formattedDate',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70.withOpacity(0.8))),
                  trailing: Text(
                    entry['action'] ?? '',
                    style: TextStyle(
                        fontSize: 12,
                        color: style['color'],
                        fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}