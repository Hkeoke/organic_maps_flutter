import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'models/models.dart';

/// Controlador principal para interactuar con el mapa de Organic Maps.
///
/// Cada instancia está vinculada a un [OrganicMapView] específico mediante
/// su `mapId`. Proporciona control completo sobre navegación, búsqueda,
/// rutas, capas del mapa, y más.
///
/// **No instanciar directamente** — se obtiene a través del callback
/// [OrganicMapView.onMapCreated].
///
/// Ejemplo:
/// ```dart
/// OrganicMapView(
///   onMapCreated: (controller) {
///     // Usar el controller
///     controller.setCenter(latitude: 40.4168, longitude: -3.7038);
///   },
/// )
/// ```
class OrganicMapController {
  final MethodChannel _channel;

  /// Constructor interno - no usar directamente.
  OrganicMapController.internal(int mapId)
      : _channel = MethodChannel('organic_maps_flutter/map_$mapId');

  // ==================== STREAMS DE EVENTOS ====================

  final StreamController<List<CountryStatusUpdate>> _countriesChangedController =
      StreamController.broadcast();
  final StreamController<DownloadProgress> _countryProgressController =
      StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _mobileDataRequiredController =
      StreamController.broadcast();
  final StreamController<MyPositionMode> _positionModeController =
      StreamController.broadcast();
  final StreamController<void> _navigationStartedController =
      StreamController.broadcast();
  final StreamController<void> _navigationCancelledController =
      StreamController.broadcast();
  final StreamController<RouteInfo> _routeBuiltController =
      StreamController.broadcast();
  final StreamController<MapTapInfo> _mapTapController =
      StreamController.broadcast();

  /// Stream de cambios de estado de países (descargas).
  Stream<List<CountryStatusUpdate>> get onCountriesChanged =>
      _countriesChangedController.stream;

  /// Stream de progreso de descarga.
  Stream<DownloadProgress> get onDownloadProgress =>
      _countryProgressController.stream;

  /// Stream cuando se requiere confirmación de datos móviles.
  Stream<Map<String, dynamic>> get onMobileDataRequired =>
      _mobileDataRequiredController.stream;

  /// Stream de cambios en el modo de posición.
  Stream<MyPositionMode> get onPositionModeChanged =>
      _positionModeController.stream;

  /// Stream emitido cuando la navegación inicia.
  Stream<void> get onNavigationStarted =>
      _navigationStartedController.stream;

  /// Stream emitido cuando la navegación se cancela.
  Stream<void> get onNavigationCancelled =>
      _navigationCancelledController.stream;

  /// Stream emitido cuando una ruta se construye exitosamente.
  Stream<RouteInfo> get onRouteBuilt => _routeBuiltController.stream;

  /// Stream de taps en el mapa.
  Stream<MapTapInfo> get onMapTap => _mapTapController.stream;

