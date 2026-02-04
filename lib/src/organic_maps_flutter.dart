import 'dart:async';
import 'package:flutter/services.dart';
import 'models/models.dart';

/// Clase principal del plugin Organic Maps Flutter
class OrganicMapsFlutter {
  static const MethodChannel _channel = MethodChannel('organic_maps_flutter');

  static bool _initialized = false;

  /// Inicializa el framework de Organic Maps
  static Future<void> initialize({
    String? dataPath,
    bool loadMaps = true,
  }) async {
    if (_initialized) return;

    try {
      await _channel.invokeMethod('initialize', {
        'dataPath': dataPath,
        'loadMaps': loadMaps,
      });
      _initialized = true;
    } catch (e) {
      throw OrganicMapsException('Error al inicializar: $e');
    }
  }

  /// Verifica si el framework está inicializado
  static bool get isInitialized => _initialized;

  /// Obtiene la versión de datos de los mapas
  static Future<int> getDataVersion() async {
    try {
      final version = await _channel.invokeMethod<int>('getDataVersion');
      return version ?? 0;
    } catch (e) {
      throw OrganicMapsException('Error al obtener versión: $e');
    }
  }

  /// Limpia todas las cachés
  static Future<void> clearCaches() async {
    try {
      await _channel.invokeMethod('clearCaches');
    } catch (e) {
      throw OrganicMapsException('Error al limpiar cachés: $e');
    }
  }

  /// Obtiene la plataforma actual
  static Future<String> getPlatformVersion() async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
