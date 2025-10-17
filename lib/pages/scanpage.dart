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
import '../widgets/scanning_animation_widget.dart';

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
        _initializeCamera();
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

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

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
      _initializeCamera();
    } else if (state == AppLifecycleState.inactive) {
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan & Identify'),
        backgroundColor: Colors.black,
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
            return _buildCameraView();
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildCameraView() {
    final cameraAspectRatio = _controller!.value.previewSize != null 
        ? _controller!.value.previewSize!.width / _controller!.value.previewSize!.height
        : 3 / 4;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_capturedImageFile == null)
          AspectRatio(
            aspectRatio: cameraAspectRatio,
            child: CameraPreview(_controller!),
          )
        else
          Center(
            child: AspectRatio(
              aspectRatio: cameraAspectRatio,
              child: Image.file(
                File(_capturedImageFile!.path),
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        if (_capturedImageFile == null)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryColor,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  _buildCornerDecoration(Alignment.topLeft),
                  _buildCornerDecoration(Alignment.topRight),
                  _buildCornerDecoration(Alignment.bottomLeft),
                  _buildCornerDecoration(Alignment.bottomRight),
                  
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Position plant within frame',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        if (_isProcessing || _isCapturing)
          Container(
            color: Colors.black87,
            child: ScanningAnimationWidget(
              text: _isCapturing ? 'Capturing...' : 'Analyzing plant...',
            ),
          ),
      ],
    );
  }

  Widget _buildCornerDecoration(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: alignment == Alignment.topLeft || alignment == Alignment.topRight
                ? BorderSide(color: AppColors.primaryColor, width: 4)
                : BorderSide.none,
            bottom: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight
                ? BorderSide(color: AppColors.primaryColor, width: 4)
                : BorderSide.none,
            left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft
                ? BorderSide(color: AppColors.primaryColor, width: 4)
                : BorderSide.none,
            right: alignment == Alignment.topRight || alignment == Alignment.bottomRight
                ? BorderSide(color: AppColors.primaryColor, width: 4)
                : BorderSide.none,
          ),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'To use the plant scanner, please grant camera and location access from your profile page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 10),
            const Text(
              'You can still identify plants by choosing an image from your gallery using the icon in the top-right corner.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
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
            backgroundColor: Colors.grey[800],
          ),
          FloatingActionButton.extended(
            onPressed: _isProcessing
                ? null
                : () => _scanImage(File(_capturedImageFile!.path)),
            label: const Text('Scan'),
            icon: const Icon(Icons.check),
            backgroundColor: AppColors.primaryColor,
          ),
        ],
      );
    } else {
      return FloatingActionButton.large(
        backgroundColor: AppColors.primaryColor,
        onPressed: _isProcessing || _isCapturing ? null : _captureAndFreeze,
        child: _isProcessing || _isCapturing
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera, size: 36),
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
        return Dialog(
          // --- MODIFIED: Set the background color ---
          backgroundColor: AppColors.backgroundColor,
          insetPadding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              minWidth: 350,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Plant Identification Results",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "We found these potential matches:",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: identification.results.length,
                      itemBuilder: (context, index) {
                        final result = identification.results[index];
                        final imageUrl =
                            result.images.isNotEmpty ? result.images.first.url : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async { 
                                final plantNameToSearch = result
                                        .species.scientificNameWithoutAuthor.isNotEmpty
                                    ? result.species.scientificNameWithoutAuthor
                                    : result.species.displayName;
                                
                                Navigator.of(context).pop();
                                
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScanResultDetailsPage(
                                        plantName: plantNameToSearch),
                                  ),
                                );

                                if (mounted) {
                                  _showResultsDialog(identification);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.grey[100],
                                      ),
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Container(
                                                  width: 80,
                                                  height: 80,
                                                  child: const Center(
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  ),
                                                ),
                                                errorWidget: (context, url, error) => 
                                                  const Icon(Icons.local_florist, 
                                                    size: 40, 
                                                    color: Colors.grey),
                                              ),
                                            )
                                          : const Center(
                                              child: Icon(Icons.local_florist, 
                                                size: 40, 
                                                color: Colors.grey),
                                          ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            result.species.displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          if (result.species.commonNames.isNotEmpty)
                                            Text(
                                              result.species.commonNames.join(', '),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black54,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getConfidenceColor(result.score),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${(result.score * 100).toStringAsFixed(1)}% match',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const Spacer(),
                                              const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getConfidenceColor(double score) {
    if (score > 0.7) return Colors.green;
    if (score > 0.4) return Colors.orange;
    return Colors.red;
  }
}