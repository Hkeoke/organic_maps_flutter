/// Excepción base para errores de Organic Maps
class OrganicMapsException implements Exception {
  final String message;
  final dynamic originalError;

  OrganicMapsException(this.message, [this.originalError]);

  @override
  String toString() => 'OrganicMapsException: $message';
}

/// Excepción cuando el framework no está inicializado
class NotInitializedException extends OrganicMapsException {
  NotInitializedException()
      : super('El framework de Organic Maps no está inicializado');
}

/// Excepción de búsqueda
class SearchException extends OrganicMapsException {
  SearchException(super.message, [super.originalError]);
}

/// Excepción de routing
class RoutingException extends OrganicMapsException {
  RoutingException(super.message, [super.originalError]);
}

/// Excepción de descarga
class DownloadException extends OrganicMapsException {
  DownloadException(super.message, [super.originalError]);
}
