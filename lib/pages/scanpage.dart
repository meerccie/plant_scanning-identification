// lib/pages/scanpage.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_plant/pages/profile_page.dart';
import 'package:my_plant/providers/permission_provider.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/plant_provider.dart';
import '../providers/location_provider.dart';
import '../services/plant_scanner_service.dart';
import 'scan_result_details_page.dart';
import '../components/app_colors.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;
  bool _isCapturing = false;
  final ImagePicker _picker = ImagePicker();
  XFile? _capturedImageFile;
  bool _cameraPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  // UPDATED: Standardized dialog matching plant upload and edit store design
  Future<void> _showCombinedPermissionRedirectDialog() async {
    final shouldGoToProfile = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.accentColor,
          title: const Text('Permissions Required'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Camera and location access are required to use the plant scanner. '
                  'Please grant these permissions from the App Permissions section.',
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
      
      // After returning, check permission status and reinitialize camera if needed
      final permissionProvider = context.read<PermissionProvider>();
      await permissionProvider.checkPermissions();
      
      if (!mounted) return;
      
      if (permissionProvider.isCameraGranted && permissionProvider.isLocationGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions granted! You can now use the scanner.'),
            backgroundColor: AppColors.success,
          ),
        );
        _initializeCamera(); // Reinitialize camera after permissions granted
      }
    }
  }

  Future<void> _initializeCamera() async {
    final permissionProvider = context.read<PermissionProvider>();
    await permissionProvider.checkPermissions();

    if (!permissionProvider.isCameraGranted) {
      if (mounted) {
        setState(() {
          _cameraPermissionGranted = false;
          _initializeControllerFuture = Future.value();
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _cameraPermissionGranted = true);
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No camera available')),
          );
        }
        return;
      }

      _controller = CameraController(cameras.first, ResolutionPreset.high,
          enableAudio: false);

      _initializeControllerFuture = _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization failed: $e')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions when the app resumes
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive) {
      // Dispose controller when app is inactive
      _controller?.dispose();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _scanImage(File image) async {
    if (!mounted) return;

    final plantProvider = context.read<PlantProvider>();
    final permissionProvider = context.read<PermissionProvider>();
    final locationProvider = context.read<LocationProvider>();
    await permissionProvider.checkPermissions();

    if (!permissionProvider.isLocationGranted ||
        !permissionProvider.isCameraGranted) {
      await _showCombinedPermissionRedirectDialog();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final hasLocation =
          await locationProvider.getCurrentLocationForScanning(context: context);

      if (!hasLocation && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(locationProvider.error ??
                  'Location is required to find nearby stores.')),
        );
      }

      final success = await plantProvider.scanPlant(image, locationProvider);

      if (mounted) {
        if (success && plantProvider.lastIdentification != null) {
          _showResultsDialog(plantProvider.lastIdentification!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(plantProvider.error ?? 'Failed to identify plant.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _capturedImageFile = null;
        });
      }
    }
  }

  Future<void> _captureAndFreeze() async {
    if (_isCapturing || _controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      setState(() => _isCapturing = true);

      final image = await _controller!.takePicture();
      if (!mounted) return;

      setState(() {
        _capturedImageFile = image;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<void> _scanFromGallery() async {
    final permissionProvider = context.read<PermissionProvider>();
    await permissionProvider.checkPermissions();
    if (!mounted) return;
    
    if (!permissionProvider.isCameraGranted || !permissionProvider.isLocationGranted) {
      await _showCombinedPermissionRedirectDialog();
      return;
    }

    final xFile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (xFile != null) {
      await _scanImage(File(xFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan & Identify'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: _scanFromGallery,
            tooltip: 'Scan from Gallery',
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (!_cameraPermissionGranted) {
              return _buildPermissionLockedView();
            }
            if (_controller == null || !_controller!.value.isInitialized) {
              return _buildNoCameraView();
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_capturedImageFile == null)
                  _buildCameraPreview(context), // MODIFIED: Call helper function
                if (_capturedImageFile != null)
                  SizedBox.expand(
                    child: Image.file(
                      File(_capturedImageFile!.path),
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_isProcessing || _isCapturing)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // ADDED: New helper function to fix camera stretching
  Widget _buildCameraPreview(BuildContext context) {
    // Determine the available size for the camera preview
    final size = MediaQuery.of(context).size;
    
    // Calculate the screen aspect ratio
    final deviceRatio = size.width / size.height;
    
    // Get the camera's aspect ratio (from the controller)
    final cameraRatio = _controller!.value.aspectRatio;
    
    // Calculate the scale factor required to fill the device ratio with the camera ratio
    // If device is taller than camera (deviceRatio < cameraRatio), scale up vertically
    // If device is wider than camera (deviceRatio > cameraRatio), scale up horizontally
    double scale = cameraRatio / deviceRatio;
    
    // If the ratio calculation results in a scale factor less than 1, invert it 
    // to ensure we always scale up (crop to fit) rather than scale down (letterbox)
    if (scale < 1) {
      scale = 1 / scale;
    }

    return Transform.scale(
      scale: scale,
      alignment: Alignment.center, // Center the scaled preview
      child: Center(
        child: AspectRatio(
          // Use the camera's native aspect ratio to prevent stretching
          aspectRatio: cameraRatio, 
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildPermissionLockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Permissions Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'To use the plant scanner, please grant camera and location access from your profile page.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfilePage(expandPermissionsSection: true),
                  ),
                );
              },
              icon: const Icon(Icons.person),
              label: const Text('Go to Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoCameraView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'Camera not available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can still identify plants by choosing an image from your gallery using the icon in the top-right corner.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    if (!_cameraPermissionGranted) return const SizedBox.shrink();

    if (_capturedImageFile != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton.extended(
            onPressed: () => setState(() => _capturedImageFile = null),
            label: const Text('Retake'),
            icon: const Icon(Icons.refresh),
            backgroundColor: Colors.grey,
          ),
          FloatingActionButton.extended(
            onPressed: _isProcessing
                ? null
                : () => _scanImage(File(_capturedImageFile!.path)),
            label: const Text('Scan'),
            icon: const Icon(Icons.check),
          ),
        ],
      );
    } else {
      return FloatingActionButton.large(
        onPressed: _isProcessing || _isCapturing ? null : _captureAndFreeze,
        child: _isProcessing || _isCapturing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera),
      );
    }
  }

  void _showResultsDialog(PlantIdentification identification) {
    if (identification.results.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify the plant.')),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text("We found these plants:"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: identification.results.length,
              itemBuilder: (context, index) {
                final result = identification.results[index];
                final imageUrl =
                    result.images.isNotEmpty ? result.images.first.url : null;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const Center(child: CircularProgressIndicator()),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.local_florist, size: 40),
                            ),
                          )
                        : const Icon(Icons.local_florist, size: 50),
                    title: Text(result.species.displayName),
                    subtitle: Text(result.species.commonNames.join(', ')),
                    trailing:
                        Text('${(result.score * 100).toStringAsFixed(1)}%'),
                    onTap: () {
                      final plantNameToSearch = result
                              .species.scientificNameWithoutAuthor.isNotEmpty
                          ? result.species.scientificNameWithoutAuthor
                          : result.species.displayName;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScanResultDetailsPage(
                              plantName: plantNameToSearch),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}