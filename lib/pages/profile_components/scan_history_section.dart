import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_plant/components/app_colors.dart';
import 'package:my_plant/providers/auth_provider.dart';
import 'package:my_plant/services/supabase_database_service.dart';
import 'package:provider/provider.dart';

class ScanHistorySection extends StatelessWidget {
  const ScanHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      return const Text('You must be logged in to see your scan history.',
          style: TextStyle(color: Colors.white70));
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseDatabaseService.getScanHistory(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return const Text('Could not load scan history.',
              style: TextStyle(color: Colors.white70));
        }
        final scans = snapshot.data ?? [];
        if (scans.isEmpty) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text('You have no saved scans.',
                style: TextStyle(color: Colors.white70)),
          ));
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: scans.length,
            itemBuilder: (context, index) {
              final scan = scans[index];
              final imageUrl = scan['image_url'] as String?;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.white.withOpacity(0.1),
                child: ListTile(
                  leading: imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorWidget: (c, u, e) => const Icon(
                                Icons.local_florist,
                                color: Colors.white),
                          ),
                        )
                      : const Icon(Icons.local_florist,
                          size: 40, color: Colors.white),
                  title: Text(scan['plant_name'] ?? 'Unknown Plant',
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(scan['scientific_name'] ?? '',
                      style: const TextStyle(color: Colors.white70)),
                  trailing: Text(
                    DateFormat.yMMMd()
                        .format(DateTime.parse(scan['created_at'])),
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white70),
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
