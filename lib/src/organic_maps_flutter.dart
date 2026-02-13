import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'models/models.dart';

/// Clase principal del plugin Organic Maps Flutter.
///
/// Se encarga de la inicialización global del framework de mapas.
/// Debe llamarse [initialize] antes de usar cualquier otra funcionalidad.
///
/// Ejemplo:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await OrganicMapsFlutter.initialize();
///   runApp(MyApp());
/// }
/// ```
class OrganicMapsFlutter {
  static const MethodChannel _channel = MethodChannel('organic_maps_flutter');

  static bool _initialized = false;

  /// Inicializa el framework de Organic Maps.
  ///
  /// [dataPath] ruta personalizada para los datos del mapa.
  /// [loadMaps] si se deben cargar los mapas al inicio.
  ///
  /// Lanza [OrganicMapsException] si la inicialización falla.
  /// No hace nada si ya fue inicializado.
  static Future<void> initialize({
    String? dataPath,
    bool loadMaps = true,
  }) async {
    if (_initialized) {
      developer.log(
        'OrganicMapsFlutter ya está inicializado',
        name: 'OrganicMapsFlutter',
      );
      return;
    }

    try {
      await _channel.invokeMethod('initialize', {
        'dataPath': dataPath,
        'loadMaps': loadMaps,
      });
      _initialized = true;
      developer.log(
        'OrganicMapsFlutter inicializado correctamente',
        name: 'OrganicMapsFlutter',
      );
    } catch (e) {
      throw OrganicMapsException('Error al inicializar: $e', e);
    }
  }

  /// Verifica si el framework está inicializado.
  static bool get isInitialized => _initialized;

  /// Obtiene la versión de datos de los mapas.
  static Future<int> getDataVersion() async {
    try {
      final version = await _channel.invokeMethod<int>('getDataVersion');
      return version ?? 0;
    } catch (e) {
      throw OrganicMapsException('Error al obtener versión: $e', e);
    }
  }

  /// Limpia todas las cachés del motor de mapas.
  static Future<void> clearCaches() async {
    try {
      await _channel.invokeMethod('clearCaches');
    } catch (e) {
      throw OrganicMapsException('Error al limpiar cachés: $e', e);
    }
  }

  /// Obtiene la versión de la plataforma (Android/iOS).
  static Future<String> getPlatformVersion() async {
    final String version =
        await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
