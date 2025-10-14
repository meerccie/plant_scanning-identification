import 'package:json_annotation/json_annotation.dart';

part 'plant.g.dart';

@JsonSerializable()
class Plant {
  final int id;
  final String name;
  final String species;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  final String? notes;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime? updatedAt;

  Plant({
    required this.id,
    required this.name,
    required this.species,
    required this.userId,
    this.imageUrl,
    this.notes,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.updatedAt,
  });

  factory Plant.fromJson(Map<String, dynamic> json) => _$PlantFromJson(json);
  Map<String, dynamic> toJson() => _$PlantToJson(this);

  // Helper method to check if plant has location
  bool get hasLocation => latitude != null && longitude != null;

  // Helper method to get a display-friendly created date
  String get formattedCreatedDate {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  // Helper method to get a display-friendly updated date
  String? get formattedUpdatedDate {
    if (updatedAt == null) return null;
    return '${updatedAt!.day}/${updatedAt!.month}/${updatedAt!.year}';
  }

  // Copy with method for updating plant data
  Plant copyWith({
    int? id,
    String? name,
    String? species,
    String? userId,
    String? imageUrl,
    String? notes,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Plant(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Plant(id: $id, name: $name, species: $species, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Plant &&
        other.id == id &&
        other.name == name &&
        other.species == species &&
        other.userId == userId &&
        other.imageUrl == imageUrl &&
        other.notes == notes &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        species.hashCode ^
        userId.hashCode ^
        imageUrl.hashCode ^
        notes.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}