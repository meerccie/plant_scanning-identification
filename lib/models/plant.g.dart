// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Plant _$PlantFromJson(Map<String, dynamic> json) => Plant(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  species: json['species'] as String,
  userId: json['user_id'] as String,
  imageUrl: json['image_url'] as String?,
  notes: json['notes'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$PlantToJson(Plant instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'species': instance.species,
  'user_id': instance.userId,
  'image_url': instance.imageUrl,
  'notes': instance.notes,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
