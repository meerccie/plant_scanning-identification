// lib/pages/unified_store_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_colors.dart';
import '../services/supabase_service.dart';
import '../services/supabase_database_service.dart';
import '../providers/plant_provider.dart';
import '../seller_pages/store_form_page.dart';
import 'store_dashboard_components/store_header.dart';
import 'store_dashboard_components/store_featured_plants.dart';

class UnifiedStoreDashboard extends StatefulWidget {
  final String? sellerId;
  final bool isViewOnly;

  const UnifiedStoreDashboard({
    super.key,
    this.sellerId,
    this.isViewOnly = false,
  });

  @override
  State<UnifiedStoreDashboard> createState() => _UnifiedStoreDashboardState();
}

class _UnifiedStoreDashboardState extends State<UnifiedStoreDashboard> {
  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _featuredStorePlants = [];
  List<Map<String, dynamic>> _allStorePlants = [];
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isOwner => !widget.isViewOnly;
  String? get _targetUserId =>
      widget.sellerId ?? SupabaseService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_targetUserId == null) {
        _setError('User not authenticated.');
        return;
      }
      _fetchStoreData();
      if (!_isOwner) {
        context.read<PlantProvider>().loadFavoriteStores();
      }
    });
  }

  Future<void> _fetchStoreData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final sellerData =
          await SupabaseDatabaseService.getSellerProfile(_targetUserId!);

      if (sellerData == null) {
        _setError('Seller profile could not be loaded.');
        return;
      }

      if (mounted) {
        setState(() {
          if (sellerData['store_id'] != null) {
            _store = {
              'id': sellerData['store_id'].toString(),
              'name': sellerData['store_name'],
              'description': sellerData['store_description'],
              'image_urls': sellerData['image_urls'] ?? [], // Updated
              'address': sellerData['address'],
              'phone_number': sellerData['phone_number'],
              'opening_time': sellerData['opening_time'],
              'closing_time': sellerData['closing_time'],
            };
            _loadStorePlants();
          } else if (_isOwner) {
            _setError(
                'No store registered. Please register your store to begin selling.');
          } else {
            _setError('Store details could not be found.');
          }
        });
      }
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return false;
  }

  Future<void> _loadStorePlants() async {
    if (_store == null) return;
    final storeId = _store!['id'];
    final allPlants = await SupabaseDatabaseService.getAllStorePlants(storeId);
    final featured = allPlants.where((p) {
      final isFeatured = _toBool(p['is_featured']);
      final isAvailable = _toBool(p['is_available']);
      return isFeatured && isAvailable;
    }).take(5).toList();

    if (mounted) {
      setState(() {
        _featuredStorePlants = featured;
        _allStorePlants = allPlants;
      });
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  void _onEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoreFormPage(store: _store)),
    );
    if (result == true) _fetchStoreData();
  }

  void _onToggleFavorite() async {
    if (_store == null) return;
    final plantProvider = context.read<PlantProvider>();
    await plantProvider.toggleFavoriteStore(_store!['id']);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _store == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(title: const Text('Store')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_outlined,
                    size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                if (_isOwner &&
                    _errorMessage!.contains('No store registered')) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_business),
                    label: const Text('Register My Store'),
                    onPressed: _onEdit,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _fetchStoreData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                _store?['name'] ?? 'Store',
                style: TextStyle(
                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                  color: AppColors.primaryColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.backgroundColor,
              elevation: 0,
              pinned: false,
              floating: true,
              snap: true,
            ),
            StoreHeader(
              store: _store,
              isOwner: _isOwner,
              onEdit: _onEdit,
              onToggleFavorite: _onToggleFavorite,
            ),
            SliverToBoxAdapter(
              child: StoreFeaturedPlants(
                store: _store,
                featuredPlants: _featuredStorePlants,
                allPlants: _allStorePlants,
                isOwner: _isOwner,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

