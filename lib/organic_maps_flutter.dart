/// Organic Maps Flutter Plugin.
///
/// Plugin de mapas offline basado en Organic Maps para Flutter.
/// Proporciona mapas vectoriales sin conexión, navegación, búsqueda y más.
///
/// ## Uso básico
///
/// ```dart
/// import 'package:organic_maps_flutter/organic_maps_flutter.dart';
///
/// // En tu widget:
/// OrganicMapView(
///   onMapCreated: (controller) {
///     controller.setCenter(
///       latitude: 40.4168,
///       longitude: -3.7038,
///       zoom: 12,
///     );
///   },
/// )
/// ```
library;

export 'src/organic_maps_flutter.dart';
export 'src/organic_map_view.dart';
export 'src/organic_map_controller.dart';
export 'src/models/models.dart';
export 'src/services/services.dart';
