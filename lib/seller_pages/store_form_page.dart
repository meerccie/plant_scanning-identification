// lib/seller_pages/store_form_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_database_service.dart';
import '../services/supabase_storage_service.dart';
import '../providers/auth_provider.dart';
import '../components/input_field.dart';
import '../components/custom_button.dart';
import '../providers/location_provider.dart';
import '../components/app_colors.dart';
import 'store_form_widgets/time_picker_field.dart';
import 'store_form_widgets/image_and_location_inputs.dart';
import '../pages/profile_page.dart';
import '../providers/permission_provider.dart';

class StoreFormPage extends StatefulWidget {
  final Map<String, dynamic>? store;

  const StoreFormPage({super.key, this.store});

  @override
  State<StoreFormPage> createState() => _StoreFormPageState();
}

class _StoreFormPageState extends State<StoreFormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;

  // REFACTORED: Image state is now managed by ImageAndLocationInputs widget.
  // These lists will be updated by the child widget's callback.
  List<File> _newImagesToUpload = [];
  List<String> _existingUrlsToKeep = [];

  bool _isLoading = false;
  double? _currentLatitude;
  double? _currentLongitude;

  bool get isEditMode => widget.store != null;

  @override
  void initState() {
    super.initState();
    if (isEditMode && widget.store != null) {
      final store = widget.store!;
      _nameController.text = store['name'] ?? '';
      _descriptionController.text = store['description'] ?? '';
      _addressController.text = store['address'] ?? '';
      _phoneNumberController.text = store['phone_number'] ?? '';

      // Initialize the list of URLs to keep.
      if (store['image_urls'] is List) {
        _existingUrlsToKeep = List<String>.from(store['image_urls']);
      }

      _currentLatitude = (store['latitude'] as num?)?.toDouble();
      _currentLongitude = (store['longitude'] as num?)?.toDouble();

      if (store['opening_time'] != null) {
        final parts = store['opening_time'].toString().split(':');
        _openingTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (store['closing_time'] != null) {
        final parts = store['closing_time'].toString().split(':');
        _closingTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  // REMOVED: All image handling logic (_pickImage, _showCameraPermissionRedirectDialog, etc.)
  // has been moved to the ImageAndLocationInputs widget.

  Future<void> _showLocationPermissionRedirectDialog() async {
    if (!mounted) return;
    
    final shouldGoToProfile = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.accentColor,
          title: const Text('Location Permission Required'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Location access is required to set your store coordinates. '
                  'Please grant location permission from the App Permissions section.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Profile'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (shouldGoToProfile == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfilePage(expandPermissionsSection: true),
        ),
      );
      
      if (!mounted) return;
      final permissionProvider = context.read<PermissionProvider>();
      await permissionProvider.checkPermissions();
      
      if (!mounted) return;
      
      if (permissionProvider.isLocationGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission granted! You can now set coordinates.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _fetchAndSetLocation() async {
    final permissionProvider = context.read<PermissionProvider>();
    await permissionProvider.checkPermissions();
    
    if (!mounted) return;
    
    if (!permissionProvider.isLocationGranted) {
      await _showLocationPermissionRedirectDialog();
      return;
    }

    setState(() => _isLoading = true);
    final locationProvider = context.read<LocationProvider>();
    
    try {
      final success = await locationProvider.getCurrentLocation(context: context);
      
      if (!mounted) return;

      if (success && locationProvider.currentPosition != null) {
        setState(() {
          _currentLatitude = locationProvider.currentPosition!.latitude;
          _currentLongitude = locationProvider.currentPosition!.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated using GPS!')),
        );
      } else if (locationProvider.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(locationProvider.error!)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectTime(bool isOpening) async {
    final initialTime = isOpening ? _openingTime : _closingTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
      });
    }
  }

  String? _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentLatitude == null || _currentLongitude == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location coordinates are missing. Please tap "Get Current Location".')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.user?.id;
      if (userId == null) throw Exception('User not authenticated');

      // REFACTORED: Use the state variables updated by the child widget.
      List<String> finalImageUrls = List.from(_existingUrlsToKeep);
      for (final imageFile in _newImagesToUpload) {
        final imageUrl = await SupabaseStorageService.uploadImage(
            imageFile, 'store_images', 'store_extra');
        
        if (!mounted) return;
        
        if (imageUrl != null) {
          finalImageUrls.add(imageUrl);
        }
      }
      
      if (!mounted) return;

      final storeData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _currentLatitude,
        'longitude': _currentLongitude,
        'image_urls': finalImageUrls, // Use the final combined list
        'user_id': userId,
        'phone_number': _phoneNumberController.text.trim(),
        'opening_time': _formatTimeOfDay(_openingTime),
        'closing_time': _formatTimeOfDay(_closingTime),
      };

      if (isEditMode) {
        await SupabaseDatabaseService.updateStore(
            widget.store!['id'].toString(), storeData);
      } else {
        await SupabaseDatabaseService.createStore(storeData);
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Store ${isEditMode ? 'updated' : 'created'} successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Store' : 'Create Store',
          style: const TextStyle(
            fontFamily: 'Pacifico',
            color: AppColors.primaryColor,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // REFACTORED: ImageAndLocationInputs now manages its own image state.
              ImageAndLocationInputs(
                initialImageUrls: _existingUrlsToKeep,
                onImagesChanged: (newImages, existingUrls) {
                  setState(() {
                    _newImagesToUpload = newImages;
                    _existingUrlsToKeep = existingUrls;
                  });
                },
                currentLatitude: _currentLatitude,
                currentLongitude: _currentLongitude,
                isLoading: _isLoading,
                onFetchLocationPressed: _fetchAndSetLocation,
              ),
              const SizedBox(height: 20),
              
              CustomInputField(
                  controller: _nameController, label: 'Store Name'),
              CustomInputField(
                  controller: _descriptionController,
                  label: 'Description',
                  maxLines: 3),
              CustomInputField(
                  controller: _addressController, label: 'Physical Address'),
              CustomInputField(
                controller: _phoneNumberController,
                label: 'Store Phone Number',
                keyboardType: TextInputType.phone,
                hintText: 'e.g., (09XX) XXX-XXXX',
                maxLines: 1,
              ),

              const SizedBox(height: 20),
              
              Text('Business Hours/Schedule',
                  style: TextStyle(
                    fontFamily: 'Pacifico',
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TimePickerField(
                      label: 'Opening Time',
                      time: _openingTime,
                      onTap: () => _selectTime(true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TimePickerField(
                      label: 'Closing Time',
                      time: _closingTime,
                      onTap: () => _selectTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              CustomButton(
                onPressed: _isLoading ? null : _submitForm,
                text: isEditMode ? 'Update Store' : 'Create Store',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}