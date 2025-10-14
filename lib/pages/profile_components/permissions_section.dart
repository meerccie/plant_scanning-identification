import 'package:flutter/material.dart';
import 'package:my_plant/providers/auth_provider.dart';
import 'package:my_plant/providers/permission_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class PermissionsSection extends StatelessWidget {
  const PermissionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    // ADDED: A Consumer for AuthProvider to determine the user's role.
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final isSeller = authProvider.userType == 'seller';

        // MODIFIED: Subtitles are now dynamic based on the user's role.
        final locationSubtitle = isSeller
            ? 'Required to set your store\'s coordinates accurately.'
            : 'Required to find nearby stores and plant sellers.';
        final cameraSubtitle = isSeller
            ? 'Required for uploading images of your store and plants.'
            : 'Required for the plant scanner and identification feature.';

        return Consumer<PermissionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }
            return Column(
              children: [
                _buildPermissionItem(
                  context: context,
                  title: 'Location',
                  // MODIFIED: Passed the dynamic subtitle.
                  subtitle: locationSubtitle,
                  status: provider.locationStatus,
                  onRequest: () => provider.requestLocationPermission(),
                  onOpenSettings: () => provider.openSettings(),
                ),
                const Divider(color: Colors.white24),
                _buildPermissionItem(
                  context: context,
                  title: 'Camera',
                  // MODIFIED: Passed the dynamic subtitle.
                  subtitle: cameraSubtitle,
                  status: provider.cameraStatus,
                  onRequest: () => provider.requestCameraPermission(),
                  onOpenSettings: () => provider.openSettings(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPermissionItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required PermissionStatus status,
    required VoidCallback onRequest,
    required VoidCallback onOpenSettings,
  }) {
    String statusText;
    Color statusColor;
    Widget actionButton;

    if (status.isGranted) {
      statusText = 'Granted';
      statusColor = Colors.greenAccent;
      actionButton = const Icon(Icons.check_circle, color: Colors.greenAccent);
    } else if (status.isPermanentlyDenied) {
      statusText = 'Permanently Denied';
      statusColor = Colors.redAccent;
      actionButton = ElevatedButton(
        onPressed: onOpenSettings,
        child: const Text('Open Settings'),
      );
    } else {
      statusText = 'Denied';
      statusColor = Colors.orangeAccent;
      actionButton = ElevatedButton(
        onPressed: onRequest,
        child: const Text('Grant Access'),
      );
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            'Status: $statusText',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      trailing: actionButton,
    );
  }
}
