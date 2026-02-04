/// Información de una ruta calculada
class RouteInfo {
  final bool success;
  final double? distanceMeters;
  final int? durationSeconds;

  RouteInfo({
    required this.success,
    this.distanceMeters,
    this.durationSeconds,
  });

  /// Distancia formateada (ej: "5.2 km")
  String get distanceFormatted {
    if (distanceMeters == null) return 'N/A';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  /// Duración formateada (ej: "1h 23min")
  String get durationFormatted {
    if (durationSeconds == null) return 'N/A';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  factory RouteInfo.fromMap(Map<String, dynamic> map) {
    return RouteInfo(
      success: map['success'] as bool? ?? false,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: map['durationSeconds'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
    };
  }

  @override
  String toString() => 'RouteInfo(success: $success, distance: $distanceMeters, duration: $durationSeconds)';
}
