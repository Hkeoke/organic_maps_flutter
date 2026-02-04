import 'package:flutter/services.dart';
import '../models/models.dart';

/// Servicio para gestión de descarga de mapas
class StorageService {
  static const MethodChannel _channel =
      MethodChannel('organic_maps_flutter/storage');

  /// Obtiene el árbol de países
  static Future<List<Country>> getCountriesTree() async {
    final results = await _channel.invokeMethod<List>('getCountriesTree');

    if (results == null) return [];

    return results
        .map((r) => Country.fromMap(r.cast<String, dynamic>()))
        .toList();
  }

  /// Descarga un país
  static Future<void> downloadCountry(String countryId) async {
    await _channel.invokeMethod('downloadCountry', {
      'countryId': countryId,
    });
  }

  /// Elimina un país
  static Future<void> deleteCountry(String countryId) async {
    await _channel.invokeMethod('deleteCountry', {
      'countryId': countryId,
    });
  }
}
