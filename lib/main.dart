import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

// Corrected relative imports
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
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthStateListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        navigatorKey.currentContext?.read<PlantProvider>().clearAllFavorites();
      }
      // The AuthProvider will handle other events like passwordRecovery.
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Let the Supabase client handle session recovery from the URL.
    // The AuthProvider's listener will then pick up the state change.
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isNavigatingToReset = false;

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseInitialized) {
      return SupabaseErrorWidget(
        onRetry: () async {
          await _initializeServices();
          (navigatorKey.currentContext as Element).reassemble();
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

        // Handle password recovery - prevent duplicate navigation
        if (authProvider.isPasswordRecoveryInProgress && !_isNavigatingToReset) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isNavigatingToReset) {
              _isNavigatingToReset = true;
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.passwordResetCombined,
                (route) => false,
              );
            }
          });
          
          // Show loading while navigating
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Reset the flag when not in recovery mode
        if (!authProvider.isPasswordRecoveryInProgress) {
          _isNavigatingToReset = false;
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
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
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