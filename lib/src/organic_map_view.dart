import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'organic_map_controller.dart';

typedef MapCreatedCallback = void Function(OrganicMapController controller);
typedef MyPositionModeChangedCallback = void Function(int mode, String modeName);
typedef MapTapCallback = void Function(double latitude, double longitude);
typedef RouteBuiltCallback = void Function(Map<String, dynamic> routeInfo);

/// Widget que muestra el mapa de Organic Maps
class OrganicMapView extends StatefulWidget {
  final MapCreatedCallback? onMapCreated;
  final MyPositionModeChangedCallback? onMyPositionModeChanged;
  final MapTapCallback? onMapTap;
  final RouteBuiltCallback? onRouteBuilt;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;
  final bool compassEnabled;
  final bool myLocationEnabled;
  final bool trafficEnabled;
  final bool transitEnabled;
  final MapTheme theme;

  const OrganicMapView({
    super.key,
    this.onMapCreated,
    this.onMyPositionModeChanged,
    this.onMapTap,
    this.onRouteBuilt,
    this.gestureRecognizers,
    this.compassEnabled = true,
    this.myLocationEnabled = true,
    this.trafficEnabled = false,
    this.transitEnabled = false,
    this.theme = MapTheme.defaultLight,
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
    // Configuración de reconocedores de gestos
    final gestureRecognizers = widget.gestureRecognizers ?? 
      <Factory<OneSequenceGestureRecognizer>>{};
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Usar PlatformViewLink con AndroidViewSurface para Hybrid Composition
      // Esto permite que los widgets de Flutter se rendericen encima del mapa
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

    return Text('Plataforma no soportada: $defaultTargetPlatform');
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
    
    // Escuchar eventos desde el lado nativo
    _methodChannel!.setMethodCallHandler((call) async {
      if (call.method == 'onMapReady') {
        if (!_isMapReady && mounted) {
          _isMapReady = true;
          // AHORA sí llamar al callback - el Framework está listo
          widget.onMapCreated?.call(_controller!);
        }
      } else if (call.method == 'onMyPositionModeChanged') {
        final mode = call.arguments['mode'] as int;
        final modeName = call.arguments['modeName'] as String;
        widget.onMyPositionModeChanged?.call(mode, modeName);
      } else if (call.method == 'onMapTap') {
        final lat = call.arguments['latitude'] as double;
        final lon = call.arguments['longitude'] as double;
        widget.onMapTap?.call(lat, lon);
      } else if (call.method == 'onRouteBuilt') {
        final routeInfo = Map<String, dynamic>.from(call.arguments as Map);
        widget.onRouteBuilt?.call(routeInfo);
      }
      
      // Delegar otros eventos al controlador
      _controller?.handleMethodCall(call);
    });
    
    // NO llamar onMapCreated aquí - esperar a que el Framework esté listo
  }

  @override
  void dispose() {
    _controller?.dispose();
    _methodChannel?.setMethodCallHandler(null);
    super.dispose();
  }
}

enum MapTheme {
  defaultLight,
  defaultDark,
  outdoorsLight,
  outdoorsDark,
  vehicleLight,
  vehicleDark,
}
