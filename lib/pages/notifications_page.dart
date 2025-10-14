// lib/pages/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_database_service.dart';
import 'plant_details_page.dart';
import 'profile_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _getNotifications();
  }

  Future<List<Map<String, dynamic>>> _getNotifications() {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      return SupabaseDatabaseService.getNotifications(userId);
    }
    return Future.value([]);
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _notificationsFuture = _getNotifications();
    });
    await _notificationsFuture;
  }

  Future<void> _markAsRead(String notificationId) async {
    await SupabaseDatabaseService.markNotificationAsRead(notificationId);
    _handleRefresh();
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to delete all notifications? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Clear All', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) return;

      try {
        await SupabaseDatabaseService.deleteAllNotifications(userId);
        await _handleRefresh();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('All notifications cleared.'),
              backgroundColor: AppColors.success));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Failed to clear notifications: $e'),
              backgroundColor: AppColors.error));
        }
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_plant':
        return Icons.local_florist;
      case 'new_favorite':
        return Icons.favorite;
      case 'new_follower':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type, bool isRead) {
    if (isRead) return Colors.grey;
    switch (type) {
      case 'new_plant':
        return AppColors.primaryColor;
      case 'new_favorite':
        return Colors.redAccent;
      case 'new_follower':
        return Colors.blue;
      default:
        return AppColors.secondaryColor;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    if (!(notification['is_read'] as bool)) {
      _markAsRead(notification['id']);
    }

    final type = notification['type'] ?? 'general';
    final plantId = notification['plant_id'];
    final actorId = notification['actor_user_id'];

    if ((type == 'new_plant' || type == 'new_favorite') && plantId != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  PlantDetailsPage(plantId: plantId.toString())));
    } else if (actorId != null) {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ProfilePage(userId: actorId.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _deleteAllNotifications,
            icon: const Icon(Icons.clear_all, color: AppColors.error),
            tooltip: 'Clear All',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height - 150,
                    alignment: Alignment.center,
                    child: Text('Error: ${snapshot.error.toString()}'),
                  ),
                ),
              );
            }

            final notifications = snapshot.data ?? [];
            if (notifications.isEmpty) {
              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height - 150,
                    alignment: Alignment.center,
                    child: const Text('No notifications yet.'),
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isRead = notification['is_read'] as bool;
                  final type = notification['type'] ?? 'general';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          _getColorForType(type, isRead).withAlpha(50),
                      child: Icon(_getIconForType(type),
                          color: _getColorForType(type, isRead)),
                    ),
                    title: Text(notification['message'] ?? '',
                        style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text(DateFormat.yMMMd()
                        .format(DateTime.parse(notification['created_at']))),
                    onTap: () => _handleNotificationTap(notification),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}