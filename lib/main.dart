import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

// Providers
import 'providers/permission_provider.dart';
import 'providers/plant_provider.dart';
import 'providers/location_provider.dart';
import 'providers/auth_provider.dart';

// Services & Config
import 'services/supabase_service.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'config/env_config.dart';
import 'components/app_colors.dart';

// Pages & Widgets
import 'widgets/supabase_error_widget.dart';
import 'pages/firstpage.dart';
import 'pages/user_main_navigation.dart';
import 'seller_pages/seller_main_navigation.dart';
import 'pages/profile_page.dart';
// FIXED: Updated import to match your filename
import 'pages/combined_password_reset_page.dart'; 

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool isSupabaseInitialized = false;

Future<void> _initializeServices() async {
  try {
    await EnvConfig.load();
    await SupabaseService.initialize();
    isSupabaseInitialized = SupabaseService.isInitialized;

    if (isSupabaseInitialized) {
      debugPrint('✅ Services initialized successfully');
    }
  } catch (e) {
    debugPrint('❌ Initialization Error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Wait for Environment and Database before starting UI
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
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (isSupabaseInitialized) {
      _initDeepLinks();
      _setupAuthStateListener();
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _setupAuthStateListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        navigatorKey.currentContext?.read<PlantProvider>().clearAllFavorites();
      }
    });
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) await _handleDeepLink(initialUri);

      _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
    } catch (e) {
      debugPrint('Deep Link Error: $e');
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (!uri.toString().contains('#')) return;
    try {
      debugPrint('Processing Auth Link: $uri');
      await Supabase.instance.client.auth.getSessionFromUrl(uri);
    } catch (e) {
      debugPrint('Auth Link Error: $e');
    }
  }

  void _restartApp() {
    setState(() {});
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
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.0),
            ),
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
        errorMessage: 'Connection failed. Please check your internet.',
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // FIXED: Updated class name to match your file
        if (auth.isPasswordRecoveryInProgress) {
          return CombinedPasswordResetPage(email: auth.user?.email ?? '');
        }

        if (auth.isAuthenticated) {
          return auth.userType == 'seller'
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
      builder: (context, permissions, _) {
        if (permissions.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final auth = context.read<AuthProvider>();
        final bool isGranted = auth.userType == 'seller'
            ? permissions.isLocationGranted
            : permissions.areAllPermissionsGranted;

        return isGranted 
            ? child 
            : Stack(children: [child, const PermissionLockScreen()]);
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
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_update_warning, size: 64, color: AppColors.primaryColor),
              const SizedBox(height: 20),
              const Text(
                'Permissions Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enable location and camera in settings to continue using Plantitao.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfilePage(expandPermissionsSection: true),
                      ),
                    );
                  },
                  child: const Text('Go to Settings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}