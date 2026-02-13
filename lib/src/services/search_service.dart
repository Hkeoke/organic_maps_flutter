import '../models/models.dart';
import '../organic_map_controller.dart';

/// Servicio de alto nivel para búsqueda en el mapa.
///
/// Ejemplo:
/// ```dart
/// final search = SearchService(controller);
/// final results = await search.searchEverywhere('restaurante');
/// for (final result in results) {
///   print('${result.name}: ${result.position}');
/// }
/// ```
class SearchService {
  final OrganicMapController _controller;

  SearchService(this._controller);

  /// Busca en todo el mapa.
  Future<List<SearchResult>> searchEverywhere(String query) async {
    return _controller.searchEverywhere(query);
  }

  /// Busca en el viewport actual.
  Future<List<SearchResult>> searchInViewport(String query) async {
    return _controller.searchInViewport(query);
  }

  /// Cancela la búsqueda actual.
  Future<void> cancel() async {
    await _controller.cancelSearch();
  }
}
