import 'dart:async';
import 'package:flutter/services.dart';
import 'models/models.dart';

/// Controlador para interactuar con el mapa de Organic Maps
class OrganicMapController {
  final MethodChannel _channel;

  /// Constructor interno - no usar directamente
  OrganicMapController.internal(int mapId)
      : _channel = MethodChannel('organic_maps_flutter/map_$mapId');

  // ==================== EVENTOS ====================
  
  final StreamController<List<Map<String, dynamic>>> _countriesChangedController = StreamController.broadcast();
  /// Stream de cambios de estado de países (descargas)
  Stream<List<Map<String, dynamic>>> get countriesChangedStream => _countriesChangedController.stream;

  final StreamController<Map<String, dynamic>> _countryProgressController = StreamController.broadcast();
  /// Stream de progreso de descarga
  Stream<Map<String, dynamic>> get countryProgressStream => _countryProgressController.stream;

  final StreamController<Map<String, dynamic>> _mobileDataRequiredController = StreamController.broadcast();
  /// Stream cuando se requiere confirmación de datos móviles
  Stream<Map<String, dynamic>> get mobileDataRequiredStream => _mobileDataRequiredController.stream;

  /// Maneja llamadas desde el lado nativo
  void handleMethodCall(MethodCall call) {
    if (call.method == 'onCountriesChanged') {
      try {
        final List<dynamic> args = call.arguments;
        final updates = args.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _countriesChangedController.add(updates);
      } catch (e) {
        print('Error parsing onCountriesChanged: $e');
      }
    } else if (call.method == 'onCountryProgress') {
      try {
        final update = Map<String, dynamic>.from(call.arguments as Map);
        _countryProgressController.add(update);
      } catch (e) {
        print('Error parsing onCountryProgress: $e');
      }
    } else if (call.method == 'onMobileDataRequired') {
      try {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _mobileDataRequiredController.add(data);
      } catch (e) {
        print('Error parsing onMobileDataRequired: $e');
      }
    }
  }

  // ==================== NAVEGACIÓN DEL MAPA ====================

  /// Establece el centro del mapa
  Future<void> setCenter({
    required double latitude,
    required double longitude,
    int zoom = 12,
    bool animate = true,
  }) async {
    await _channel.invokeMethod('setCenter', {
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'animate': animate,
    });
  }

  /// Muestra un rectángulo en el mapa
  Future<void> showRect({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    bool animate = true,
  }) async {
    await _channel.invokeMethod('showRect', {
      'minLat': minLat,
      'minLon': minLon,
      'maxLat': maxLat,
      'maxLon': maxLon,
      'animate': animate,
    });
  }

  /// Hace zoom in/out
  Future<void> zoom(ZoomMode mode, {bool animate = true}) async {
    await _channel.invokeMethod('zoom', {
      'mode': mode.name,
      'animate': animate,
    });
  }

  /// Rota el mapa
  Future<void> rotate(double azimuth, {bool animate = true}) async {
    await _channel.invokeMethod('rotate', {
      'azimuth': azimuth,
      'animate': animate,
    });
  }

  /// Obtiene la posición actual del viewport
  Future<MapViewport> getViewport() async {
    final result = await _channel.invokeMethod<Map>('getViewport');
    return MapViewport.fromMap(result!.cast<String, dynamic>());
  }

  /// Hace zoom a un punto específico
  Future<void> zoomToPoint({
    required double latitude,
    required double longitude,
    int zoom = 12,
    bool animate = true,
  }) async {
    await _channel.invokeMethod('zoomToPoint', {
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
      'animate': animate,
    });
  }

  // ==================== BÚSQUEDA ====================

  /// Busca en todo el mapa
  Future<List<SearchResult>> searchEverywhere(String query) async {
    final results = await _channel.invokeMethod<List>('searchEverywhere', {
      'query': query,
    });
    return results!
        .map((r) => SearchResult.fromMap(r.cast<String, dynamic>()))
        .toList();
  }

  /// Busca en el viewport actual
  Future<List<SearchResult>> searchInViewport(String query) async {
    final results = await _channel.invokeMethod<List>('searchInViewport', {
      'query': query,
    });
    return results!
        .map((r) => SearchResult.fromMap(r.cast<String, dynamic>()))
        .toList();
  }

  /// Cancela la búsqueda actual
  Future<void> cancelSearch() async {
    await _channel.invokeMethod('cancelSearch');
  }

  // ==================== RUTAS Y NAVEGACIÓN ====================

  /// Construye una ruta
  Future<RouteInfo> buildRoute({
    required LatLng start,
    required LatLng end,
    RouterType type = RouterType.vehicle,
    List<LatLng>? waypoints,
  }) async {
    final result = await _channel.invokeMethod<Map>('buildRoute', {
      'startLat': start.latitude,
      'startLon': start.longitude,
      'endLat': end.latitude,
      'endLon': end.longitude,
      'type': type.name,
      'waypoints': waypoints
          ?.map((w) => {
                'lat': w.latitude,
                'lon': w.longitude,
              })
          .toList(),
    });
    return RouteInfo.fromMap(result!.cast<String, dynamic>());
  }

