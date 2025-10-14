// lib/config/app_routes.dart
import 'package:flutter/material.dart';
import '../pages/firstpage.dart';
import '../pages/loginpage.dart';
import '../pages/registerpage.dart';
import '../pages/email_confirmation_page.dart';
import '../pages/combined_password_reset_page.dart';
import '../pages/user_main_navigation.dart';
import '../pages/profile_page.dart';
import '../pages/unified_store_dashboard.dart';
import '../seller_pages/seller_main_navigation.dart';
import '../pages/plant_details_page.dart';

class AppRoutes {
  static const String first = '/first';
  static const String login = '/login';
  static const String register = '/register';
  static const String searchResults = '/search-results';
  static const String plantDetails = '/plant-details';
  static const String storeDetails = '/store-details';
  static const String sellerDashboardView = '/seller-dashboard-view';
  static const String passwordResetCombined = '/password-reset-combined';
  static const String emailConfirmation = '/email-confirmation';
  static const String userMain = '/user-main';
  static const String sellerMain = '/seller-main';
  static const String profile = '/profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case first:
        return MaterialPageRoute(builder: (_) => const Firstpage());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterPage());
      case plantDetails:
        final plantId = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => PlantDetailsPage(plantId: plantId));
      case storeDetails:
      case sellerDashboardView:
        final sellerId = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => UnifiedStoreDashboard(sellerId: sellerId, isViewOnly: true));
      case passwordResetCombined:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => CombinedPasswordResetPage(email: email));
      case emailConfirmation:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(builder: (_) => EmailConfirmationPage(email: email));
      case userMain:
        return MaterialPageRoute(builder: (_) => const MainNavigation());
      case sellerMain:
        return MaterialPageRoute(builder: (_) => const SellerMainNavigation());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      default:
        return MaterialPageRoute(builder: (_) => const Firstpage());
    }
  }
}