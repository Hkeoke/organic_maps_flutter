import 'lat_lng.dart';

/// Tipo de resultado de búsqueda.
enum SearchResultType {
  /// Resultado concreto (lugar, dirección, etc.)
  result,

  /// Sugerencia de búsqueda para refinar la query.
  suggest,

  /// Sugerencia pura (sin coordenadas válidas).
  pureSuggest,

  /// Tipo desconocido.
  unknown;

  static SearchResultType fromString(String value) {
    switch (value) {
      case 'result':
        return SearchResultType.result;
      case 'suggest':
        return SearchResultType.suggest;
      case 'pure_suggest':
        return SearchResultType.pureSuggest;
      default:
        return SearchResultType.unknown;
    }
  }
}

/// Resultado de búsqueda en el mapa.
class SearchResult {
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final SearchResultType type;

  const SearchResult({
    required this.name,
    this.description = '',
    required this.latitude,
    required this.longitude,
    this.type = SearchResultType.result,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      type: SearchResultType.fromString(map['type'] as String? ?? ''),
    );
  }

  /// Posición como [LatLng].
  LatLng get position => LatLng(latitude, longitude);

  /// Indica si el resultado tiene coordenadas válidas.
  bool get hasValidPosition =>
      latitude != 0.0 || longitude != 0.0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'type': type.name,
    };
  }

  SearchResult copyWith({
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    SearchResultType? type,
  }) {
    return SearchResult(
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
    );
  }

  @override
  String toString() =>
      'SearchResult(name: $name, position: ($latitude, $longitude), type: ${type.name})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResult &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(name, latitude, longitude);
}