  /// Inicia el seguimiento de ruta
  Future<void> followRoute() async {
    await _channel.invokeMethod('followRoute');
  }

  /// Detiene la navegación
  Future<void> stopNavigation() async {
    await _channel.invokeMethod('stopNavigation');
  }

  /// Obtiene información de la ruta actual
  Future<RouteFollowingInfo?> getRouteFollowingInfo() async {
    final result = await _channel.invokeMethod<Map>('getRouteFollowingInfo');
    if (result == null) return null;
    return RouteFollowingInfo.fromMap(result.cast<String, dynamic>());
  }

  // ==================== MARCADORES Y BOOKMARKS ====================

  /// Crea un bookmark
  Future<String> createBookmark({
    required double latitude,
    required double longitude,
    required String name,
    String? description,
    String? categoryId,
  }) async {
    final id = await _channel.invokeMethod<String>('createBookmark', {
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'description': description,
      'categoryId': categoryId,
    });
    return id!;
  }

  /// Elimina un bookmark
  Future<void> deleteBookmark(String bookmarkId) async {
    await _channel.invokeMethod('deleteBookmark', {
      'bookmarkId': bookmarkId,
    });
  }

  /// Obtiene todos los bookmarks
  Future<List<Bookmark>> getBookmarks() async {
    final results = await _channel.invokeMethod<List>('getBookmarks');
    return results!
        .map((r) => Bookmark.fromMap(r.cast<String, dynamic>()))
        .toList();
  }

  /// Muestra un bookmark en el mapa
  Future<void> showBookmark(String bookmarkId) async {
    await _channel.invokeMethod('showBookmark', {
      'bookmarkId': bookmarkId,
    });
  }

  // ==================== TRACKING GPS ====================

  /// Inicia la grabación de track
  Future<void> startTrackRecording() async {
    await _channel.invokeMethod('startTrackRecording');
  }

  /// Detiene la grabación de track
  Future<void> stopTrackRecording() async {
    await _channel.invokeMethod('stopTrackRecording');
  }

  /// Guarda el track actual
  Future<String> saveTrack(String name) async {
    final id = await _channel.invokeMethod<String>('saveTrack', {
      'name': name,
    });
    return id!;
  }

  /// Verifica si está grabando
  Future<bool> isTrackRecording() async {
    final result = await _channel.invokeMethod<bool>('isTrackRecording');
    return result ?? false;
  }

  // ==================== UBICACIÓN ====================

