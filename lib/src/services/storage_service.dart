import 'dart:async';
import '../models/models.dart';
import '../organic_map_controller.dart';

/// Servicio de alto nivel para gestión de descargas de mapas.
///
/// Ejemplo:
/// ```dart
/// final storage = StorageService(controller);
///
/// // Obtener países disponibles.
/// final countries = await storage.getCountries();
///
/// // Descargar un país.
/// await storage.downloadCountry('Spain');
///
/// // Escuchar progreso de descarga.
/// storage.onDownloadProgress.listen((progress) {
///   print('${progress.countryId}: ${progress.progress}%');
/// });
/// ```
class StorageService {
  final OrganicMapController _controller;

  StorageService(this._controller);

  /// Obtiene la lista de países/regiones disponibles.
  Future<List<Country>> getCountries() async {
    return _controller.getCountries();
  }

  /// Obtiene solo los países descargados.
  Future<List<Country>> getDownloadedCountries() async {
    final countries = await getCountries();
    return countries.where((c) => c.isDownloaded).toList();
  }

  /// Obtiene los países con actualizaciones disponibles.
  Future<List<Country>> getUpdatableCountries() async {
    final countries = await getCountries();
    return countries.where((c) => c.hasUpdate).toList();
  }

  /// Descarga un país/región.
  Future<void> downloadCountry(String countryId) async {
    await _controller.downloadCountry(countryId);
  }

  /// Elimina un país descargado.
  Future<void> deleteCountry(String countryId) async {
    await _controller.deleteCountry(countryId);
  }

  /// Cancela la descarga en progreso.
  Future<void> cancelDownload(String countryId) async {
    await _controller.cancelDownload(countryId);
  }

  /// Habilita las descargas con datos móviles.
  Future<void> enableMobileDataDownloads() async {
    await _controller.enableMobileDataDownloads();
  }

  /// Stream de progreso de descarga.
  Stream<DownloadProgress> get onDownloadProgress =>
      _controller.onDownloadProgress;

  /// Stream de cambios de estado de países.
  Stream<List<CountryStatusUpdate>> get onCountriesChanged =>
      _controller.onCountriesChanged;

  /// Stream cuando se requiere confirmación de datos móviles.
  Stream<Map<String, dynamic>> get onMobileDataRequired =>
      _controller.onMobileDataRequired;
}
