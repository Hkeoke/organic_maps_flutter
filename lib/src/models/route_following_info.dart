/// Información de seguimiento de ruta en tiempo real
class RouteFollowingInfo {
  final double distanceToTarget;
  final double distanceToTurn;
  final int timeToTarget;
  final String turnSuffix;

  RouteFollowingInfo({
    required this.distanceToTarget,
    required this.distanceToTurn,
    required this.timeToTarget,
    required this.turnSuffix,
  });

  factory RouteFollowingInfo.fromMap(Map<String, dynamic> map) {
    return RouteFollowingInfo(
      distanceToTarget: (map['distanceToTarget'] as num?)?.toDouble() ?? 0.0,
      distanceToTurn: (map['distanceToTurn'] as num?)?.toDouble() ?? 0.0,
      timeToTarget: map['timeToTarget'] as int? ?? 0,
      turnSuffix: map['turnSuffix'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'distanceToTarget': distanceToTarget,
      'distanceToTurn': distanceToTurn,
      'timeToTarget': timeToTarget,
      'turnSuffix': turnSuffix,
    };
  }

  @override
  String toString() => 'RouteFollowingInfo(distToTarget: $distanceToTarget, distToTurn: $distanceToTurn, time: $timeToTarget)';
}
