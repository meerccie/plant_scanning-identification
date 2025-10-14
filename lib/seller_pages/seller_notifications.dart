// lib/seller_pages/seller_notifications.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_database_service.dart';
import '../components/app_colors.dart';
import '../pages/profile_page.dart';

class SellerNotifications extends StatefulWidget {
  const SellerNotifications({super.key});

  @override
  State<SellerNotifications> createState() => _SellerNotificationsState();
}

class _SellerNotificationsState extends State<SellerNotifications> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      setState(() {
        _notificationsFuture = SupabaseDatabaseService.getNotifications(userId);
      });
    } else {
      setState(() {
        _notificationsFuture = Future.value([]);
      });
    }
  }

  Future<void> _handleRefresh() async {
    _loadNotifications();
    await _notificationsFuture;
  }

  Future<void> _markAsRead(String notificationId) async {
    await SupabaseDatabaseService.markNotificationAsRead(notificationId);
    _loadNotifications();
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
        _loadNotifications();

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
    final actorId = notification['actor_user_id'];
    if (actorId != null) {
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
        top: false,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(snapshot.hasError ? 'Could not load notifications.' : 'No notifications yet.', style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              );
            }
            final notifications = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  final isRead = n['is_read'] as bool;
                  final type = n['type'] ?? 'general';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 6.0),
                    elevation: isRead ? 1 : 4,
                    color: isRead ? Colors.white : AppColors.accentColor,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            _getColorForType(type, isRead).withAlpha(50),
                        child: Icon(_getIconForType(type),
                            color: _getColorForType(type, isRead)),
                      ),
                      title: Text(n['message'],
                          style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text(DateFormat.yMMMd()
                          .format(DateTime.parse(n['created_at']))),
                      onTap: () => _handleNotificationTap(n),
                      trailing: isRead
                          ? null
                          : const Icon(Icons.circle,
                              size: 8, color: Colors.red),
                    ),
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