// lib/seller_pages/seller_my_plants.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_database_service.dart';
import '../providers/auth_provider.dart';
import '../components/app_colors.dart';
import 'plant_upload.dart';
import '../pages/plant_details_page.dart';

class SellerMyPlants extends StatefulWidget {
  const SellerMyPlants({super.key});

  @override
  State<SellerMyPlants> createState() => _SellerMyPlantsState();
}

class _SellerMyPlantsState extends State<SellerMyPlants> {
  List<Map<String, dynamic>> _plants = [];
  List<Map<String, dynamic>> _filteredPlants = [];
  Map<String, dynamic>? _store;
  bool _isLoading = true;
  String? _error;
  int _featuredCount = 0;
  final int _maxFeatured = 5;
  final TextEditingController _searchController = TextEditingController();
  String _sortOrder = 'newest';
  bool _isDeleting = false; // ADDED: State to manage deletion in progress

  @override
  void initState() {
    super.initState();
    _loadPlants();
    _searchController.addListener(_filterPlants);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterPlants);
    _searchController.dispose();
    super.dispose();
  }

  void _filterPlants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPlants = _plants.where((plant) {
        final plantName = (plant['name'] as String? ?? '').toLowerCase();
        return plantName.contains(query);
      }).toList();
      _sortPlants();
    });
  }

  void _sortPlants() {
    switch (_sortOrder) {
      case 'a-z':
        _filteredPlants.sort((a, b) => (a['name'] as String? ?? '')
            .compareTo(b['name'] as String? ?? ''));
        break;
      case 'z-a':
        _filteredPlants.sort((a, b) => (b['name'] as String? ?? '')
            .compareTo(a['name'] as String? ?? ''));
        break;
      case 'oldest':
        _filteredPlants.sort((a, b) =>
            DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
        break;
      case 'newest':
      default:
        _filteredPlants.sort((a, b) =>
            DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
        break;
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  Future<void> _loadPlants() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        final stores = await SupabaseDatabaseService.getStoresByUser(userId);
        if (mounted && stores.isNotEmpty) {
          _store = stores.first;
          final plants =
              await SupabaseDatabaseService.getAllStorePlants(_store!['id']);
          final featured =
              plants.where((p) => _toBool(p['is_featured'])).toList();

          if (mounted) {
            setState(() {
              _plants = plants;
              _filterPlants();
              _error = null;
              _featuredCount = featured.length;
            });
          }
        } else if (mounted) {
          setState(() {
            _error = 'No store found. Please register a store first.';
            _featuredCount = 0;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load plants: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlantAvailability(
      String plantId, bool currentStatus) async {
    try {
      await SupabaseDatabaseService.updatePlant(
          plantId, {'is_available': !currentStatus});
      await _loadPlants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plant status updated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleFeaturedStatus(String plantId, bool currentStatus) async {
    final newStatus = !currentStatus;

    if (newStatus && _featuredCount >= _maxFeatured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Cannot add to featured. Maximum of $_maxFeatured plants already featured.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      await SupabaseDatabaseService.updatePlant(
          plantId, {'is_featured': newStatus});
      await _loadPlants();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Plant marked as ${newStatus ? 'featured' : 'not featured'}.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deletePlant(String plantId, Map<String, dynamic> plant) async {
    // FIX: Guard context use across async gap.
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this plant?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    // FIX: Add mounted check after the dialog is dismissed.
    if (!mounted || confirmed != true) return;
    
    // ADDED: Set deleting state
    setState(() => _isDeleting = true); 

    try {
      final userId = context.read<AuthProvider>().user?.id;

      // 1. Create Ledger Entry for DELETE action (ENSURING it's done before the plant record is gone)
      if (userId != null) {
        await SupabaseDatabaseService.createDeletedPlantLedgerEntry(
          plantId: plantId,
          plantName: plant['name'] ?? 'Unnamed Plant',
          userId: userId,
          plantImageUrl: plant['image_url'] as String?,
        );
      }

      // 2. Delete the plant record (now safe from duplicate ledger call)
      await SupabaseDatabaseService.deletePlant(plantId, plant);
      
      // 3. Refresh the plant list
      await _loadPlants();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plant deleted and logged.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      // ADDED: Reset deleting state
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _navigateToPlantDetails(Map<String, dynamic> plant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlantDetailsPage(
          plantId: plant['id'].toString(),
          hideStoreNavigation: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('My Plants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UpdatedPlantUploadPage(),
                ),
              );
              if (result == true) {
                _loadPlants();
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(12.0),
                    shadowColor: Colors.black.withOpacity(0.1),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search plants...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  color: AppColors.accentColor,
                  onSelected: (value) {
                    setState(() {
                      _sortOrder = value;
                      _sortPlants();
                    });
                  },
                  itemBuilder: (context) {
                    const Map<String, String> sortOptions = {
                      'newest': 'Newest First',
                      'oldest': 'Oldest First',
                      'a-z': 'A-Z',
                      'z-a': 'Z-A',
                    };
                    return sortOptions.entries.map((entry) {
                      return PopupMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontFamily: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.fontFamily,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  icon: const Icon(Icons.sort, color: AppColors.primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _filteredPlants.isEmpty
                    ? const Center(child: Text('No plants found.'))
                    : RefreshIndicator(
                        onRefresh: _loadPlants,
                        child: ListView.builder(
                          itemCount: _filteredPlants.length,
                          itemBuilder: (context, index) {
                            final plant = _filteredPlants[index];
                            final plantId = plant['id'].toString();
                            final isAvailable =
                                _toBool(plant['is_available']);
                            final isFeatured =
                                _toBool(plant['is_featured']);
                            final canFeature =
                                !isFeatured && _featuredCount < _maxFeatured;

                            return Card(
                              color: AppColors.accentColor,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 16),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: plant['image_url'] != null
                                        ? DecorationImage(
                                            image:
                                                NetworkImage(plant['image_url']),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                    color: AppColors.backgroundColor,
                                  ),
                                  child: plant['image_url'] == null
                                      ? const Icon(Icons.local_florist,
                                          color: AppColors.primaryColor)
                                      : null,
                                ),
                                title: Text(
                                  plant['name'] ?? 'Unnamed Plant',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '₱${plant['price_range'] ?? 'N/A'}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildStatusChip(
                                          isAvailable
                                              ? 'Available'
                                              : 'Unavailable',
                                          isAvailable
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 8),
                                        if (isFeatured)
                                          _buildStatusChip(
                                              'Featured', Colors.purple),
                                      ],
                                    ),
                                  ],
                                ),
                                onTap: () => _navigateToPlantDetails(plant),
                                trailing: PopupMenuButton<String>(
                                  color: Colors.white,
                                  onSelected: (value) {
                                    // ADDED: Prevent re-entry if a delete operation is in progress
                                    if (_isDeleting) return;

                                    if (value == 'toggle') {
                                      _togglePlantAvailability(
                                          plantId, isAvailable);
                                    } else if (value == 'feature_toggle') {
                                      _toggleFeaturedStatus(
                                          plantId, isFeatured);
                                    } else if (value == 'delete') {
                                      _deletePlant(plantId, plant);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'toggle',
                                      child: Text(
                                        isAvailable
                                            ? 'Mark Unavailable'
                                            : 'Mark Available',
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    if (!isFeatured)
                                      PopupMenuItem(
                                        value: 'feature_toggle',
                                        enabled: canFeature,
                                        child: Text(
                                          canFeature
                                              ? 'Add to Featured'
                                              : 'Add to Featured (Max Reached: $_maxFeatured)',
                                          style: TextStyle(
                                            color: canFeature
                                                ? AppColors.primaryColor
                                                : AppColors.passiveText,
                                          ),
                                        ),
                                      )
                                    else
                                      const PopupMenuItem(
                                        value: 'feature_toggle',
                                        child: Text(
                                          'Remove from Featured',
                                          style:
                                              TextStyle(color: Colors.purple),
                                        ),
                                      ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}