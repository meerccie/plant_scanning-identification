// lib/services/plant_scanner_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';

// --- DATA MODELS UPDATED TO INCLUDE IMAGES ---
class PlantIdentification {
  final List<PlantResult> results;

  PlantIdentification({ required this.results });

  factory PlantIdentification.fromJson(Map<String, dynamic> json) {
    return PlantIdentification(
      results: (json['results'] as List<dynamic>?)
              ?.map((result) => PlantResult.fromJson(result as Map<String, dynamic>))
              .toList() ?? [],
    );
  }
}

class PlantResult {
  final double score;
  final PlantSpecies species;
  final List<PlantImage> images;

  PlantResult({ required this.score, required this.species, required this.images });

  factory PlantResult.fromJson(Map<String, dynamic> json) {
    return PlantResult(
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      species: PlantSpecies.fromJson(json['species'] as Map<String, dynamic>? ?? {}),
      images: (json['images'] as List<dynamic>?)
              ?.map((img) => PlantImage.fromJson(img as Map<String, dynamic>))
              .toList() ?? [],
    );
  }
}

class PlantSpecies {
  final String scientificNameWithoutAuthor;
  final String scientificNameAuthorship;
  final String displayName;
  final List<String> commonNames;
  final PlantTaxonomy taxonomy;

  PlantSpecies({
    required this.scientificNameWithoutAuthor,
    required this.scientificNameAuthorship,
    required this.displayName,
    required this.commonNames,
    required this.taxonomy,
  });

  factory PlantSpecies.fromJson(Map<String, dynamic> json) {
    return PlantSpecies(
      scientificNameWithoutAuthor: json['scientificNameWithoutAuthor'] as String? ?? '',
      scientificNameAuthorship: json['scientificNameAuthorship'] as String? ?? '',
      displayName: json['scientificName'] as String? ?? 'Unknown Plant',
      commonNames: (json['commonNames'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      taxonomy: PlantTaxonomy.fromJson(json),
    );
  }
}

class PlantTaxonomy {
  final String? genus;
  final String? family;

  PlantTaxonomy({ this.genus, this.family });

  factory PlantTaxonomy.fromJson(Map<String, dynamic> json) {
    return PlantTaxonomy(
      genus: (json['genus'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor'] as String?,
      family: (json['family'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor'] as String?,
    );
  }
}

class PlantImage {
  final String url;
  final String organ;

  PlantImage({ required this.url, required this.organ });

  factory PlantImage.fromJson(Map<String, dynamic> json) {
    return PlantImage(
      url: (json['url'] as Map<String, dynamic>?)?['m'] as String? ?? '',
      organ: json['organ'] as String? ?? '',
    );
  }
}

class PlantScannerService {
  static const String baseUrl = 'https://my-api.plantnet.org';
  static String get project => dotenv.env['PLANTNET_PROJECT'] ?? 'k-world-flora';
  static String get apiKey => dotenv.env['PLANTNET_API_KEY'] ?? '';

  static Future<PlantIdentification> identifyPlantEnhanced(File imageFile) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('PlantNet API key is not configured.');
      }
      await validateEnhancedImageFile(imageFile);
      return await callEnhancedPlantNetAPI(imageFile, includeRelatedImages: true);
    } catch (e) {
      debugPrint('Error during plant identification flow: $e');
      rethrow;
    }
  }

  static MediaType getEnhancedContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('image', 'jpeg');
    }
  }

  static void handleEnhancedApiError(int statusCode, String responseBody) {
    if (kDebugMode) {
      print('Handling API Error: $statusCode, Body: $responseBody');
    }
    switch (statusCode) {
      case 400:
        throw Exception('No recognizable plant parts detected. Please try a different photo.');
      case 401:
        throw Exception('Authentication failed. Check your API key.');
      default:
        throw Exception('Plant identification service failed, HTTP $statusCode');
    }
  }

  static Future<void> validateEnhancedImageFile(File imageFile) async {
    if (!await imageFile.exists()) {
      throw Exception('Image file does not exist.');
    }
    final fileSize = await imageFile.length();
    if (fileSize == 0) {
      throw Exception('Image file is empty.');
    }
    const maxSize = 5 * 1024 * 1024;
    if (fileSize > maxSize) {
      throw Exception('Image is too large (${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB). Max size is 5MB.');
    }
  }

  static Future<PlantIdentification> callEnhancedPlantNetAPI(File imageFile, {bool includeRelatedImages = false}) async {
    try {
      // *** FIX: This now uses the correct general identification endpoint for both pages ***
      final uri = Uri.parse('$baseUrl/v2/identify/all').replace(
        queryParameters: {
          'api-key': apiKey,
          'include-related-images': includeRelatedImages.toString(),
          'no-reject': 'false',
          'lang': 'en',
        },
      );
      var request = http.MultipartRequest('POST', uri);
      final fileBytes = await imageFile.readAsBytes();
      final contentType = getEnhancedContentType(imageFile.path);
      final multipartFile = http.MultipartFile.fromBytes(
        'images',
        fileBytes,
        filename: imageFile.path.split('/').last,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      request.fields['organs'] = 'auto';
      request.headers['Accept'] = 'application/json';
      request.headers['User-Agent'] = 'Plantitao Flutter App';

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = json.decode(responseBody) as Map<String, dynamic>;
        if (jsonResponse['results'] == null || (jsonResponse['results'] as List).isEmpty) {
          throw Exception('No plant species found. Please try a clearer photo.');
        }
        return _parsePlantNetResponse(jsonResponse);
      } else {
        handleEnhancedApiError(streamedResponse.statusCode, responseBody);
        throw Exception('An unknown API error occurred.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Network/Request error: $e');
      }
      if (e.toString().contains('SocketException')) {
        throw Exception('Network connection failed. Please check your internet connection.');
      }
      rethrow;
    }
  }

  static PlantIdentification _parsePlantNetResponse(Map<String, dynamic> json) {
    try {
      return PlantIdentification.fromJson(json);
    } catch (e) {
      if (kDebugMode) {
        print('JSON parse error: $e');
      }
      throw Exception('Failed to parse results from the identification service.');
    }
  }
}