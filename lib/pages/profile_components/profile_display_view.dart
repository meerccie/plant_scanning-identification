import 'package:flutter/material.dart';
import 'package:my_plant/components/app_colors.dart';

class ProfileDisplayView extends StatelessWidget {
  final Map<String, dynamic> profileData;

  const ProfileDisplayView({super.key, required this.profileData});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInfoCard(
            'Email', profileData['email'] ?? 'Not set', Icons.email),
        _buildInfoCard('Username', profileData['username'] ?? 'Not set',
            Icons.person_outline),
        _buildInfoCard('Full Name', profileData['full_name'] ?? 'Not set',
            Icons.badge_outlined),
        _buildInfoCard('Phone Number',
            profileData['phone_number'] ?? 'Not set', Icons.phone_outlined),
        _buildInfoCard('Address', profileData['address'] ?? 'Not set',
            Icons.location_on_outlined),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: value == 'Not set' ? Colors.white70 : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
