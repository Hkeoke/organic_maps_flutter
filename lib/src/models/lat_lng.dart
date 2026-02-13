import 'dart:math' as math;

/// Representa una coordenada geográfica (latitud/longitud).
///
/// Valores válidos:
/// - latitude: -90.0 a 90.0
/// - longitude: -180.0 a 180.0
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude)
      : assert(latitude >= -90.0 && latitude <= 90.0,
            'Latitude must be between -90 and 90'),
        assert(longitude >= -180.0 && longitude <= 180.0,
            'Longitude must be between -180 and 180');

  /// Crea una instancia desde un mapa de datos nativos.
  factory LatLng.fromMap(Map<String, dynamic> map) {
    return LatLng(
      (map['latitude'] as num).toDouble(),
      (map['longitude'] as num).toDouble(),
    );
  }

  /// Convierte a mapa para enviar al lado nativo.
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Calcula la distancia en metros a otro punto usando la fórmula de Haversine.
  double distanceTo(LatLng other) {
    const double earthRadius = 6371000; // metros
    final dLat = _toRad(other.latitude - latitude);
    final dLon = _toRad(other.longitude - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(latitude)) *
            math.cos(_toRad(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRad(double deg) => deg * (math.pi / 180);

  /// Crea una copia con valores modificados.
  LatLng copyWith({double? latitude, double? longitude}) {
    return LatLng(
      latitude ?? this.latitude,
      longitude ?? this.longitude,
    );
  }

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
