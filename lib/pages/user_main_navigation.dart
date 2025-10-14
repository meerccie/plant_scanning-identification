// lib/pages/user_main_navigation.dart
import 'package:flutter/material.dart';
import '../components/app_colors.dart';
import 'user_dashboard.dart';
import 'favorites.dart';
import 'scanpage.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = const [
    DashboardPage(),
    FavoritesPage(),
    ScanPage(),
    NotificationsPage(),
    ProfilePage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primaryColor,
        unselectedItemColor: AppColors.passiveText,
        showUnselectedLabels: true,
        // UPDATED: Set background color to accentColor
        backgroundColor: AppColors.accentColor,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(
            icon: Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}