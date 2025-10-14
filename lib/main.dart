// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_plant/providers/permission_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'components/app_colors.dart';
import 'widgets/supabase_error_widget.dart';
import 'pages/firstpage.dart';
import 'pages/user_main_navigation.dart';
import 'seller_pages/seller_main_navigation.dart';
import 'providers/plant_provider.dart';
import 'providers/location_provider.dart';
import 'providers/auth_provider.dart';
import 'services/supabase_service.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'config/env_config.dart';
import 'pages/profile_page.dart'; // Import for lock screen navigation

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool isSupabaseInitialized = false;

Future<void> _initializeServices() async {
  try {
    // Initialize Supabase
    await SupabaseService.initialize();
    isSupabaseInitialized = SupabaseService.isInitialized;

    if (isSupabaseInitialized) {
      debugPrint('✅ Supabase initialized successfully in main.dart');
    }
  } catch (e) {
    debugPrint('❌ Error initializing services in main.dart: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use EnvConfig to load environment variables
  await EnvConfig.load();

  await _initializeServices();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    if (!isSupabaseInitialized) return;
    _initDeepLinks();
    _setupAuthStateListener();
    _setupServiceListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentContext?.read<PlantProvider>().clearAllFavorites();

        // Clear sensitive cache on sign out
        _clearSensitiveCache();
      }
    });
  }

  void _setupServiceListeners() {
    // Listen for network connectivity changes if needed
  }

  void _clearSensitiveCache() {
    // Clear any user-specific cache if needed
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.fragment.isEmpty && uri.query.isEmpty) {
      return;
    }

    try {
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e) {
      debugPrint('Error handling deep link: $e');
    }
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleDeepLink(initialUri);
      }
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
        _handleDeepLink(uri);
      });
    } catch (e) {
      debugPrint('Error initializing deep links: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => PermissionProvider()),
      ],
      child: MaterialApp(
        title: 'Plantitao',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        onGenerateRoute: AppRoutes.onGenerateRoute,
        // Enhanced error handling for the entire app
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseInitialized) {
      return SupabaseErrorWidget(
        onRetry: () async {
          await _initializeServices();
        },
        errorMessage:
            'Failed to connect to the database. Please check your internet connection and try again.',
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading Plantitao...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          // FIX: Removed the call to checkPermissions from the build method.
          // The PermissionProvider already calls this in its own constructor.
          return authProvider.userType == 'seller'
              ? const SellerMainNavigation()
              : const MainNavigation();
        }
        return const Firstpage();
      },
    );
  }
}

// NEW WIDGET: Wraps the main app and shows a lock screen if permissions are not granted.
class PermissionWrapper extends StatelessWidget {
  final Widget child;
  const PermissionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionProvider>(
      builder: (context, permissionProvider, _) {
        if (permissionProvider.isLoading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        // For sellers, we only check location. For users, we check both.
        final authProvider = context.read<AuthProvider>();
        final bool permissionsGranted =
            authProvider.userType == 'seller'
                ? permissionProvider.isLocationGranted
                : permissionProvider.areAllPermissionsGranted;

        if (permissionsGranted) {
          return child;
        } else {
          // Show the main app but with a lock screen overlay
          return Stack(
            children: [
              child, // The main UI is behind the overlay
              const PermissionLockScreen(),
            ],
          );
        }
      },
    );
  }
}

// NEW WIDGET: The overlay that blocks the app and directs users to settings.
class PermissionLockScreen extends StatelessWidget {
  const PermissionLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.75),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline,
                  size: 60, color: AppColors.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Permissions Required',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'To use all features of Plantitao, please grant the required camera and location permissions from your profile settings.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Go to Settings'),
                onPressed: () {
                  // Navigate to a new instance of the Profile Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
