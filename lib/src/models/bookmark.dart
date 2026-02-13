import 'lat_lng.dart';

/// Representa un marcador o bookmark en el mapa.
class Bookmark {
  final String id;
  final String name;
  final String? description;
  final LatLng position;
  final String? categoryId;
  final DateTime? createdAt;

  const Bookmark({
    required this.id,
    required this.name,
    this.description,
    required this.position,
    this.categoryId,
    this.createdAt,
  });

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      position: LatLng(
        (map['latitude'] as num).toDouble(),
        (map['longitude'] as num).toDouble(),
      ),
      categoryId: map['categoryId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'categoryId': categoryId,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  Bookmark copyWith({
    String? id,
    String? name,
    String? description,
    LatLng? position,
    String? categoryId,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      position: position ?? this.position,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Bookmark(id: $id, name: $name, position: $position)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
