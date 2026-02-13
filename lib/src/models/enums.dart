/// Tipo de router para cálculo de rutas.
enum RouterType {
  /// Ruta para vehículo motorizado.
  vehicle,

  /// Ruta para peatón.
  pedestrian,

  /// Ruta para bicicleta.
  bicycle,

  /// Ruta con transporte público.
  transit,
}

/// Modo de zoom.
enum ZoomMode {
  /// Acercar el mapa.
  zoomIn,

  /// Alejar el mapa.
  zoomOut,
}

/// Estilo visual del mapa.
enum MapStyle {
  /// Estilo claro por defecto.
  defaultLight,

  /// Estilo oscuro por defecto.
  defaultDark,

  /// Estilo claro para vehículo (navegación).
  vehicleLight,

  /// Estilo oscuro para vehículo (navegación).
  vehicleDark,

  /// Estilo claro para exteriores (senderismo).
  outdoorsLight,

  /// Estilo oscuro para exteriores.
  outdoorsDark,
}
