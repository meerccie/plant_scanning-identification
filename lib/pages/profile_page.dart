// lib/pages/profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_plant/providers/permission_provider.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/supabase_database_service.dart';
import '../services/supabase_storage_service.dart';
import '../components/app_colors.dart';
import 'profile_components/profile_display_view.dart';
import 'profile_components/profile_edit_view.dart';
import 'profile_components/scan_history_section.dart';
import 'profile_components/permissions_section.dart';
import 'profile_components/about_section.dart';
import 'profile_components/section_tile.dart';
import 'profile_components/plant_history_section.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;
  final bool? expandPermissionsSection;

  const ProfilePage({super.key, this.userId, this.expandPermissionsSection});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isEditing = false;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  File? _selectedImage;
  String? _currentAvatarUrl;

  // FIX: Use GlobalKey only for scrolling, not for controlling expansion
  final GlobalKey _permissionsSectionKey = GlobalKey();

  // Track user-driven expansion states for all sections
  bool _isScanHistoryExpanded = false;
  bool _isPlantHistoryExpanded = false;
  bool _isPermissionsExpanded = false;

  bool get _isViewingOwnProfile => widget.userId == null;

  @override
  void initState() {
    super.initState();
    // FIX: Set the initial expansion state based on the parameter
    _isPermissionsExpanded = widget.expandPermissionsSection == true;
    
    _loadProfileData();
    
    if (widget.expandPermissionsSection == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToPermissionsSection();
      });
    }
  }

  void _scrollToPermissionsSection() {
    final context = _permissionsSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final targetUserId = widget.userId ?? authProvider.user?.id;

    if (targetUserId != null) {
      _profileData =
          await SupabaseDatabaseService.getCompleteUserProfile(targetUserId);
    }

    if (mounted && _profileData != null) {
      _usernameController.text = _profileData!['username'] ?? '';
      _fullNameController.text = _profileData!['full_name'] ?? '';
      _phoneController.text = _profileData!['phone_number'] ?? '';
      _addressController.text = _profileData!['address'] ?? '';
      _currentAvatarUrl = _profileData!['avatar_url'];
      _selectedImage = null;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleEditMode() {
    if (_isEditing) {
      _loadProfileData();
    }
    setState(() => _isEditing = !_isEditing);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    final Map<String, dynamic> updates = {
      'username': _usernameController.text.trim(),
      'full_name': _fullNameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
    };

    if (_selectedImage != null) {
      final imageUrl = await SupabaseStorageService.replaceImage(
        newImageFile: _selectedImage!,
        oldImageUrl: _currentAvatarUrl,
        bucket: 'avatars',
        prefix: 'avatar',
      );
      updates['avatar_url'] = imageUrl;
    }

    final success = await authProvider.updateProfile(updates);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Profile updated successfully!'
              : authProvider.error ?? 'Update failed.'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
      if (success) {
        await _loadProfileData();
        setState(() => _isEditing = false);
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPermissionRedirectDialog(String permissionName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.accentColor,
          title: Text('$permissionName Permission Required'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'To use this feature, please grant $permissionName access from the App Permissions section.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmSignOut() async {
    final authProvider = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.accentColor,
        title: const Text('Confirm Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await authProvider.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isSeller = authProvider.userType == 'seller';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(_isViewingOwnProfile ? 'My Profile' : 'User Profile'),
        actions: [
          if (_isViewingOwnProfile)
            IconButton(
              icon: Icon(_isEditing
                  ? (_isLoading ? Icons.hourglass_top : Icons.save)
                  : Icons.edit),
              onPressed: _isEditing ? _saveProfile : _toggleEditMode,
              tooltip: _isEditing ? 'Save Changes' : 'Edit Profile',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleEditMode,
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
              ? const Center(child: Text('Could not load profile.'))
              : RefreshIndicator(
                  onRefresh: _loadProfileData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildProfileHeader(authProvider),
                      const SizedBox(height: 24),
                      SectionTile(
                        title: 'Profile Details',
                        icon: Icons.person_pin_outlined,
                        initiallyExpanded: false,
                        onExpansionChanged: (expanded) {},
                        child: _isEditing && _isViewingOwnProfile
                            ? ProfileEditView(
                                formKey: _formKey,
                                usernameController: _usernameController,
                                fullNameController: _fullNameController,
                                phoneController: _phoneController,
                                addressController: _addressController,
                                authProvider: authProvider,
                              )
                            : ProfileDisplayView(profileData: _profileData!),
                      ),
                      if (_isViewingOwnProfile) ...[
                        // Conditional history section
                        if (isSeller)
                          SectionTile(
                            title: 'Plant Inventory Log',
                            icon: Icons.inventory_2_outlined,
                            initiallyExpanded: _isPlantHistoryExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _isPlantHistoryExpanded = expanded;
                              });
                            },
                            child: const PlantHistorySection(),
                          )
                        else
                          SectionTile(
                            title: 'Scan History',
                            icon: Icons.history,
                            initiallyExpanded: _isScanHistoryExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _isScanHistoryExpanded = expanded;
                              });
                            },
                            child: const ScanHistorySection(),
                          ),
                        // Permissions section with Container wrapper for the key
                        Container(
                          key: _permissionsSectionKey,
                          child: SectionTile(
                            title: 'App Permissions',
                            icon: Icons.shield_outlined,
                            initiallyExpanded: _isPermissionsExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _isPermissionsExpanded = expanded;
                              });
                            },
                            child: const PermissionsSection(),
                          ),
                        ),
                        SectionTile(
                          title: 'About Plantitao',
                          icon: Icons.info_outline,
                          initiallyExpanded: false,
                          onExpansionChanged: (expanded) {},
                          child: const AboutSection(),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.logout,
                                color: AppColors.error),
                            label: const Text('Log Out',
                                style: TextStyle(color: AppColors.error)),
                            onPressed: _confirmSignOut,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileHeader(AuthProvider authProvider) {
    ImageProvider? backgroundImage;
    if (_selectedImage != null) {
      backgroundImage = FileImage(_selectedImage!);
    } else if (_currentAvatarUrl != null) {
      backgroundImage = NetworkImage(_currentAvatarUrl!);
    }

    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primaryColor,
              backgroundImage: backgroundImage,
              child: backgroundImage == null
                  ? const Icon(Icons.person, size: 50, color: Colors.white)
                  : null,
            ),
            if (_isEditing && _isViewingOwnProfile)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () async {
                    final permissionProvider =
                        context.read<PermissionProvider>();
                    await permissionProvider.checkPermissions();
                    if (!mounted) return;

                    if (!permissionProvider.isCameraGranted) {
                      _showPermissionRedirectDialog('Camera');
                      return;
                    }

                    final picker = ImagePicker();
                    final pickedFile =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      setState(() {
                        _selectedImage = File(pickedFile.path);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.secondaryColor,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 20),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _profileData?['username'] ?? _profileData?['email'] ?? 'User',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily:
                    Theme.of(context).textTheme.bodyLarge?.fontFamily,
              ),
        ),
        if (_isViewingOwnProfile)
          Builder(builder: (context) {
            final userType = authProvider.userType ?? 'user';
            final formattedUserType = userType.isNotEmpty
                ? '${userType[0].toUpperCase()}${userType.substring(1).toLowerCase()}'
                : 'User';
            return Text(
              formattedUserType,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.secondaryColor,
                    letterSpacing: 1.5,
                  ),
            );
          }),
      ],
    );
  }
}
