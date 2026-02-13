/// Información de una ruta calculada.
class RouteInfo {
  /// Indica si la ruta se calculó exitosamente.
  final bool success;

  /// Distancia total en metros.
  final double? distanceMeters;

  /// Duración estimada en segundos.
  final int? durationSeconds;

  /// Distancia formateada desde el motor nativo (ej: "5.2 km").
  final String? distanceFormatted;

  /// Tiempo formateado desde el motor nativo (ej: "1h 23min").
  final String? durationFormatted;

  const RouteInfo({
    required this.success,
    this.distanceMeters,
    this.durationSeconds,
    this.distanceFormatted,
    this.durationFormatted,
  });

  /// Distancia con formato legible.
  /// Usa el formato nativo si está disponible, sino calcula.
  String get displayDistance {
    if (distanceFormatted != null && distanceFormatted!.isNotEmpty) {
      return distanceFormatted!;
    }
    if (distanceMeters == null) return 'N/A';
    if (distanceMeters! < 1000) {
      return '${distanceMeters!.toStringAsFixed(0)} m';
    }
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  /// Duración con formato legible.
  /// Usa el formato nativo si está disponible, sino calcula.
  String get displayDuration {
    if (durationFormatted != null && durationFormatted!.isNotEmpty) {
      return durationFormatted!;
    }
    if (durationSeconds == null) return 'N/A';
    final hours = durationSeconds! ~/ 3600;
    final minutes = (durationSeconds! % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    if (minutes > 0) {
      return '${minutes}min';
    }
    return '${durationSeconds}s';
  }

  factory RouteInfo.fromMap(Map<String, dynamic> map) {
    return RouteInfo(
      success: map['success'] as bool? ?? false,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
      distanceFormatted: map['totalDistance'] as String?,
      durationFormatted: map['totalTime'] is String
          ? map['totalTime'] as String
          : null,
    );
  }

  /// Crea un RouteInfo indicando fallo.
  factory RouteInfo.failed() => const RouteInfo(success: false);

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'distanceFormatted': distanceFormatted,
      'durationFormatted': durationFormatted,
    };
  }

  RouteInfo copyWith({
    bool? success,
    double? distanceMeters,
    int? durationSeconds,
    String? distanceFormatted,
    String? durationFormatted,
  }) {
    return RouteInfo(
      success: success ?? this.success,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceFormatted: distanceFormatted ?? this.distanceFormatted,
      durationFormatted: durationFormatted ?? this.durationFormatted,
    );
  }

  @override
  String toString() =>
      'RouteInfo(success: $success, distance: $displayDistance, duration: $displayDuration)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteInfo &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          distanceMeters == other.distanceMeters &&
          durationSeconds == other.durationSeconds;

  @override
  int get hashCode => Object.hash(success, distanceMeters, durationSeconds);
}
