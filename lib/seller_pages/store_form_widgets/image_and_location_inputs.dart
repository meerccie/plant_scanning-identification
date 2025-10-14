// lib/seller_pages/store_form_widgets/image_and_location_inputs.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../components/app_colors.dart';
import '../../pages/profile_page.dart';
import '../../providers/permission_provider.dart';

// CORRECTED: Moved the enum declaration outside the class.
enum DialogAction { cancel, goToProfile }

// REFACTORED: Converted to a StatefulWidget to manage its own image state.
class ImageAndLocationInputs extends StatefulWidget {
  final List<String> initialImageUrls;
  final Function(List<File> newImages, List<String> existingUrls) onImagesChanged;
  final double? currentLatitude;
  final double? currentLongitude;
  final bool isLoading;
  final VoidCallback onFetchLocationPressed;

  const ImageAndLocationInputs({
    super.key,
    required this.initialImageUrls,
    required this.onImagesChanged,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.isLoading,
    required this.onFetchLocationPressed,
  });

  @override
  State<ImageAndLocationInputs> createState() => _ImageAndLocationInputsState();
}

class _ImageAndLocationInputsState extends State<ImageAndLocationInputs> {
  final List<File> _selectedImages = [];
  late List<String> _currentImageUrls;

  @override
  void initState() {
    super.initState();
    _currentImageUrls = List.from(widget.initialImageUrls);
  }

  // Helper to notify the parent widget about changes.
  void _notifyParent() {
    widget.onImagesChanged(_selectedImages, _currentImageUrls);
  }

  // MOVED: All image handling logic is now inside this widget.
  Future<void> _showCameraPermissionRedirectDialog() async {
    if (!mounted) return;

    final action = await showDialog<DialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.accentColor,
          title: const Text('Camera Access Required'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'To add an image, camera access is required. Please grant camera permission from your profile settings.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(DialogAction.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Profile'),
              onPressed: () => Navigator.of(context).pop(DialogAction.goToProfile),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (action == DialogAction.goToProfile) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfilePage(expandPermissionsSection: true),
        ),
      );
      if (!mounted) return;
      final permissionProvider = context.read<PermissionProvider>();
      await permissionProvider.checkPermissions();
      if (!mounted) return;
      if (permissionProvider.isCameraGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission granted! You can now add images.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null && mounted) {
      setState(() {
        _selectedImages.add(File(image.path));
      });
      _notifyParent();
    }
  }

  Future<void> _onAddImagePressed() async {
    if (_selectedImages.length + _currentImageUrls.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can upload a maximum of 3 images.')),
        );
      }
      return;
    }

    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    await permissionProvider.checkPermissions();

    if (!mounted) return;

    if (!permissionProvider.isCameraGranted) {
      await _showCameraPermissionRedirectDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImagePicker(),
        const SizedBox(height: 20),
        Text('Store Location Coordinates',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.primaryColor)),
        const SizedBox(height: 8),
        _buildLocationDisplay(),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: widget.isLoading ? null : widget.onFetchLocationPressed,
          icon: const Icon(Icons.gps_fixed),
          label: const Text('Get Current Location'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Store Images (Up to 3)',
          style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textSecondary.withAlpha(127)),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._currentImageUrls.map((url) => _buildImageThumbnail(url, null)),
              ..._selectedImages.map((file) => _buildImageThumbnail(null, file)),
              if (_currentImageUrls.length + _selectedImages.length < 3)
                _buildAddImageButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageThumbnail(String? imageUrl, File? imageFile) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: (imageFile != null
                        ? FileImage(imageFile)
                        : NetworkImage(imageUrl!)) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (imageFile != null) {
                    _selectedImages.remove(imageFile);
                  } else if (imageUrl != null) {
                    _currentImageUrls.remove(imageUrl);
                  }
                });
                _notifyParent();
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageButton() {
    return GestureDetector(
      onTap: _onAddImagePressed,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.add_a_photo, color: Colors.grey),
      ),
    );
  }

  Widget _buildLocationDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latitude: ${widget.currentLatitude?.toStringAsFixed(6) ?? 'Not Set'}',
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        Text(
          'Longitude: ${widget.currentLongitude?.toStringAsFixed(6) ?? 'Not Set'}',
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

