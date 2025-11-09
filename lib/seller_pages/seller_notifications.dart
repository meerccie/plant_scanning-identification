// lib/seller_pages/seller_notifications.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_database_service.dart';
import '../services/supabase_service.dart';
import '../components/app_colors.dart';
import '../pages/profile_page.dart';
import '../pages/plant_details_page.dart';

class SellerNotifications extends StatefulWidget {
  const SellerNotifications({super.key});

  @override
  State<SellerNotifications> createState() => _SellerNotificationsState();
}

class _SellerNotificationsState extends State<SellerNotifications> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  StreamSubscription? _notificationSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // REAL-TIME: Setup subscription for live notification updates
  void _setupRealtimeSubscription() {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) {
      debugPrint('⚠️ Cannot setup realtime: User not logged in');
      return;
    }

    try {
      debugPrint('🔄 Setting up realtime subscription for user: $userId');
      
      _notificationSubscription = SupabaseService.client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('recipient_user_id', userId)
          .listen((List<Map<String, dynamic>> data) {
            if (mounted) {
              debugPrint('⚡ Realtime update: ${data.length} notifications');
              
              setState(() {
                _notificationsFuture = Future.value(data);
                _unreadCount = data.where((n) => !(n['is_read'] as bool)).length;
              });
              
              debugPrint('📊 Unread count: $_unreadCount');
            }
          }, onError: (error) {
            debugPrint('❌ Realtime subscription error: $error');
          });
    } catch (e) {
      debugPrint('❌ Error setting up notification subscription: $e');
    }
  }

  void _loadNotifications() {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      debugPrint('📥 Loading notifications for user: $userId');
      
      setState(() {
        _notificationsFuture = SupabaseDatabaseService.getNotifications(userId);
      });
      
      // Update unread count
      _notificationsFuture.then((notifications) {
        if (mounted) {
          final unread = notifications.where((n) => !(n['is_read'] as bool)).length;
          setState(() => _unreadCount = unread);
          debugPrint('📊 Loaded ${notifications.length} notifications, $unread unread');
        }
      }).catchError((e) {
        debugPrint('❌ Error loading notifications: $e');
      });
    } else {
      debugPrint('⚠️ Cannot load notifications: User not logged in');
      setState(() {
        _notificationsFuture = Future.value([]);
      });
    }
  }

  Future<void> _handleRefresh() async {
    debugPrint('🔄 Manual refresh triggered');
    _loadNotifications();
    await _notificationsFuture;
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      debugPrint('📖 Marking notification as read: $notificationId');
      await SupabaseDatabaseService.markNotificationAsRead(notificationId);
      _loadNotifications();
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    try {
      debugPrint('📖 Marking all notifications as read for user: $userId');
      
      final notifications = await _notificationsFuture;
      int markedCount = 0;
      
      for (var notification in notifications) {
        if (!(notification['is_read'] as bool)) {
          await SupabaseDatabaseService.markNotificationAsRead(notification['id']);
          markedCount++;
        }
      }
      
      debugPrint('✅ Marked $markedCount notifications as read');
      _loadNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$markedCount notifications marked as read.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.accentColor,
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to delete all notifications? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId == null) return;

      try {
        debugPrint('🗑️ Deleting all notifications for user: $userId');
        await SupabaseDatabaseService.deleteAllNotifications(userId);
        _loadNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All notifications cleared.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        debugPrint('❌ Error clearing notifications: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear notifications: $e'),
              backgroundColor: AppColors.error,
            ),
          );
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'new_favorite':
        return 'Plant Favorite';
      case 'new_follower':
        return 'New Follower';
      case 'general':
        return 'General';
      default:
        return type;
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    debugPrint('👆 Notification tapped: ${notification['id']}');
    
    // Mark as read if not already
    if (!(notification['is_read'] as bool)) {
      _markAsRead(notification['id']);
    }

    final type = notification['type'] ?? 'general';
    final plantId = notification['plant_id'];
    final actorId = notification['actor_user_id'];
    final storeId = notification['store_id'];
    final message = notification['message'] ?? '';

    debugPrint('📱 Notification details - Type: $type, Actor: $actorId, Plant: $plantId, Store: $storeId');

    // For seller notifications, always try to navigate to the user's profile
    if (actorId != null) {
      _navigateToUserProfile(actorId.toString(), type, message);
    } else {
      _handleNotificationWithoutActor(type, plantId, storeId, message);
    }
  }

  void _navigateToUserProfile(String userId, String type, String message) {
    debugPrint('👤 Navigating to user profile: $userId (type: $type)');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    ).then((_) {
      // Optional: Refresh notifications when returning from profile
      _loadNotifications();
    });
  }

  void _handleNotificationWithoutActor(String type, dynamic plantId, dynamic storeId, String message) {
    // Handle notifications without actor (system notifications, etc.)
    switch (type) {
      case 'new_favorite' when plantId != null:
        debugPrint('🌱 Navigating to plant details: $plantId');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlantDetailsPage(plantId: plantId.toString()),
          ),
        );
        break;
      case 'new_follower' when storeId != null:
        // Could navigate to store details if you have that page
        debugPrint('🏪 Store follower notification for store: $storeId');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Store notification: $message'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
      default:
        debugPrint('ℹ️ No specific action for this notification');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification: $message'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            IconButton(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all),
              tooltip: 'Mark all as read',
            ),
          IconButton(
            onPressed: _handleRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _deleteAllNotifications();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading notifications...'),
                  ],
                ),
              );
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not load notifications.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _handleRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }

            final notifications = snapshot.data ?? [];
            
            if (notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll see notifications here when users\ninteract with your store',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _handleRefresh,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  final isRead = n['is_read'] as bool;
                  final type = n['type'] ?? 'general';
                  final createdAt = DateTime.parse(n['created_at']);
                  final hasAction = n['actor_user_id'] != null || n['plant_id'] != null;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 4.0,
                    ),
                    elevation: isRead ? 1 : 3,
                    color: isRead 
                        ? Colors.white 
                        : AppColors.accentColor.withOpacity(0.95),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isRead 
                          ? BorderSide.none 
                          : BorderSide(
                              color: _getColorForType(type, false).withOpacity(0.3),
                              width: 1,
                            ),
                    ),
                    child: InkWell(
                      onTap: () => _handleNotificationTap(n),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon container
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getColorForType(type, isRead).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForType(type),
                                color: _getColorForType(type, isRead),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Content
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Type badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getColorForType(type, isRead).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _getTypeLabel(type),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _getColorForType(type, isRead),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Message
                                  Text(
                                    n['message'],
                                    style: TextStyle(
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      color: isRead ? Colors.black87 : AppColors.primaryColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Timestamp
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 12,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat.yMMMd().add_jm().format(createdAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Unread indicator & action hint
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                if (hasAction)
                                  Column(
                                    children: [
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.grey[400],
                                        size: 16,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'View',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
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