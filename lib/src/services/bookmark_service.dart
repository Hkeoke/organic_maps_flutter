import 'package:flutter/services.dart';
import '../models/models.dart';

/// Servicio para gestión de bookmarks
class BookmarkService {
  static const MethodChannel _channel =
      MethodChannel('organic_maps_flutter/bookmarks');

  /// Crea un nuevo bookmark
  static Future<String> createBookmark(Bookmark bookmark) async {
    final id = await _channel.invokeMethod<String>('createBookmark', {
      'name': bookmark.name,
      'description': bookmark.description,
      'latitude': bookmark.position.latitude,
      'longitude': bookmark.position.longitude,
      'categoryId': bookmark.categoryId,
    });

    if (id == null) {
      throw OrganicMapsException('No se pudo crear el bookmark');
    }

    return id;
  }

  /// Obtiene todos los bookmarks
  static Future<List<Bookmark>> getAllBookmarks() async {
    final results = await _channel.invokeMethod<List>('getAllBookmarks');

    if (results == null) return [];

    return results
        .map((r) => Bookmark.fromMap(r.cast<String, dynamic>()))
        .toList();
  }
}
