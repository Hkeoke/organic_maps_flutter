import 'lat_lng.dart';

/// Representa el viewport actual del mapa
class MapViewport {
  final LatLng center;
  final double zoom;
  final double azimuth;
  final LatLng topLeft;
  final LatLng bottomRight;

  MapViewport({
    required this.center,
    required this.zoom,
    required this.azimuth,
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

  Map<String, dynamic> toMap() {
    return {
      'center': center.toMap(),
      'zoom': zoom,
      'azimuth': azimuth,
      'topLeft': topLeft.toMap(),
      'bottomRight': bottomRight.toMap(),
    };
  }
}
