import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart'; // Ensure this path matches your project structure

// --- DATA MODELS ---

class PlantIdentification {
  final List<PlantResult> results;

  PlantIdentification({required this.results});

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

  PlantResult({required this.score, required this.species, required this.images});

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

  PlantTaxonomy({this.genus, this.family});

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

  PlantImage({required this.url, required this.organ});

  factory PlantImage.fromJson(Map<String, dynamic> json) {
    return PlantImage(
      url: (json['url'] as Map<String, dynamic>?)?['m'] as String? ?? '',
      organ: json['organ'] as String? ?? '',
    );
  }
}

// --- SERVICE IMPLEMENTATION ---

class PlantScannerService {
  static const String baseUrl = 'https://my-api.plantnet.org';
  
  // Now pulling from our secure EnvConfig
  static String get project => EnvConfig.plantNetProject;
  static String get apiKey => EnvConfig.plantNetApiKey;

  /// Main entry point for identifying a plant from a file
  static Future<PlantIdentification> identifyPlantEnhanced(File imageFile) async {
    try {
      if (apiKey.isEmpty) {
        throw Exception('PlantNet API key is not configured in .env');
      }
      
      await _validateImageFile(imageFile);
      return await _callPlantNetAPI(imageFile, includeRelatedImages: true);
    } catch (e) {
      debugPrint('PlantScannerService Error: $e');
      rethrow;
    }
  }

  static Future<PlantIdentification> _callPlantNetAPI(File imageFile, {bool includeRelatedImages = false}) async {
    try {
      final uri = Uri.parse('$baseUrl/v2/identify/$project').replace(
        queryParameters: {
          'api-key': apiKey,
          'include-related-images': includeRelatedImages.toString(),
          'no-reject': 'false',
          'lang': 'en',
        },
      );

      var request = http.MultipartRequest('POST', uri);
      
      // Read file and attach to request
      final fileBytes = await imageFile.readAsBytes();
      final contentType = _getContentType(imageFile.path);
      
      request.files.add(http.MultipartFile.fromBytes(
        'images',
        fileBytes,
        filename: imageFile.path.split('/').last,
        contentType: contentType,
      ));

      request.fields['organs'] = 'auto';
      request.headers['Accept'] = 'application/json';
      request.headers['User-Agent'] = 'Plantitao Flutter App';

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final jsonResponse = json.decode(responseBody) as Map<String, dynamic>;
        return _parseResponse(jsonResponse);
      } else {
        _handleApiError(streamedResponse.statusCode, responseBody);
        throw Exception('Failed to identify plant');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('No internet connection. Please try again.');
      }
      rethrow;
    }
  }

  static PlantIdentification _parseResponse(Map<String, dynamic> json) {
    if (json['results'] == null || (json['results'] as List).isEmpty) {
      throw Exception('No plant species found. Please try a clearer photo.');
    }
    return PlantIdentification.fromJson(json);
  }

  static MediaType _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    if (extension == 'png') return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  static Future<void> _validateImageFile(File imageFile) async {
    if (!await imageFile.exists()) throw Exception('Image file not found.');
    
    final fileSize = await imageFile.length();
    if (fileSize == 0) throw Exception('Image file is empty.');
    
    // 5MB Limit
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('Image is too large. Max size is 5MB.');
    }
  }

  static void _handleApiError(int statusCode, String body) {
    debugPrint('PlantNet API Error ($statusCode): $body');
    if (statusCode == 401) throw Exception('Invalid API Key.');
    if (statusCode == 404) throw Exception('Botanical project "$project" not found.');
    if (statusCode == 400) throw Exception('The image was not recognized as a plant.');
  }
}