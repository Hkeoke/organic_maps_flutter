import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'models/models.dart';
import 'organic_map_controller.dart';

/// Callback cuando el mapa está listo y el controller disponible.
typedef MapCreatedCallback = void Function(OrganicMapController controller);

/// Callback cuando cambia el modo de posición del usuario.
typedef MyPositionModeChangedCallback = void Function(
    MyPositionMode mode, String modeName);

/// Callback cuando el usuario toca el mapa.
typedef MapTapCallback = void Function(MapTapInfo tapInfo);

/// Callback cuando se construye una ruta.
typedef RouteBuiltCallback = void Function(RouteInfo routeInfo);

/// Callback cuando la navegación inicia.
typedef VoidCallback2 = void Function();

/// Widget que muestra el mapa de Organic Maps.
///
/// Ejemplo de uso:
/// ```dart
/// OrganicMapView(
///   onMapCreated: (controller) {
///     _mapController = controller;
///     controller.setCenter(
///       latitude: 40.4168,
///       longitude: -3.7038,
///       zoom: 12,
///     );
///   },
///   onMyPositionModeChanged: (mode, modeName) {
///     setState(() => _currentMode = mode);
///   },
///   onMapTap: (tapInfo) {
///     print('Tap en: ${tapInfo.latitude}, ${tapInfo.longitude}');
///   },
/// )
/// ```
class OrganicMapView extends StatefulWidget {
  /// Callback cuando el mapa está listo.
  final MapCreatedCallback? onMapCreated;

  /// Callback cuando cambia el modo de posición.
  final MyPositionModeChangedCallback? onMyPositionModeChanged;

  /// Callback cuando el usuario toca el mapa.
  final MapTapCallback? onMapTap;

  /// Callback cuando se construye una ruta exitosamente.
  final RouteBuiltCallback? onRouteBuilt;

  /// Callback cuando la navegación inicia.
  final VoidCallback? onNavigationStarted;

  /// Callback cuando la navegación se cancela.
  final VoidCallback? onNavigationCancelled;

  /// Reconocedores de gestos personalizados.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// Si la brújula está habilitada.
  final bool compassEnabled;

  /// Si la ubicación del usuario está habilitada.
  final bool myLocationEnabled;

  /// Si la capa de tráfico está habilitada al inicio.
  final bool trafficEnabled;

  /// Si el transporte público está habilitado al inicio.
  final bool transitEnabled;

  /// Estilo visual del mapa.
  final MapStyle theme;

  const OrganicMapView({
    super.key,
    this.onMapCreated,
    this.onMyPositionModeChanged,
    this.onMapTap,
    this.onRouteBuilt,
    this.onNavigationStarted,
    this.onNavigationCancelled,
    this.gestureRecognizers,
    this.compassEnabled = true,
    this.myLocationEnabled = true,
    this.trafficEnabled = false,
    this.transitEnabled = false,
    this.theme = MapStyle.defaultLight,
  });

  @override
  State<OrganicMapView> createState() => _OrganicMapViewState();
}

class _OrganicMapViewState extends State<OrganicMapView> {
  OrganicMapController? _controller;
  MethodChannel? _methodChannel;
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final gestureRecognizers = widget.gestureRecognizers ??
        <Factory<OneSequenceGestureRecognizer>>{};

    if (defaultTargetPlatform == TargetPlatform.android) {
      return PlatformViewLink(
        viewType: 'organic_maps_flutter/map_view',
        surfaceFactory: (context, controller) {
          return AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: gestureRecognizers,
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          );
        },
        onCreatePlatformView: (params) {
          return PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: 'organic_maps_flutter/map_view',
            layoutDirection: TextDirection.ltr,
            creationParams: _buildCreationParams(),
            creationParamsCodec: const StandardMessageCodec(),
          )
            ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
            ..addOnPlatformViewCreatedListener(_onPlatformViewCreated)
            ..create();
        },
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        viewType: 'organic_maps_flutter/map_view',
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: gestureRecognizers,
        creationParams: _buildCreationParams(),
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return Center(
      child: Text(
        'Plataforma no soportada: $defaultTargetPlatform',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  Map<String, dynamic> _buildCreationParams() {
    return {
      'compassEnabled': widget.compassEnabled,
      'myLocationEnabled': widget.myLocationEnabled,
      'trafficEnabled': widget.trafficEnabled,
      'transitEnabled': widget.transitEnabled,
      'theme': widget.theme.name,
    };
  }

  void _onPlatformViewCreated(int id) {
    _controller = OrganicMapController.internal(id);
    _methodChannel = MethodChannel('organic_maps_flutter/map_$id');

    _methodChannel!.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onMapReady':
          if (!_isMapReady && mounted) {
            _isMapReady = true;
            widget.onMapCreated?.call(_controller!);
          }
          break;

        case 'onMyPositionModeChanged':
          final mode = (call.arguments['mode'] as num).toInt();
          final modeName = call.arguments['modeName'] as String;
          final positionMode = MyPositionMode.fromValue(mode);
          widget.onMyPositionModeChanged?.call(positionMode, modeName);
          break;

        case 'onMapTap':
          final tapInfo = MapTapInfo.fromMap(
              Map<String, dynamic>.from(call.arguments as Map));
          widget.onMapTap?.call(tapInfo);
          break;

        case 'onRouteBuilt':
          final routeData =
              Map<String, dynamic>.from(call.arguments as Map);
          final routeInfo =
              RouteInfo.fromMap({...routeData, 'success': true});
          widget.onRouteBuilt?.call(routeInfo);
          break;

        case 'onNavigationStarted':
          widget.onNavigationStarted?.call();
          break;

        case 'onNavigationCancelled':
          widget.onNavigationCancelled?.call();
          break;
      }

      // Delegar al controlador para que actualice sus streams internos.
      _controller?.handleMethodCall(call);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _methodChannel?.setMethodCallHandler(null);
    super.dispose();
  }
}
