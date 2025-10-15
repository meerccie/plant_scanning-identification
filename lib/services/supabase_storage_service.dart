// lib/services/supabase_storage_service.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'supabase_service.dart';

class SupabaseStorageService {
  static SupabaseClient get _client => SupabaseService.client;
  static User? get _currentUser => SupabaseService.currentUser;

  static String _generateUniqueFileName(String prefix, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '${prefix}_${timestamp}_$random$extension';
  }

  static Future<String?> uploadImage(File imageFile, String bucket, String prefix) async {
    final userId = _currentUser?.id;
    if (userId == null) {
      throw Exception('User must be logged in to upload images.');
    }

    try {
      final extension = path.extension(imageFile.path);
      final fileName = _generateUniqueFileName(prefix, extension);
      final filePath = '$userId/$fileName';

      await _client.storage.from(bucket).upload(filePath, imageFile);
      return _client.storage.from(bucket).getPublicUrl(filePath);
    } on StorageException catch (e) {
      debugPrint('Storage error during upload: ${e.message}');
      rethrow;
    }
  }

  static Future<void> deleteImage(String? imageUrl, String bucket) async {
    if (imageUrl == null || imageUrl.isEmpty) return;

    try {
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(bucket);

      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _client.storage.from(bucket).remove([filePath]);
      }
    } on StorageException catch (e) {
      debugPrint('Storage error deleting image: ${e.message}');
    }
  }

  static Future<String?> replaceImage({
    required File newImageFile,
    String? oldImageUrl,
    required String bucket,
    required String prefix,
  }) async {
    try {
      final newImageUrl = await uploadImage(newImageFile, bucket, prefix);
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        await deleteImage(oldImageUrl, bucket).catchError((e) {
          debugPrint('Failed to delete old image during replacement: $e');
        });
      }
      return newImageUrl;
    } catch (e) {
      debugPrint('Error replacing image: $e');
      rethrow;
    }
  }
}