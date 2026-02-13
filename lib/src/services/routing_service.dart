import '../models/models.dart';
import '../organic_map_controller.dart';

/// Servicio de alto nivel para gestionar rutas y navegación.
///
/// Usa directamente un [OrganicMapController] en lugar de
/// un MethodChannel separado, evitando problemas de sincronización.
///
/// Ejemplo:
/// ```dart
/// final routing = RoutingService(controller);
///
/// final route = await routing.calculateRoute(
///   start: LatLng(40.4168, -3.7038),
///   end: LatLng(41.3851, 2.1734),
///   routerType: RouterType.vehicle,
/// );
///
/// if (route.success) {
///   await routing.startNavigation();
/// }
/// ```
class RoutingService {
  final OrganicMapController _controller;

  RoutingService(this._controller);

  /// Calcula una ruta entre dos puntos.
  Future<RouteInfo> calculateRoute({
    required LatLng start,
    required LatLng end,
    RouterType routerType = RouterType.vehicle,
    List<LatLng>? waypoints,
  }) async {
    return _controller.buildRoute(
      start: start,
      end: end,
      type: routerType,
      waypoints: waypoints,
    );
  }

  /// Inicia la navegación (seguimiento de ruta).
  Future<void> startNavigation() async {
    await _controller.followRoute();
  }

  /// Detiene la navegación actual.
  Future<void> stopNavigation() async {
    await _controller.stopNavigation();
  }

  /// Obtiene información de seguimiento de ruta en tiempo real.
  Future<RouteFollowingInfo?> getFollowingInfo() async {
    return _controller.getRouteFollowingInfo();
  }

  /// Stream de cuando se construye una ruta.
  Stream<RouteInfo> get onRouteBuilt => _controller.onRouteBuilt;

  /// Stream de cuando la navegación inicia.
  Stream<void> get onNavigationStarted => _controller.onNavigationStarted;

  /// Stream de cuando la navegación se cancela.
  Stream<void> get onNavigationCancelled => _controller.onNavigationCancelled;
}
