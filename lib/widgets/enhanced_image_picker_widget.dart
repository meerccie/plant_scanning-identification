// enhanced_image_picker_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_plant/pages/profile_page.dart';
import 'package:my_plant/providers/permission_provider.dart';
import 'package:provider/provider.dart';
import 'package:my_plant/components/app_colors.dart';

// CORRECTED: Moved the enum declaration outside the class.
enum DialogAction { cancel, goToProfile }

class EnhancedImagePickerWidget extends StatefulWidget {
  final String? initialImageUrl;
  final ValueChanged<File?> onImageSelected;
  final ValueChanged<String?> onImageUrlChanged;
  final double maxWidth;
  final double maxHeight;
  final int imageQuality;
  final bool allowEditing;

  const EnhancedImagePickerWidget({
    super.key,
    this.initialImageUrl,
    required this.onImageSelected,
    required this.onImageUrlChanged,
    this.maxWidth = 1024,
    this.maxHeight = 1024,
    this.imageQuality = 85,
    this.allowEditing = true,
  });

  @override
  State<EnhancedImagePickerWidget> createState() =>
      _EnhancedImagePickerWidgetState();
}

class _EnhancedImagePickerWidgetState extends State<EnhancedImagePickerWidget> {
  File? _selectedImage;
  String? _imageUrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
  }

  // UPDATED: This dialog is now stricter and doesn't offer a gallery option.
  Future<void> _showCameraPermissionDialog() async {
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
                  'To add an image, camera access is required. Please grant camera permission from the App Permissions section in your profile.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(DialogAction.cancel);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Profile'),
              onPressed: () {
                Navigator.of(context).pop(DialogAction.goToProfile);
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    switch (action) {
      case DialogAction.goToProfile:
        // Redirect to profile page with permissions section expanded
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ProfilePage(expandPermissionsSection: true),
          ),
        );

        // After returning from profile, check permission status
        if (!mounted) return;
        final permissionProvider =
            Provider.of<PermissionProvider>(context, listen: false);
        await permissionProvider.checkPermissions();

        if (!mounted) return;
        // Show feedback based on permission status
        if (permissionProvider.isCameraGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Camera permission granted! You can now use the camera.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        break;
      case DialogAction.cancel:
      default:
        // Do nothing
        break;
    }
  }

  // This internal method still exists but is only called if permission is granted.
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      setState(() => _isProcessing = true);

      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        imageQuality: widget.imageQuality,
      );

      if (image != null) {
        final file = File(image.path);

        final fileSize = await file.length();
        const maxSize = 10 * 1024 * 1024;
        if (fileSize > maxSize) {
          _showError('Image file is too large. Maximum size is 10MB.');
          return;
        }

        final extension = image.path.split('.').last.toLowerCase();
        const allowedFormats = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
        if (!allowedFormats.contains(extension)) {
          _showError(
              'Unsupported image format. Please use JPG, PNG, GIF, BMP, or WEBP.');
          return;
        }

        if (mounted) {
          setState(() {
            _selectedImage = file;
            _imageUrl = null; 
          });
          widget.onImageSelected(_selectedImage);
          widget.onImageUrlChanged(null);
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // UPDATED: This is the new entry point for adding an image.
  // It checks permissions first.
  Future<void> _handleAddImageTapped() async {
    final permissionProvider = Provider.of<PermissionProvider>(context, listen: false);
    await permissionProvider.checkPermissions();

    if (!mounted) return;

    if (permissionProvider.isCameraGranted) {
      // If permission is already granted, show the choice modal
      _showImageSourceModal();
    } else {
      // If permission is not granted, show the redirect dialog immediately.
      // This enforces the camera permission requirement upfront.
      await _showCameraPermissionDialog();
    }
  }

  void _showImageSourceModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImageSourceButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _ImageSourceButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                ],
              ),
              if (_selectedImage != null ||
                  (_imageUrl != null && _imageUrl!.isNotEmpty)) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _removeImage();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Remove Image',
                        style: TextStyle(color: Colors.red)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
    });
    widget.onImageSelected(null);
    widget.onImageUrlChanged(null);
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red[600],
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Preview Container
        GestureDetector(
          onTap: _isProcessing ? null : _handleAddImageTapped, // UPDATED
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF3E5A36).withAlpha(80),
                width: 2,
              ),
            ),
            child: _isProcessing
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF3E5A36),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Processing image...',
                          style: TextStyle(
                            color: Color(0xFF3E5A36),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _selectedImage != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(153),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.white, size: 18),
                                onPressed: _handleAddImageTapped, // UPDATED
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                          // Image info overlay
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withAlpha(178),
                                  ],
                                ),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              padding: const EdgeInsets.all(12),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Image selected',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : _imageUrl != null && _imageUrl!.isNotEmpty
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: const Color(0xFF3E5A36),
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholder(isError: true);
                                  },
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(153),
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.white, size: 18),
                                    onPressed: _handleAddImageTapped, // UPDATED
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _buildPlaceholder(),
          ),
        ),
        const SizedBox(height: 12),

        // Action Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _handleAddImageTapped, // UPDATED
            icon: Icon(
              (_selectedImage != null ||
                      (_imageUrl != null && _imageUrl!.isNotEmpty))
                  ? Icons.edit
                  : Icons.add_photo_alternate,
            ),
            label: Text(
              (_selectedImage != null ||
                      (_imageUrl != null && _imageUrl!.isNotEmpty))
                  ? 'Change Image'
                  : 'Add Image',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E5A36),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Help text
        Center(
          child: Text(
            'Supported formats: JPG, PNG, GIF, BMP, WEBP • Max size: 10MB',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder({bool isError = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isError ? Colors.red[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.add_photo_alternate_outlined,
            size: 48,
            color: isError ? Colors.red[400] : Colors.grey[500],
          ),
          const SizedBox(height: 12),
          Text(
            isError ? 'Failed to load image' : 'Tap to add image',
            style: TextStyle(
              fontSize: 16,
              color: isError ? Colors.red[600] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isError ? 'Try selecting a different image' : 'Upload a photo to showcase',
            style: TextStyle(
              fontSize: 12,
              color: isError ? Colors.red[400] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF3E5A36).withAlpha(20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3E5A36).withAlpha(51),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3E5A36).withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: const Color(0xFF3E5A36),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3E5A36),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

