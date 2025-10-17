import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/supabase_database_service.dart';
import '../services/supabase_storage_service.dart';
import '../providers/auth_provider.dart';
import '../components/app_colors.dart';
import '../widgets/enhanced_image_picker_widget.dart';
import '../services/plant_scanner_service.dart';

class UpdatedPlantUploadPage extends StatefulWidget {
  const UpdatedPlantUploadPage({super.key});

  @override
  State<UpdatedPlantUploadPage> createState() => _UpdatedPlantUploadPageState();
}

class _UpdatedPlantUploadPageState extends State<UpdatedPlantUploadPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _scientificNameController =
      TextEditingController();
  final TextEditingController _priceRangeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  File? _imageFile;
  bool _isUploading = false;
  Map<String, dynamic>? _store;
  bool _isFeatured = false;
  bool _isIdentified = false;
  bool _isLoadingStore = true;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId != null) {
      final stores = await SupabaseDatabaseService.getStoresByUser(userId);
      if (mounted && stores.isNotEmpty) {
        setState(() {
          _store = stores.first;
          _isLoadingStore = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingStore = false;
        });
      }
    } else if (mounted) {
      setState(() {
        _isLoadingStore = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_isUploading) return;
    
    if (!_formKey.currentState!.validate() ||
        _imageFile == null ||
        _store == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please fill all required fields and select an image.')),
      );
      return;
    }

    if (!_isIdentified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Plant must be successfully identified before uploading.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final imageUrl = await SupabaseStorageService.uploadImage(
          _imageFile!, 'plant_images', 'plant');
      
      if (!mounted) return;

      final plantData = {
        'name': _nameController.text.trim(),
        'scientific_name': _scientificNameController.text.trim(),
        'price_range': _priceRangeController.text.trim(),
        'description': _descriptionController.text.trim(),
        'image_url': imageUrl,
        'store_id': _store!['id'],
        'is_available': true,
        'is_featured': _isFeatured,
        'quantity': int.tryParse(_quantityController.text.trim()) ?? 0,
      };

      await SupabaseDatabaseService.createPlant(plantData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Plant uploaded successfully!'),
              backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'There was a problem uploading your plant. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _identifyPlant() async {
    if (_imageFile == null || _isUploading) return; 

    setState(() => _isUploading = true);
    _isIdentified = false;

    try {
      final identification =
          await PlantScannerService.identifyPlantEnhanced(_imageFile!);
      
      if (!mounted) return;

      if (identification.results.isNotEmpty) {
        final topResult = identification.results.first;
        setState(() {
          _scientificNameController.text =
              topResult.species.scientificNameWithoutAuthor;
          _nameController.text = topResult.species.commonNames.isNotEmpty
              ? topResult.species.commonNames.first
              : '';
          _isIdentified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Plant identified successfully! Fields are now unlocked.'),
              backgroundColor: AppColors.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not identify the plant. Please try a clearer image.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Identification failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fieldsEnabled = _isIdentified;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Upload Plant',
          style: TextStyle(
            fontFamily: 'Pacifico',
            fontSize: 24,
            color: AppColors.primaryColor,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoadingStore
            ? const Center(child: CircularProgressIndicator())
            : _store == null
                ? const Center(
                    child: Text(
                        'You must have a registered store to upload plants.'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          EnhancedImagePickerWidget(
                            onImageSelected: (file) => setState(() {
                              _imageFile = file;
                              _isIdentified = false;
                            }),
                            onImageUrlChanged: (url) {},
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _imageFile == null || _isUploading
                                ? null
                                : _identifyPlant,
                            icon: const Icon(Icons.search),
                            label: Text(_isIdentified
                                ? 'Identification Confirmed'
                                : 'Identify from Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isIdentified
                                  ? AppColors.success
                                  : AppColors.secondaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            enabled: fieldsEnabled,
                            decoration: InputDecoration(
                              labelText: 'Plant Name',
                              hintText:
                                  fieldsEnabled ? null : 'Identify plant first',
                            ),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Name is required' : null,
                          ),
                          TextFormField(
                            controller: _scientificNameController,
                            enabled: fieldsEnabled,
                            decoration: InputDecoration(
                              labelText: 'Scientific Name',
                              hintText:
                                  fieldsEnabled ? null : 'Identify plant first',
                            ),
                          ),
                          TextFormField(
                            controller: _priceRangeController,
                            enabled: fieldsEnabled,
                            decoration: InputDecoration(
                              labelText: 'Price Range (e.g., ₱100-₱200)',
                              hintText:
                                  fieldsEnabled ? null : 'Identify plant first',
                            ),
                            validator: (val) => val == null || val.isEmpty
                                ? 'Price Range is required'
                                : null,
                          ),
                          TextFormField(
                            controller: _quantityController,
                            enabled: fieldsEnabled,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                                labelText: 'Quantity in Stock',
                                hintText: fieldsEnabled
                                    ? 'Enter available stock'
                                    : 'Identify plant first'),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Quantity is required';
                              }
                              if (int.tryParse(val) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: _descriptionController,
                            enabled: fieldsEnabled,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText:
                                  fieldsEnabled ? null : 'Identify plant first',
                            ),
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Feature this Plant'),
                            subtitle: const Text(
                                'Show this plant on the top of your store page (max 5)'),
                            value: _isFeatured,
                            onChanged: fieldsEnabled
                                ? (bool value) {
                                    setState(() {
                                      _isFeatured = value;
                                    });
                                  }
                                : null,
                            secondary: const Icon(Icons.star_outline),
                            activeColor: AppColors.primaryColor,
                            tileColor: AppColors.backgroundColor,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  color: AppColors.passiveText.withAlpha(127)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isUploading || !fieldsEnabled
                                ? null
                                : _submitForm,
                            child: _isUploading
                                ? const CircularProgressIndicator()
                                : const Text('Upload Plant'),
                          )
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}