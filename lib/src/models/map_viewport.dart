import 'lat_lng.dart';

/// Representa el viewport actual del mapa.
class MapViewport {
  /// Centro del viewport.
  final LatLng center;

  /// Nivel de zoom actual.
  final double zoom;

  /// Azimut de rotación en grados.
  final double azimuth;

  /// Esquina superior izquierda del viewport.
  final LatLng topLeft;

  /// Esquina inferior derecha del viewport.
  final LatLng bottomRight;

  const MapViewport({
    required this.center,
    required this.zoom,
    this.azimuth = 0.0,
    required this.topLeft,
    required this.bottomRight,
  });

  factory MapViewport.fromMap(Map<String, dynamic> map) {
    return MapViewport(
      center: LatLng(
        (map['centerLat'] as num).toDouble(),
        (map['centerLon'] as num).toDouble(),
      ),
      zoom: (map['zoom'] as num?)?.toDouble() ?? 12.0,
      azimuth: (map['azimuth'] as num?)?.toDouble() ?? 0.0,
      topLeft: LatLng(
        (map['topLeftLat'] as num?)?.toDouble() ?? 0.0,
        (map['topLeftLon'] as num?)?.toDouble() ?? 0.0,
      ),
      bottomRight: LatLng(
        (map['bottomRightLat'] as num?)?.toDouble() ?? 0.0,
        (map['bottomRightLon'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  /// Verifica si un punto está dentro del viewport.
  bool contains(LatLng point) {
    return point.latitude >= bottomRight.latitude &&
        point.latitude <= topLeft.latitude &&
        point.longitude >= topLeft.longitude &&
        point.longitude <= bottomRight.longitude;
  }

  Map<String, dynamic> toMap() {
    return {
      'center': center.toMap(),
      'zoom': zoom,
      'azimuth': azimuth,
      'topLeft': topLeft.toMap(),
      'bottomRight': bottomRight.toMap(),
    };
  }

  MapViewport copyWith({
    LatLng? center,
    double? zoom,
    double? azimuth,
    LatLng? topLeft,
    LatLng? bottomRight,
  }) {
    return MapViewport(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      azimuth: azimuth ?? this.azimuth,
      topLeft: topLeft ?? this.topLeft,
      bottomRight: bottomRight ?? this.bottomRight,
    );
  }

  @override
  String toString() =>
      'MapViewport(center: $center, zoom: $zoom, azimuth: $azimuth)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapViewport &&
          runtimeType == other.runtimeType &&
          center == other.center &&
          zoom == other.zoom &&
          azimuth == other.azimuth;

  @override
  int get hashCode => Object.hash(center, zoom, azimuth);
}
