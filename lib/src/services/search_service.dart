import 'package:flutter/services.dart';
import '../models/models.dart';

/// Servicio para búsqueda en el mapa
class SearchService {
  static const MethodChannel _channel =
      MethodChannel('organic_maps_flutter/search');

  /// Busca en todo el mapa
  static Future<List<SearchResult>> searchEverywhere(String query) async {
    final results = await _channel.invokeMethod<List>('searchEverywhere', {
      'query': query,
    });

    if (results == null) return [];

    return results
        .map((r) => SearchResult.fromMap(r.cast<String, dynamic>()))
        .toList();
  }

  /// Cancela todas las búsquedas
  static Future<void> cancelAllSearches() async {
    await _channel.invokeMethod('cancelAllSearches');
  }
}
