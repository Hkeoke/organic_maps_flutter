import 'lat_lng.dart';

/// Resultado de búsqueda
class SearchResult {
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String type;

  SearchResult({
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.type,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      type: map['type'] as String? ?? '',
    );
  }

  LatLng get position => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'type': type,
    };
  }

  @override
  String toString() => 'SearchResult(name: $name, lat: $latitude, lon: $longitude)';
}
