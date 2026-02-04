import 'lat_lng.dart';

/// Representa un marcador o bookmark
class Bookmark {
  final String id;
  final String name;
  final String? description;
  final LatLng position;
  final String? categoryId;
  final DateTime? createdAt;

  Bookmark({
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
      'position': position.toMap(),
      'categoryId': categoryId,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }
}
