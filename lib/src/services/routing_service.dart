import 'package:flutter/services.dart';
import '../models/models.dart';

/// Servicio para gestionar rutas y navegación
class RoutingService {
  static const MethodChannel _channel =
      MethodChannel('organic_maps_flutter/routing');

  /// Calcula una ruta
  static Future<RouteInfo> calculateRoute({
    required LatLng start,
    required LatLng end,
    String routerType = 'vehicle',
    List<LatLng>? waypoints,
  }) async {
    final result = await _channel.invokeMethod<Map>('calculateRoute', {
      'startLat': start.latitude,
      'startLon': start.longitude,
      'endLat': end.latitude,
      'endLon': end.longitude,
      'routerType': routerType,
      'waypoints': waypoints?.map((w) => w.toMap()).toList(),
    });

    if (result == null) {
      throw RoutingException('No se pudo calcular la ruta');
    }

    return RouteInfo.fromMap(result.cast<String, dynamic>());
  }

  /// Habilita notificaciones de giro
  static Future<void> enableTurnNotifications(bool enable) async {
    await _channel.invokeMethod('enableTurnNotifications', {
      'enable': enable,
    });
  }

  /// Verifica si las notificaciones están habilitadas
  static Future<bool> areTurnNotificationsEnabled() async {
    final result =
        await _channel.invokeMethod<bool>('areTurnNotificationsEnabled');
    return result ?? false;
  }
}
