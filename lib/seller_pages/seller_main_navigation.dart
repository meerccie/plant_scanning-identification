// lib/seller_pages/seller_main_navigation.dart
import 'package:flutter/material.dart';
import '../pages/unified_store_dashboard.dart'; // Use unified dashboard
import 'seller_my_plants.dart';
import 'seller_notifications.dart';
import '../pages/profile_page.dart';
import '../components/app_colors.dart'; // Import to use accentColor

class SellerMainNavigation extends StatefulWidget {
  const SellerMainNavigation({super.key});
  
  @override
  State<SellerMainNavigation> createState() => _SellerMainNavigationState();
}

class _SellerMainNavigationState extends State<SellerMainNavigation> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = const [
    UnifiedStoreDashboard(), // Use unified dashboard for seller's home
    SellerMyPlants(),
    SellerNotifications(),
    ProfilePage(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // The selected item color is a darker green, which matches the primary color palette.
        selectedItemColor: const Color(0xFF3E5A36), 
        unselectedItemColor: Colors.grey,
        // UPDATED: Set background color to accentColor
        backgroundColor: AppColors.accentColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_florist),
            label: 'My Plants',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}