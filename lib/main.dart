// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import 'providers/permission_provider.dart';
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
import 'pages/profile_page.dart';

final shorebirdCodePush = ShorebirdCodePush();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool isSupabaseInitialized = false;

Future<void> _initializeServices() async {
  try {
    await EnvConfig.load();
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

  // For Shorebird 1.0.0, no initialization is needed
  // The package auto-initializes

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
  int? _currentPatchNumber;

  void _restartApp() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (!isSupabaseInitialized) return;
    _initDeepLinks();
    _setupAuthStateListener();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    try {
      // Check if Shorebird is available
      final isShorebirdAvailable = await shorebirdCodePush.isShorebirdAvailable();
      
      if (!isShorebirdAvailable) {
        debugPrint('Shorebird Engine not available');
        return;
      }

      // Get current patch number
      _currentPatchNumber = await shorebirdCodePush.currentPatchNumber();
      debugPrint('Current patch number: $_currentPatchNumber');

      // Check for new patches
      final newPatchNumber = await shorebirdCodePush.nextPatchNumber();
      
      if (newPatchNumber != null && _currentPatchNumber != null && newPatchNumber > _currentPatchNumber!) {
        debugPrint('New patch available: $newPatchNumber');
        
        // Download and apply the update
        await shorebirdCodePush.downloadUpdateIfAvailable();
        
        // Optional: Force restart after update
        // WidgetsBinding.instance.addPostFrameCallback((_) {
        //   _restartApp();
        // });
      } else {
        debugPrint('No new patches available');
      }
    } catch (error) {
      debugPrint('Error checking for updates: $error');
    }
  }

  void _setupAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentContext?.read<PlantProvider>().clearAllFavorites();
      }
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (!uri.toString().contains('#')) {
      debugPrint('Ignoring deep link without auth fragment: $uri');
      return;
    }
    try {
      debugPrint('Handling auth deep link: $uri');
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
        home: AuthWrapper(onRetry: _restartApp),
        onGenerateRoute: AppRoutes.onGenerateRoute,
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
  final VoidCallback onRetry;
  const AuthWrapper({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseInitialized) {
      return SupabaseErrorWidget(
        onRetry: () async {
          await _initializeServices();
          onRetry();
        },
        errorMessage:
            'Failed to connect to the database. Please check your internet connection and try again.',
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        bool isNavigatingToReset = false;

        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading Plantitao...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          );
        }

        if (authProvider.isPasswordRecoveryInProgress && !isNavigatingToReset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.findRenderObject() != null) {
              isNavigatingToReset = true;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.passwordResetCombined,
                (route) => false,
                arguments: authProvider.user?.email ?? '',
              );
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (authProvider.isAuthenticated) {
          return authProvider.userType == 'seller'
              ? const SellerMainNavigation()
              : const MainNavigation();
        }

        return const Firstpage();
      },
    );
  }
}

class PermissionWrapper extends StatelessWidget {
  final Widget child;
  const PermissionWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionProvider>(
      builder: (context, permissionProvider, _) {
        if (permissionProvider.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final authProvider = context.read<AuthProvider>();
        final bool permissionsGranted = authProvider.userType == 'seller'
            ? permissionProvider.isLocationGranted
            : permissionProvider.areAllPermissionsGranted;

        if (permissionsGranted) {
          return child;
        } else {
          return Stack(
            children: [
              child,
              const PermissionLockScreen(),
            ],
          );
        }
      },
    );
  }
}

class PermissionLockScreen extends StatelessWidget {
  const PermissionLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withAlpha(191), // ~75% opacity
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
              const Icon(Icons.lock_outline, size: 60, color: AppColors.primaryColor),
              const SizedBox(height: 16),
              const Text(
                'Permissions Required', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryColor), 
                textAlign: TextAlign.center
              ),
              const SizedBox(height: 12),
              const Text(
                'To use all features of Plantitao, please grant the required camera and location permissions from your profile settings.', 
                textAlign: TextAlign.center, 
                style: TextStyle(fontSize: 16, color: AppColors.textSecondary)
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Go to Settings'),
                onPressed: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => const ProfilePage(expandPermissionsSection: true)
                    )
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