  /// Actualiza la ubicación del usuario
  Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? bearing,
    double? speed,
  }) async {
    await _channel.invokeMethod('updateLocation', {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'bearing': bearing,
      'speed': speed,
    });
  }

  /// Cambia el modo de posición
  Future<void> switchMyPositionMode() async {
    await _channel.invokeMethod('switchMyPositionMode');
  }

  /// Inicia actualizaciones de ubicación
  Future<void> startLocationUpdates() async {
    await _channel.invokeMethod('startLocationUpdates');
  }

  /// Detiene actualizaciones de ubicación
  Future<void> stopLocationUpdates() async {
    await _channel.invokeMethod('stopLocationUpdates');
  }

  /// Obtiene la posición actual del usuario
  Future<LatLng?> getMyPosition() async {
    final result = await _channel.invokeMethod<Map>('getMyPosition');
    if (result == null) return null;
    return LatLng(
      (result['latitude'] as num).toDouble(),
      (result['longitude'] as num).toDouble(),
    );
  }

  /// Obtiene la información completa de ubicación del usuario
  Future<Map<String, dynamic>?> getMyPositionDetails() async {
    final result = await _channel.invokeMethod<Map>('getMyPosition');
    if (result == null) return null;
    return result.cast<String, dynamic>();
  }

  // ==================== TRÁFICO Y TRANSPORTE ====================

  /// Habilita/deshabilita tráfico
  Future<void> setTrafficEnabled(bool enabled) async {
    await _channel.invokeMethod('setTrafficEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si el tráfico está habilitado
  Future<bool> isTrafficEnabled() async {
    final result = await _channel.invokeMethod<bool>('isTrafficEnabled');
    return result ?? false;
  }

  /// Habilita/deshabilita transporte público
  Future<void> setTransitEnabled(bool enabled) async {
    await _channel.invokeMethod('setTransitEnabled', {
      'enabled': enabled,
    });
  }

  // ==================== CAPAS DEL MAPA ====================

  /// Habilita/deshabilita capa de metro/subway
  Future<void> setSubwayEnabled(bool enabled) async {
    await _channel.invokeMethod('setSubwayEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si la capa de metro está habilitada
  Future<bool> isSubwayEnabled() async {
    final result = await _channel.invokeMethod<bool>('isSubwayEnabled');
    return result ?? false;
  }

  /// Habilita/deshabilita isolíneas (curvas de nivel)
  Future<void> setIsolinesEnabled(bool enabled) async {
    await _channel.invokeMethod('setIsolinesEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si las isolíneas están habilitadas
  Future<bool> isIsolinesEnabled() async {
    final result = await _channel.invokeMethod<bool>('isIsolinesEnabled');
    return result ?? false;
  }

  // ==================== TTS / VOZ ====================

  /// Habilita/deshabilita instrucciones de voz (TTS)
  Future<void> setTtsEnabled(bool enabled) async {
    await _channel.invokeMethod('setTtsEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si TTS está habilitado
  Future<bool> isTtsEnabled() async {
    final result = await _channel.invokeMethod<bool>('isTtsEnabled');
    return result ?? false;
  }

  /// Establece el volumen de TTS (0.0 a 1.0)
  Future<void> setTtsVolume(double volume) async {
    await _channel.invokeMethod('setTtsVolume', {
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Obtiene el volumen actual de TTS
  Future<double> getTtsVolume() async {
    final result = await _channel.invokeMethod<double>('getTtsVolume');
    return result ?? 1.0;
  }

  // ==================== CONFIGURACIÓN DEL MAPA ====================

  /// Habilita/deshabilita modo 3D
  Future<void> set3dMode({
    required bool enabled,
    bool buildings = true,
  }) async {
    await _channel.invokeMethod('set3dMode', {
      'enabled': enabled,
      'buildings': buildings,
    });
  }

  /// Habilita/deshabilita auto zoom durante navegación
  Future<void> setAutoZoom(bool enabled) async {
    await _channel.invokeMethod('setAutoZoom', {
      'enabled': enabled,
    });
  }

  /// Establece el estilo del mapa
  Future<void> setMapStyle(MapStyle style) async {
    await _channel.invokeMethod('setMapStyle', {
      'style': style.name,
    });
  }

  /// Obtiene el estilo actual del mapa
  Future<MapStyle> getMapStyle() async {
    final result = await _channel.invokeMethod<String>('getMapStyle');
    return MapStyle.values.firstWhere(
      (s) => s.name == result,
      orElse: () => MapStyle.defaultLight,
    );
  }

  // ==================== EDITOR DE MAPAS ====================

  /// Verifica si se puede editar una característica
  Future<bool> canEditFeature() async {
    final result = await _channel.invokeMethod<bool>('canEditFeature');
    return result ?? false;
  }

  /// Inicia la edición de una característica
  Future<void> startEdit() async {
    await _channel.invokeMethod('startEdit');
  }

  /// Guarda la característica editada
  Future<bool> saveEditedFeature() async {
    final result = await _channel.invokeMethod<bool>('saveEditedFeature');
    return result ?? false;
  }

  /// Crea un nuevo objeto en el mapa
  Future<void> createMapObject(String type) async {
    await _channel.invokeMethod('createMapObject', {
      'type': type,
    });
  }

  // ==================== GESTIÓN DE MAPAS ====================

  /// Obtiene la lista de países disponibles
  Future<List<Country>> getCountries() async {
    final results = await _channel.invokeMethod<List>('getCountries');
    return results!
        .map((r) => Country.fromMap(r.cast<String, dynamic>()))
        .toList();
  }

  /// Descarga un país
  Future<Map<String, dynamic>?> downloadCountry(String countryId) async {
    final result = await _channel.invokeMethod<Map>('downloadCountry', {
      'countryId': countryId,
    });
    return result?.cast<String, dynamic>();
  }

  /// Habilita las descargas por datos móviles (3G/4G/5G)
  /// Una vez habilitado, no se puede deshabilitar programáticamente
  Future<void> enableMobileDataDownloads() async {
    await _channel.invokeMethod('setMobileDataPolicy', {
      'enabled': true,
    });
  }

  /// Elimina un país descargado
  Future<void> deleteCountry(String countryId) async {
    await _channel.invokeMethod('deleteCountry', {
      'countryId': countryId,
    });
  }

  /// Cancela la descarga de un país
  Future<void> cancelDownload(String countryId) async {
    await _channel.invokeMethod('cancelDownload', {
      'countryId': countryId,
    });
  }

  // ==================== LIMPIEZA ====================

  /// Libera recursos
  void dispose() {
    _countriesChangedController.close();
    _countryProgressController.close();
    _mobileDataRequiredController.close();
  }
}

enum ZoomMode { zoomIn, zoomOut }

enum RouterType {
  vehicle,
  pedestrian,
  bicycle,
  transit,
}

enum MapStyle {
  defaultLight,
  defaultDark,
  vehicleLight,
  vehicleDark,
  outdoorsLight,
  outdoorsDark,
}
