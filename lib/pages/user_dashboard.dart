// lib/pages/user_dashboard.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/perenual_service.dart';
import '../services/supabase_database_service.dart';
import '../providers/plant_provider.dart';
import 'dashboard_components/daily_guide_card.dart';
import 'dashboard_components/featured_plants_carousel.dart';
import 'dashboard_components/favorite_store_listings.dart';
import '../components/app_colors.dart';
import '../providers/auth_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // State variables
  Map<String, dynamic>? _dailyGuide;
  List<Map<String, dynamic>> _featuredPlants = [];
  bool _isGuideLoading = true; // Start as true
  bool _isLoadingFeatured = true;
  bool _isFetchingGuide = false;
  String? _lastCheckedUserType;

  @override
  void initState() {
    super.initState();
    
    // Load initial data that doesn't depend on user type
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadFeaturedPlants();
        context.read<PlantProvider>().loadFavorites();
        context.read<PlantProvider>().loadFavoriteStores();
      }
    });
  }

  // FIX: Use didChangeDependencies to safely react to Provider changes.
  // This is the correct lifecycle method for this task.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkAndInitializeDailyGuide();
  }

  /// Check if we can initialize the daily guide based on current auth state.
  /// This is now safe to call from didChangeDependencies.
  void _checkAndInitializeDailyGuide() {
    final authProvider = context.read<AuthProvider>();
    
    // Don't proceed if AuthProvider is still loading its initial state or profile
    if (authProvider.isLoading || authProvider.isProfileLoading) {
      debugPrint("⏳ AuthProvider or profile still loading, waiting...");
      return;
    }
    
    final userType = authProvider.userType;
    
    // Only fetch if the user type has changed since the last check
    if (_lastCheckedUserType == userType) {
      return;
    }
    
    debugPrint("🔍 Initializing for user type: $userType");
    _lastCheckedUserType = userType;
    
    // If user is a seller, just mark as not loading (no API call)
    if (userType == 'seller') {
      debugPrint("✅ User is SELLER - skipping daily guide API call");
      if (mounted) {
        setState(() {
          _dailyGuide = null;
          _isGuideLoading = false;
        });
      }
      return;
    }
    
    // User is a regular user - fetch the daily guide
    if (userType == 'user' || userType == null) {
      debugPrint("✅ User is REGULAR USER - fetching daily guide");
      if (mounted && !_isFetchingGuide) {
        _fetchAndSetDailyGuide();
      }
    }
  }

  /// Fetches all data again for pull-to-refresh.
  Future<void> _refreshDashboard() async {
    final authProvider = context.read<AuthProvider>();
    final userType = authProvider.userType;
    
    debugPrint("🔄 Refreshing dashboard for user type: $userType");
    
    // Only fetch daily guide for regular users
    if (userType != 'seller' && !_isFetchingGuide) {
      debugPrint("📡 Fetching daily guide for regular user");
      await _fetchAndSetDailyGuide();
    } else {
      debugPrint("⏭️ Skipping daily guide");
      if (mounted && userType == 'seller') {
        setState(() => _dailyGuide = null);
      }
    }
    
    await _loadFeaturedPlants();
    if (mounted) {
      await context.read<PlantProvider>().loadFavorites();
      await context.read<PlantProvider>().loadFavoriteStores();
    }
  }

  // --- Data Fetching Methods ---

  Future<void> _fetchAndSetDailyGuide() async {
    if (!mounted) {
      debugPrint("⚠️ Widget not mounted, aborting fetch");
      return;
    }

    // Prevent concurrent calls
    if (_isFetchingGuide) {
      debugPrint("⚠️ Already fetching daily guide, skipping");
      return;
    }

    // Final safety check
    final authProvider = context.read<AuthProvider>();
    final userType = authProvider.userType;
    
    if (userType == 'seller') {
      debugPrint("🛑 BLOCKED: User is seller, aborting API call");
      if (mounted) {
        setState(() {
          _dailyGuide = null;
          _isGuideLoading = false;
        });
      }
      return;
    }

    _isFetchingGuide = true;
    if (mounted) setState(() => _isGuideLoading = true);
    
    debugPrint("📡 Starting daily guide fetch for user type: $userType");
    
    try {
      final guide = await PerenualService.getDailyPlantGuide();
      if (mounted) {
        setState(() => _dailyGuide = guide);
        debugPrint("✅ Daily guide fetched successfully");
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch daily guide: $e");
      if (mounted) {
        setState(() => _dailyGuide = null);
      }
    } finally {
      _isFetchingGuide = false;
      if (mounted) setState(() => _isGuideLoading = false);
    }
  }

  Future<void> _loadFeaturedPlants() async {
    if (!mounted) return;
    setState(() => _isLoadingFeatured = true);
    try {
      final plants = await SupabaseDatabaseService.getFeaturedPlants();
      if (mounted) {
        setState(() {
          _featuredPlants = plants.take(6).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading featured plants: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingFeatured = false);
    }
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: AppColors.primaryColor,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DailyGuideCard(
                  guide: _dailyGuide,
                  isLoading: _isGuideLoading,
                ),
              ),
              const SizedBox(height: 30),
              FeaturedPlantsCarousel(
                featuredPlants: _featuredPlants,
                isLoading: _isLoadingFeatured,
              ),
              const FavoriteStoreListings(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widget Builders ---

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.backgroundColor,
      elevation: 0,
      title: Row(
        children: [
          Image.asset('assets/images/plant_img1.png', height: 30, width: 30),
          const SizedBox(width: 8),
          const Text('Plantitao'),
        ],
      ),
    );
  }
}

