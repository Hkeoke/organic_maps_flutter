/// Información de seguimiento de ruta en tiempo real.
///
/// Contiene datos que se actualizan constantemente durante la navegación
/// como distancia restante, próximo giro, etc.
class RouteFollowingInfo {
  /// Distancia restante hasta el destino (texto formateado, ej: "5.2 km").
  final String distanceToTarget;

  /// Distancia al próximo giro (texto formateado, ej: "200 m").
  final String distanceToTurn;

  /// Tiempo estimado restante en segundos.
  final int timeToTarget;

  /// Nombre de la próxima calle o instrucción de giro.
  final String nextStreet;

  /// Unidades de la distancia al destino (ej: "km", "m").
  final String distanceToTargetUnits;

  /// Unidades de la distancia al giro (ej: "m").
  final String distanceToTurnUnits;

  const RouteFollowingInfo({
    required this.distanceToTarget,
    required this.distanceToTurn,
    required this.timeToTarget,
    this.nextStreet = '',
    this.distanceToTargetUnits = '',
    this.distanceToTurnUnits = '',
  });

  factory RouteFollowingInfo.fromMap(Map<String, dynamic> map) {
    return RouteFollowingInfo(
      distanceToTarget: map['distanceToTarget']?.toString() ?? '0',
      distanceToTurn: map['distanceToTurn']?.toString() ?? '0',
      timeToTarget: (map['timeToTarget'] as num?)?.toInt() ?? 0,
      nextStreet: map['turnSuffix'] as String? ??
          map['nextStreet'] as String? ??
          '',
      distanceToTargetUnits:
          map['distanceToTargetUnits'] as String? ?? '',
      distanceToTurnUnits: map['distanceToTurnUnits'] as String? ?? '',
    );
  }

  /// Tiempo restante formateado (ej: "1h 23min").
  String get timeFormatted {
    if (timeToTarget <= 0) return '--';
    final hours = timeToTarget ~/ 3600;
    final minutes = (timeToTarget % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    if (minutes > 0) {
      return '${minutes}min';
    }
    return '${timeToTarget}s';
  }

  /// Indica si hay información válida de navegación.
  bool get isValid => timeToTarget > 0;

  Map<String, dynamic> toMap() {
    return {
      'distanceToTarget': distanceToTarget,
      'distanceToTurn': distanceToTurn,
      'timeToTarget': timeToTarget,
      'nextStreet': nextStreet,
      'distanceToTargetUnits': distanceToTargetUnits,
      'distanceToTurnUnits': distanceToTurnUnits,
    };
  }

  RouteFollowingInfo copyWith({
    String? distanceToTarget,
    String? distanceToTurn,
    int? timeToTarget,
    String? nextStreet,
    String? distanceToTargetUnits,
    String? distanceToTurnUnits,
  }) {
    return RouteFollowingInfo(
      distanceToTarget: distanceToTarget ?? this.distanceToTarget,
      distanceToTurn: distanceToTurn ?? this.distanceToTurn,
      timeToTarget: timeToTarget ?? this.timeToTarget,
      nextStreet: nextStreet ?? this.nextStreet,
      distanceToTargetUnits:
          distanceToTargetUnits ?? this.distanceToTargetUnits,
      distanceToTurnUnits:
          distanceToTurnUnits ?? this.distanceToTurnUnits,
    );
  }

  @override
  String toString() =>
      'RouteFollowingInfo(distTarget: $distanceToTarget, distTurn: $distanceToTurn, time: $timeFormatted, next: $nextStreet)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteFollowingInfo &&
          runtimeType == other.runtimeType &&
          distanceToTarget == other.distanceToTarget &&
          distanceToTurn == other.distanceToTurn &&
          timeToTarget == other.timeToTarget;

  @override
  int get hashCode =>
      Object.hash(distanceToTarget, distanceToTurn, timeToTarget);
}