  /// Maneja llamadas desde el lado nativo.
  void handleMethodCall(MethodCall call) {
    try {
      switch (call.method) {
        case 'onCountriesChanged':
          final List<dynamic> args = call.arguments;
          final updates = args
              .map((e) => CountryStatusUpdate.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
          _countriesChangedController.add(updates);
          break;

        case 'onCountryProgress':
          final data = Map<String, dynamic>.from(call.arguments as Map);
          _countryProgressController.add(DownloadProgress.fromMap(data));
          break;

        case 'onMobileDataRequired':
          final data = Map<String, dynamic>.from(call.arguments as Map);
          _mobileDataRequiredController.add(data);
          break;

        case 'onMyPositionModeChanged':
          final mode = (call.arguments['mode'] as num).toInt();
          _positionModeController.add(MyPositionMode.fromValue(mode));
          break;

        case 'onNavigationStarted':
          _navigationStartedController.add(null);
          break;

        case 'onNavigationCancelled':
          _navigationCancelledController.add(null);
          break;

        case 'onRouteBuilt':
          final data = Map<String, dynamic>.from(call.arguments as Map);
          _routeBuiltController.add(RouteInfo.fromMap({...data, 'success': true}));
          break;

        case 'onMapTap':
          final data = Map<String, dynamic>.from(call.arguments as Map);
          _mapTapController.add(MapTapInfo.fromMap(data));
          break;
      }
    } catch (e, stack) {
      developer.log(
        'Error handling native method call: ${call.method}',
        error: e,
        stackTrace: stack,
        name: 'OrganicMapController',
      );
    }
  }

  // ==================== NAVEGACIÓN DEL MAPA ====================

  /// Establece el centro del mapa.
  ///
  /// [zoom] controla el nivel de acercamiento (1-20).
  /// [animate] determina si la transición es animada.
  Future<void> setCenter({
    required double latitude,
    required double longitude,
    double zoom = 12,
    bool animate = true,
  }) async {
    await _channel.invokeMethod('setCenter', {
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom.toInt(),
      'animate': animate,
    });
  }

  /// Muestra un rectángulo (bounding box) en el mapa.
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

  /// Hace zoom in o out.
  Future<void> zoom(ZoomMode mode, {bool animate = true}) async {
    await _channel.invokeMethod('zoom', {
      'mode': mode.name,
      'animate': animate,
    });
  }

  /// Rota el mapa al azimut especificado (en grados).
  Future<void> rotate(double azimuth, {bool animate = true}) async {
    await _channel.invokeMethod('rotate', {
      'azimuth': azimuth,
      'animate': animate,
    });
  }

  /// Obtiene la posición actual del viewport.
  Future<MapViewport> getViewport() async {
    final result = await _channel.invokeMethod<Map>('getViewport');
    return MapViewport.fromMap(result!.cast<String, dynamic>());
  }

  /// Hace zoom a un punto específico.
  Future<void> zoomToPoint({
    required double latitude,
    required double longitude,
    double zoom = 12,
    bool animate = true,
  }) async {
    await _channel.invokeMethod('zoomToPoint', {
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom.toInt(),
      'animate': animate,
    });
  }

  // ==================== BÚSQUEDA ====================

  /// Busca en todo el mapa.
  ///
  /// Retorna una lista de [SearchResult]. Si la búsqueda no produce
  /// resultados, retorna una lista vacía.
  Future<List<SearchResult>> searchEverywhere(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final results = await _channel.invokeMethod<List>('searchEverywhere', {
        'query': query.trim(),
      });

      if (results == null || results.isEmpty) return [];

      return results
          .map((r) => SearchResult.fromMap(
              Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PlatformException catch (e) {
      throw SearchException(
        'Error en búsqueda: ${e.message}',
        e,
      );
    }
  }

  /// Busca en el viewport actual del mapa.
  Future<List<SearchResult>> searchInViewport(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final results = await _channel.invokeMethod<List>('searchInViewport', {
        'query': query.trim(),
      });

      if (results == null || results.isEmpty) return [];

      return results
          .map((r) => SearchResult.fromMap(
              Map<String, dynamic>.from(r as Map)))
          .toList();
    } on PlatformException catch (e) {
      throw SearchException(
        'Error en búsqueda en viewport: ${e.message}',
        e,
      );
    }
  }

  /// Cancela la búsqueda actual.
  Future<void> cancelSearch() async {
    await _channel.invokeMethod('cancelSearch');
  }

  // ==================== RUTAS Y NAVEGACIÓN ====================

  /// Construye una ruta entre dos puntos.
  ///
  /// [start] y [end] son los puntos de inicio y fin.
  /// [type] define el tipo de ruta (vehículo, peatón, bicicleta, transporte).
  /// [waypoints] son puntos intermedios opcionales.
  ///
  /// Retorna un [RouteInfo] con información de la ruta calculada.
  /// Escucha [onRouteBuilt] para recibir la información final cuando
  /// el motor termine de calcular.
  Future<RouteInfo> buildRoute({
    required LatLng start,
    required LatLng end,
    RouterType type = RouterType.vehicle,
    List<LatLng>? waypoints,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map>('buildRoute', {
        'startLat': start.latitude,
        'startLon': start.longitude,
        'endLat': end.latitude,
        'endLon': end.longitude,
        'type': type.name,
        'waypoints': waypoints
            ?.map((w) => {'lat': w.latitude, 'lon': w.longitude})
            .toList(),
      });
      return RouteInfo.fromMap(result!.cast<String, dynamic>());
    } on PlatformException catch (e) {
      throw RoutingException(
        'Error construyendo ruta: ${e.message}',
        e,
      );
    }
  }

  /// Inicia el seguimiento de ruta (navegación activa).
  ///
  /// Debe llamarse después de que [buildRoute] haya terminado
  /// y la ruta esté construida.
  Future<void> followRoute() async {
    await _channel.invokeMethod('followRoute');
  }

  /// Detiene la navegación activa.
  Future<void> stopNavigation() async {
    await _channel.invokeMethod('stopNavigation');
  }

  /// Obtiene información de la ruta en tiempo real.
  ///
  /// Retorna `null` si no hay navegación activa.
  Future<RouteFollowingInfo?> getRouteFollowingInfo() async {
    final result = await _channel.invokeMethod<Map>('getRouteFollowingInfo');
    if (result == null) return null;
    return RouteFollowingInfo.fromMap(result.cast<String, dynamic>());
  }

  // ==================== MARCADORES Y BOOKMARKS ====================

  /// Crea un bookmark en la posición indicada.
  ///
  /// Retorna el ID del bookmark creado.
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

  /// Elimina un bookmark por su ID.
  Future<void> deleteBookmark(String bookmarkId) async {
    await _channel.invokeMethod('deleteBookmark', {
      'bookmarkId': bookmarkId,
    });
  }

  /// Obtiene todos los bookmarks.
  Future<List<Bookmark>> getBookmarks() async {
    final results = await _channel.invokeMethod<List>('getBookmarks');
    if (results == null) return [];
    return results
        .map((r) => Bookmark.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Centra el mapa en un bookmark.
  Future<void> showBookmark(String bookmarkId) async {
    await _channel.invokeMethod('showBookmark', {
      'bookmarkId': bookmarkId,
    });
  }

  // ==================== TRACKING GPS ====================

  /// Inicia la grabación de track GPS.
  ///
  /// Lanza [LocationPermissionException] si faltan permisos.
  Future<TrackRecordingResult> startTrackRecording() async {
    try {
      final result = await _channel.invokeMethod<Map>('startTrackRecording');
      if (result == null) {
        return const TrackRecordingResult(success: true, isRecording: true);
      }
      return TrackRecordingResult(
        success: result['success'] == true,
        isRecording: result['isRecording'] == true,
      );
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        throw const LocationPermissionException();
      }
      rethrow;
    }
  }

  /// Detiene la grabación de track.
  Future<TrackRecordingResult> stopTrackRecording() async {
    try {
      final result = await _channel.invokeMethod<Map>('stopTrackRecording');
      if (result == null) {
        return const TrackRecordingResult(success: true, isRecording: false);
      }
      return TrackRecordingResult(
        success: result['success'] == true,
        isRecording: false,
        wasEmpty: result['wasEmpty'] == true,
      );
    } catch (e) {
      developer.log('Error stopping track recording: $e',
          name: 'OrganicMapController');
      rethrow;
    }
  }

  /// Guarda el track actual con el nombre especificado.
  ///
  /// Lanza [TrackRecordingException] si el track está vacío.
  Future<String> saveTrack(String name) async {
    try {
      final result = await _channel.invokeMethod<Map>('saveTrack', {
        'name': name,
      });
      if (result == null) return name;
      if (result['success'] == true) {
        return result['name'] as String? ?? name;
      }
      throw const TrackRecordingException('Error al guardar el track');
    } on PlatformException catch (e) {
      if (e.code == 'EMPTY_TRACK') {
        throw const TrackRecordingException(
            'El track está vacío, no hay datos para guardar');
      }
      rethrow;
    }
  }

  /// Verifica el estado de la grabación de track.
  Future<TrackRecordingStatus> isTrackRecording() async {
    try {
      final result = await _channel.invokeMethod<Map>('isTrackRecording');
      if (result == null) return TrackRecordingStatus.inactive();
      return TrackRecordingStatus(
        isRecording: result['isRecording'] == true,
        isEmpty: result['isEmpty'] != false,
        isGpsTrackerEnabled: result['isGpsTrackerEnabled'] == true,
      );
    } catch (e) {
      developer.log('Error checking track recording status: $e',
          name: 'OrganicMapController');
      return TrackRecordingStatus.inactive();
    }
  }

  // ==================== UBICACIÓN ====================

  /// Actualiza la ubicación del usuario manualmente.
  ///
  /// **Nota:** En la mayoría de los casos, la ubicación se maneja
  /// nativamente por el motor del mapa. Usa esto solo para inyectar
  /// ubicaciones personalizadas (ej: simulación).
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

  /// Cambia al siguiente modo de posición (cicla entre modos).
  Future<void> switchMyPositionMode() async {
    await _channel.invokeMethod('switchMyPositionMode');
  }

  /// Inicia actualizaciones de ubicación del motor nativo.
  Future<void> startLocationUpdates() async {
    await _channel.invokeMethod('startLocationUpdates');
  }

  /// Detiene actualizaciones de ubicación.
  Future<void> stopLocationUpdates() async {
    await _channel.invokeMethod('stopLocationUpdates');
  }

  /// Obtiene la posición actual del usuario.
  ///
  /// Retorna `null` si la ubicación no está disponible.
  Future<LatLng?> getMyPosition() async {
    final result = await _channel.invokeMethod<Map>('getMyPosition');
    if (result == null) return null;
    return LatLng(
      (result['latitude'] as num).toDouble(),
      (result['longitude'] as num).toDouble(),
    );
  }

  /// Obtiene la información completa de ubicación del usuario.
  ///
  /// Incluye accuracy, altitude, bearing, speed y timestamp.
  Future<LocationInfo?> getMyPositionDetails() async {
    final result = await _channel.invokeMethod<Map>('getMyPosition');
    if (result == null) return null;
    return LocationInfo.fromMap(result.cast<String, dynamic>());
  }

  // ==================== TRÁFICO Y TRANSPORTE ====================

  /// Habilita/deshabilita la capa de tráfico.
  Future<void> setTrafficEnabled(bool enabled) async {
    await _channel.invokeMethod('setTrafficEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si la capa de tráfico está habilitada.
  Future<bool> isTrafficEnabled() async {
    final result = await _channel.invokeMethod<bool>('isTrafficEnabled');
    return result ?? false;
  }

  /// Habilita/deshabilita transporte público.
  Future<void> setTransitEnabled(bool enabled) async {
    await _channel.invokeMethod('setTransitEnabled', {
      'enabled': enabled,
    });
  }

  // ==================== CAPAS DEL MAPA ====================

  /// Habilita/deshabilita la capa de metro/subway.
  Future<void> setSubwayEnabled(bool enabled) async {
    await _channel.invokeMethod('setSubwayEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si la capa de metro está habilitada.
  Future<bool> isSubwayEnabled() async {
    final result = await _channel.invokeMethod<bool>('isSubwayEnabled');
    return result ?? false;
  }

  /// Habilita/deshabilita isolíneas (curvas de nivel).
  Future<void> setIsolinesEnabled(bool enabled) async {
    await _channel.invokeMethod('setIsolinesEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si las isolíneas están habilitadas.
  Future<bool> isIsolinesEnabled() async {
    final result = await _channel.invokeMethod<bool>('isIsolinesEnabled');
    return result ?? false;
  }

  // ==================== TTS / VOZ ====================

  /// Habilita/deshabilita instrucciones de voz (TTS).
  Future<void> setTtsEnabled(bool enabled) async {
    await _channel.invokeMethod('setTtsEnabled', {
      'enabled': enabled,
    });
  }

  /// Verifica si TTS está habilitado.
  Future<bool> isTtsEnabled() async {
    final result = await _channel.invokeMethod<bool>('isTtsEnabled');
    return result ?? false;
  }

  /// Establece el volumen de TTS (0.0 a 1.0).
  Future<void> setTtsVolume(double volume) async {
    await _channel.invokeMethod('setTtsVolume', {
      'volume': volume.clamp(0.0, 1.0),
    });
  }

  /// Obtiene el volumen actual de TTS.
  Future<double> getTtsVolume() async {
    final result = await _channel.invokeMethod<double>('getTtsVolume');
    return result ?? 1.0;
  }

  // ==================== CONFIGURACIÓN DEL MAPA ====================

  /// Habilita/deshabilita modo 3D.
  Future<void> set3dMode({
    required bool enabled,
    bool buildings = true,
  }) async {
    await _channel.invokeMethod('set3dMode', {
      'enabled': enabled,
      'buildings': buildings,
    });
  }

  /// Habilita/deshabilita auto zoom durante navegación.
  Future<void> setAutoZoom(bool enabled) async {
    await _channel.invokeMethod('setAutoZoom', {
      'enabled': enabled,
    });
  }

  /// Establece el estilo del mapa.
  Future<void> setMapStyle(MapStyle style) async {
    await _channel.invokeMethod('setMapStyle', {
      'style': style.name,
    });
  }

  /// Obtiene el estilo actual del mapa.
  Future<MapStyle> getMapStyle() async {
    final result = await _channel.invokeMethod<String>('getMapStyle');
    return MapStyle.values.firstWhere(
      (s) => s.name == result,
      orElse: () => MapStyle.defaultLight,
    );
  }

  // ==================== EDITOR DE MAPAS ====================

  /// Verifica si se puede editar la característica seleccionada.
  Future<bool> canEditFeature() async {
    final result = await _channel.invokeMethod<bool>('canEditFeature');
    return result ?? false;
  }

  /// Inicia la edición de una característica.
  Future<void> startEdit() async {
    await _channel.invokeMethod('startEdit');
  }

  /// Guarda la característica editada.
  Future<bool> saveEditedFeature() async {
    final result = await _channel.invokeMethod<bool>('saveEditedFeature');
    return result ?? false;
  }

  /// Crea un nuevo objeto en el mapa.
  Future<void> createMapObject(String type) async {
    await _channel.invokeMethod('createMapObject', {
      'type': type,
    });
  }

  // ==================== GESTIÓN DE MAPAS ====================

  /// Obtiene la lista de países/regiones disponibles para descargar.
  Future<List<Country>> getCountries() async {
    final results = await _channel.invokeMethod<List>('getCountries');
    if (results == null) return [];
    return results
        .map((r) => Country.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Descarga un país/región.
  ///
  /// Retorna información sobre si se requirió confirmación.
  /// Escucha [onDownloadProgress] para el progreso de descarga.
  /// Escucha [onCountriesChanged] para cambios de estado.
  Future<Map<String, dynamic>?> downloadCountry(String countryId) async {
    try {
      final result = await _channel.invokeMethod<Map>('downloadCountry', {
        'countryId': countryId,
      });
      return result?.cast<String, dynamic>();
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NO_INTERNET':
          throw const NetworkException();
        case 'NO_SPACE':
          throw const InsufficientStorageException();
        default:
          throw DownloadException('Error descargando mapa: ${e.message}', e);
      }
    }
  }

  /// Habilita las descargas por datos móviles (3G/4G/5G).
  Future<void> enableMobileDataDownloads() async {
    await _channel.invokeMethod('setMobileDataPolicy', {
      'enabled': true,
    });
  }

  /// Elimina un país descargado.
  Future<void> deleteCountry(String countryId) async {
    await _channel.invokeMethod('deleteCountry', {
      'countryId': countryId,
    });
  }

  /// Cancela la descarga de un país.
  Future<void> cancelDownload(String countryId) async {
    await _channel.invokeMethod('cancelDownload', {
      'countryId': countryId,
    });
  }

  // ==================== LIMPIEZA ====================

  /// Libera recursos. Debe llamarse cuando el mapa ya no se necesita.
  void dispose() {
    _countriesChangedController.close();
    _countryProgressController.close();
    _mobileDataRequiredController.close();
    _positionModeController.close();
    _navigationStartedController.close();
    _navigationCancelledController.close();
    _routeBuiltController.close();
    _mapTapController.close();
  }
}

// ==================== MODELOS AUXILIARES DEL CONTROLLER ====================

/// Información de un tap en el mapa.
class MapTapInfo {
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;

  const MapTapInfo({
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  factory MapTapInfo.fromMap(Map<String, dynamic> map) {
    return MapTapInfo(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      name: map['name'] as String?,
      address: map['address'] as String?,
    );
  }

  LatLng get position => LatLng(latitude, longitude);

  @override
  String toString() =>
      'MapTapInfo(lat: $latitude, lon: $longitude, name: $name)';
}

/// Información de ubicación completa.
class LocationInfo {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? bearing;
  final double? speed;
  final DateTime? timestamp;

  const LocationInfo({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.bearing,
    this.speed,
    this.timestamp,
  });

  factory LocationInfo.fromMap(Map<String, dynamic> map) {
    return LocationInfo(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      bearing: (map['bearing'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['timestamp'] as num).toInt())
          : null,
    );
  }

  LatLng get position => LatLng(latitude, longitude);

  /// Velocidad en km/h (la nativa viene en m/s).
  double? get speedKmh => speed != null ? speed! * 3.6 : null;

  @override
  String toString() =>
      'LocationInfo(lat: $latitude, lon: $longitude, accuracy: $accuracy)';
}

/// Actualización de estado de un país en la descarga.
class CountryStatusUpdate {
  final String countryId;
  final String status;

  const CountryStatusUpdate({
    required this.countryId,
    required this.status,
  });

  factory CountryStatusUpdate.fromMap(Map<String, dynamic> map) {
    return CountryStatusUpdate(
      countryId: map['countryId'] as String,
      status: map['status'] as String,
    );
  }

  @override
  String toString() =>
      'CountryStatusUpdate(countryId: $countryId, status: $status)';
}

/// Progreso de descarga de un país.
class DownloadProgress {
  final String countryId;
  final int progress;

  const DownloadProgress({
    required this.countryId,
    required this.progress,
  });

  factory DownloadProgress.fromMap(Map<String, dynamic> map) {
    return DownloadProgress(
      countryId: map['countryId'] as String,
      progress: (map['progress'] as num).toInt(),
    );
  }

  /// Progreso normalizado (0.0 a 1.0).
  double get normalized => progress / 100.0;

  @override
  String toString() =>
      'DownloadProgress(countryId: $countryId, progress: $progress%)';
}
