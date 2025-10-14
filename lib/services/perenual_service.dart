// lib/services/perenual_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../utils/api_cache.dart';

class PerenualService {
  static const String _baseUrl = 'https://perenual.com/api';
  static String get _apiKey => EnvConfig.perenualApiKey;

  static int? _safeParsePlantId(dynamic id) {
    if (id == null) return null;
    if (id is int) return id;
    if (id is String) {
      return int.tryParse(id);
    }
    try {
      return int.tryParse(id.toString());
    } catch (e) {
      debugPrint('Failed to parse plant ID: $id, error: $e');
      return null;
    }
  }

  // --- AI-POWERED DAILY GUIDE ---
  static Future<Map<String, dynamic>?> getDailyPlantGuide() async {
    if (_apiKey.isEmpty) {
      throw Exception('Perenual API key not configured.');
    }

    final now = DateTime.now();
    final dateKey = '${now.year}-${now.month}-${now.day}';
    // UPDATED: New cache key for the dedicated API version
    final cacheKey = 'daily_plant_guide_api_$dateKey'; 

    final cachedGuide = ApiCache().get(cacheKey);
    if (cachedGuide != null) {
      debugPrint('Cache Hit: Returning API-powered daily plant guide for $dateKey.');
      return Map<String, dynamic>.from(cachedGuide);
    }

    try {
      // Step 1: Get a stable list of plants from Perenual to get a name and image.
      final listUrl =
          Uri.parse('$_baseUrl/species-list?key=$_apiKey&watering=average');
      final listResponse =
          await http.get(listUrl).timeout(const Duration(seconds: 15));

      if (listResponse.statusCode != 200) {
        throw Exception(
            'Failed to load plant list for daily guide (Status: ${listResponse.statusCode}).');
      }
      
      final Map<String, dynamic> decodedBody = json.decode(listResponse.body);
      final listData = decodedBody['data'] as List;
      if (listData.isEmpty) return null;

      final plantsWithImages =
          listData.where((p) => p['default_image'] != null).toList();
      if (plantsWithImages.isEmpty) return null;
      
      final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
      final plantOfTheDaySummary = plantsWithImages[dayOfYear % plantsWithImages.length];
      
      final commonName = plantOfTheDaySummary['common_name'] as String? ?? 'this beautiful plant';
      final scientificName = (plantOfTheDaySummary['scientific_name'] as List<dynamic>?)?.first ?? '';
      final imageUrl = plantOfTheDaySummary['default_image']?['regular_url'];
      final plantId = _safeParsePlantId(plantOfTheDaySummary['id']);

      // Step 2: Call the dedicated Perenual Care Guide API
      String summary = 'A daily care guide for $commonName. Tap to read more.';
      String fullGuide = '';

      if (plantId != null) {
        try {
          final careUrl = Uri.parse('$_baseUrl/species-care-guide-list?key=$_apiKey&species_id=$plantId');
          final careResponse = await http.get(careUrl).timeout(const Duration(seconds: 15));

          if (careResponse.statusCode == 200) {
            final decodedCareBody = json.decode(careResponse.body);
            final careData = decodedCareBody['data'] as List?;
            
            if (careData != null && careData.isNotEmpty) {
              final sections = careData.first['section'] as List?;
              if (sections != null) {
                final summarySections = <String>[];
                final fullGuideSections = <String>[];

                for (var section in sections) {
                  final type = section['type'] as String?;
                  final description = section['description'] as String?;
                  if (type != null && description != null) {
                    // Create a summary from key sections
                    if (type == 'watering' || type == 'sunlight') {
                      summarySections.add(description);
                    }
                    // Build the full guide with titles
                    fullGuideSections.add('${type[0].toUpperCase()}${type.substring(1)}:\n$description\n');
                  }
                }
                
                if (summarySections.isNotEmpty) {
                  summary = summarySections.join(' ');
                }
                if (fullGuideSections.isNotEmpty) {
                  fullGuide = fullGuideSections.join('\n');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Could not fetch specific care guide, providing fallback. Error: $e');
        }
      }

      // If the full guide is still empty after the API call, use a fallback.
      if (fullGuide.isEmpty) {
        fullGuide = 'General care advice: Provide this plant with moderate water and bright, indirect light. Check its specific needs for best results.';
      }

      // Step 3: Combine the Perenual data (image) with the API content.
      final guide = {
        'common_name': commonName,
        'scientific_name': scientificName,
        'primary_image': imageUrl,
        'summary': summary,
        'full_guide': fullGuide,
      };
      
      ApiCache().set(cacheKey, guide);
      return guide;

    } catch (e) {
      debugPrint('Error fetching API-powered daily plant guide: $e');
      return null; // Return null on failure
    }
  }

  static Future<List<Map<String, dynamic>>> searchPlants(String query) async {
    // ... existing searchPlants code remains the same ...
    if (_apiKey.isEmpty) {
      throw Exception('Perenual API key not configured. Check PERENUAL_API_KEY in my.env.');
    }
    
    await ApiCache().waitForRateLimit(); 
    final cachedResults = ApiCache().getPlantSearch(query);
    if (cachedResults != null) {
      debugPrint('Cache Hit: Returning ${cachedResults.length} plants for query "$query"');
      return List<Map<String, dynamic>>.from(cachedResults);
    }
    
    final url = Uri.parse('$_baseUrl/species-list?key=$_apiKey&q=${Uri.encodeComponent(query)}');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final plantData = data['data'];

        if (plantData is List) {
          final mappedResults = plantData.map((item) => _mapPerenualSearchItem(item)).toList();
          ApiCache().setPlantSearch(query, mappedResults);
          return mappedResults;
        }
        return [];
      } else if (response.statusCode == 429) {
        throw Exception("You've made too many requests. Please wait a moment and try again.");
      } else if (response.statusCode == 401) {
        throw Exception("Invalid Perenual API Key. Please check your key in my.env.");
      } else {
        throw Exception("We couldn't load the search results (Status: ${response.statusCode}). Please try again.");
      }
    } on TimeoutException {
        debugPrint('Perenual search error: Timeout');
        throw Exception('The request to the plant database timed out. Please try again.');
    } on SocketException {
        debugPrint('Perenual search error: SocketException');
        throw Exception('Network request failed. Ensure internet connection is stable.');
    } catch (e) {
      debugPrint('Perenual search error: $e');
      throw Exception('An unknown error occurred while searching for plants.');
    }
  }

  static Future<Map<String, dynamic>> getPlantDetails(int plantId) async {
    // ... existing getPlantDetails code remains the same ...
    if (_apiKey.isEmpty) {
      throw Exception('Perenual API key not configured. Check PERENUAL_API_KEY in my.env.');
    }

    await ApiCache().waitForRateLimit();
    final cacheKey = 'details_v12_final_$plantId'; // Incremented cache key version
    final cachedDetails = ApiCache().getPlantDetails(cacheKey);
    if (cachedDetails != null) {
      try {
        debugPrint('Cache Hit: Returning details for plant ID "$plantId"');
        return Map<String, dynamic>.from(cachedDetails);
      } catch (e) {
        debugPrint('Failed to cast cached details, fetching from network instead. Error: $e');
      }
    }
    
    final detailsUrl = Uri.parse('$_baseUrl/species/details/$plantId?key=$_apiKey');
    final careGuideUrl = Uri.parse('$_baseUrl/species-care-guide-list?key=$_apiKey&species_id=$plantId');

    try {
      final responses = await Future.wait([
        http.get(detailsUrl).timeout(const Duration(seconds: 15)),
        http.get(careGuideUrl).timeout(const Duration(seconds: 15)),
      ]);

      final detailsResponse = responses[0];
      final careGuideResponse = responses[1];
      
      if (detailsResponse.statusCode != 200) {
        throw Exception("Could not load plant details (Status: ${detailsResponse.statusCode})");
      }
      
      final Map<String, dynamic> decodedDetails;
      try {
        final dynamic rawDecode = json.decode(detailsResponse.body);
        if (rawDecode is! Map<String, dynamic>) {
            throw FormatException('Expected a JSON object for details, but got ${rawDecode.runtimeType}');
        }
        decodedDetails = rawDecode;
      } catch (e) {
          debugPrint('Error decoding plant details JSON: ${detailsResponse.body}');
          throw Exception('Failed to parse plant details from the server.');
      }
      
      final mappedDetails = _mapPerenualDetail(decodedDetails);

      if (careGuideResponse.statusCode == 200) {
        try {
          final dynamic rawCareDecode = json.decode(careGuideResponse.body);
          if (rawCareDecode is Map<String, dynamic> && rawCareDecode['data'] is List) {
            final careDataList = rawCareDecode['data'] as List;
            for (var careItem in careDataList) {
              if (careItem is Map && careItem['section'] is List) {
                final sections = careItem['section'] as List;
                for (var section in sections) {
                  if (section is Map) {
                    final type = section['type'];
                    final description = section['description'];
                    if (type is String && description is String && type.isNotEmpty && description.isNotEmpty) {
                      final key = '${type.toLowerCase().trim()}_guide';
                      mappedDetails[key] = description;
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint("Could not parse care guide data: $e");
        }
      }

      ApiCache().setPlantDetails(cacheKey, mappedDetails);
      return mappedDetails;

    } on TimeoutException {
        throw Exception('The request to the plant database timed out. Please try again.');
    } on SocketException {
        throw Exception('Network request failed. Ensure internet connection is stable.');
    } catch (e) {
      debugPrint('Perenual detail error: $e');
      throw Exception('An unknown error occurred while fetching plant details.');
    }
  }
  
  // All other methods (_mapPerenualSearchItem, _mapPerenualDetail, etc.) remain unchanged.
  // ...
  static Map<String, dynamic> _mapPerenualSearchItem(Map<String, dynamic> item) {
    final imageMap = item['default_image'];
    final imageUrl = imageMap != null && imageMap.containsKey('small_url') 
        ? imageMap['small_url'] 
        : null;

    final plantId = _safeParsePlantId(item['id']) ?? 0;

    return {
      'id': plantId,
      'common_name': item['common_name'] as String?,
      'scientific_name': item['scientific_name'] as List<dynamic>?,
      'family': item['family'] as String?,
      'care_level': item['maintenance'] as String? ?? 'Moderate', 
      'primary_image': imageUrl,
      'data_source': 'perenual',
    };
  }
  
  static Map<String, dynamic> _mapPerenualDetail(Map<String, dynamic> detail) {
    final imageMap = detail['default_image'];
    final imageUrl = imageMap is Map && imageMap.containsKey('regular_url')
        ? imageMap['regular_url']
        : null;

    String? extractString(String key) {
      final value = detail[key];
      if (value == null || value.toString().trim().isEmpty) return null;
      return value.toString();
    }

    List<String> extractList(String key) {
      final value = detail[key];
      if (value is List) {
        return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      }
      return [];
    }
    
    bool? extractBool(String key) {
        final value = detail[key];
        if (value == null) return null;
        if (value is bool) return value;
        if (value is int) return value == 1;
        if (value is String) {
          if (value.toLowerCase() == 'true' || value == '1') return true;
          if (value.toLowerCase() == 'false' || value == '0') return false;
        }
        return null;
    }
    
    String? getDisplayValue(dynamic data) {
      if (data == null) return null;
      if (data is List) return data.join(', ');
      return data.toString();
    }

    String? formatPruningCount(dynamic countData) {
      if (countData is! Map) return null;
      final amount = countData['amount']?.toString();
      final interval = countData['interval']?.toString();
      if (amount != null && interval != null) {
        return '$amount time(s) per $interval';
      }
      return null;
    }

    final plantId = _safeParsePlantId(detail['id']) ?? 0;

    return {
      'id': plantId,
      'common_name': extractString('common_name'),
      'scientific_name': extractList('scientific_name'),
      'other_name': extractList('other_name'),
      'family': extractString('family'),
      'origin': extractList('origin'),
      'type': extractString('type'),
      'dimension': extractString('dimension'),
      'cycle': extractString('cycle'),
      'attracts': extractList('attracts'),
      'watering': extractString('watering'),
      'watering_general_benchmark': (detail['watering_general_benchmark'] is Map)
        ? '${detail['watering_general_benchmark']['value']} ${detail['watering_general_benchmark']['unit']}'
        : null,
      'sunlight': extractList('sunlight'),
      'soil': extractList('soil'),
      'growth_rate': extractString('growth_rate'),
      'maintenance': extractString('maintenance'),
      'hardiness': (detail['hardiness'] is Map) 
        ? 'Zones ${detail['hardiness']['min']} - ${detail['hardiness']['max']}'
        : null,
      'hardiness_location': detail['hardiness_location'],
      'care_level': extractString('care_level'),
      'pruning_month': getDisplayValue(detail['pruning_month']),
      'pruning_count': formatPruningCount(detail['pruning_count']),
      'propagation': extractList('propagation'),
      'pest_susceptibility': extractList('pest_susceptibility'),
      'description': extractString('description'),
      'primary_image': imageUrl,
      'other_images': (detail['other_images']?['data'] as List?)
        ?.map((img) => {
          'thumbnail': img['thumbnail'] as String,
          'original_url': img['original_url'] as String,
        }).toList() ?? [],
      'data_source': 'perenual',
      
      'leaf': extractBool('leaf'),
      'leaf_color': extractList('leaf_color'),
      'flowers': extractBool('flowers'),
      'flower_color': extractString('flower_color'),
      'flowering_season': extractString('flowering_season'),
      'cones': extractBool('cones'),
      'fruits': extractBool('fruits'),
      'fruit_color': extractList('fruit_color'),
      'fruiting_season': extractString('fruiting_season'),
      'harvest_season': extractString('harvest_season'),
      'edible_fruit': extractBool('edible_fruit'),
      'edible_leaf': extractBool('edible_leaf'),
      'medicinal': extractBool('medicinal'),
      'poisonous_to_humans': extractBool('poisonous_to_humans'),
      'poisonous_to_pets': extractBool('poisonous_to_pets'),
      'drought_tolerant': extractBool('drought_tolerant'),
      'salt_tolerant': extractBool('salt_tolerant'),
      'thorny': extractBool('thorny'),
      'indoor': extractBool('indoor'),
      'tropical': extractBool('tropical'),
      'invasive': extractBool('invasive'),

      // Care Guide Details
      'watering_guide': extractString('watering_guide'),
      'sunlight_guide': extractString('sunlight_guide'),
      'pruning_guide': extractString('pruning_guide'),
      'soil_guide': extractString('soil_guide'),
    };
  }
}

