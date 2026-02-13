import '../models/models.dart';
import '../organic_map_controller.dart';

/// Servicio de alto nivel para gestión de bookmarks.
///
/// Ejemplo:
/// ```dart
/// final bookmarks = BookmarkService(controller);
///
/// final id = await bookmarks.create(
///   name: 'Mi lugar favorito',
///   position: LatLng(40.4168, -3.7038),
/// );
///
/// final allBookmarks = await bookmarks.getAll();
/// ```
class BookmarkService {
  final OrganicMapController _controller;

  BookmarkService(this._controller);

  /// Crea un nuevo bookmark.
  Future<String> create({
    required String name,
    required LatLng position,
    String? description,
    String? categoryId,
  }) async {
    return _controller.createBookmark(
      latitude: position.latitude,
      longitude: position.longitude,
      name: name,
      description: description,
      categoryId: categoryId,
    );
  }

  /// Obtiene todos los bookmarks.
  Future<List<Bookmark>> getAll() async {
    return _controller.getBookmarks();
  }

  /// Elimina un bookmark por su ID.
  Future<void> delete(String bookmarkId) async {
    await _controller.deleteBookmark(bookmarkId);
  }

  /// Muestra un bookmark en el mapa.
  Future<void> show(String bookmarkId) async {
    await _controller.showBookmark(bookmarkId);
  }
}
