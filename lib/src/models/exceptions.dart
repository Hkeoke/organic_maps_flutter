/// Excepción base para errores de Organic Maps.
class OrganicMapsException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const OrganicMapsException(this.message, [this.originalError, this.stackTrace]);

  @override
  String toString() => 'OrganicMapsException: $message';
}

/// Excepción cuando el framework no está inicializado.
class NotInitializedException extends OrganicMapsException {
  const NotInitializedException()
      : super('El framework de Organic Maps no está inicializado');
}

/// Excepción de búsqueda.
class SearchException extends OrganicMapsException {
  const SearchException(super.message, [super.originalError, super.stackTrace]);
}

/// Excepción de routing/navegación.
class RoutingException extends OrganicMapsException {
  const RoutingException(super.message, [super.originalError, super.stackTrace]);
}

/// Excepción de descarga de mapas.
class DownloadException extends OrganicMapsException {
  const DownloadException(super.message, [super.originalError, super.stackTrace]);
}

/// Excepción de grabación de track.
class TrackRecordingException extends OrganicMapsException {
  const TrackRecordingException(super.message, [super.originalError, super.stackTrace]);
}

/// Excepción de permisos de ubicación.
class LocationPermissionException extends OrganicMapsException {
  const LocationPermissionException([super.message = 'Permisos de ubicación no concedidos']);
}

/// Excepción de conexión de red.
class NetworkException extends OrganicMapsException {
  const NetworkException([super.message = 'Sin conexión a internet']);
}

/// Excepción de espacio insuficiente.
class InsufficientStorageException extends OrganicMapsException {
  const InsufficientStorageException([super.message = 'Espacio insuficiente para la descarga']);
}
