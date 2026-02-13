/// Modos de posición del usuario en el mapa.
///
/// Estos modos corresponden a los estados del SDK nativo de Organic Maps
/// y determinan cómo el mapa reacciona a la ubicación del usuario.
enum MyPositionMode {
  /// Sin posición disponible ni seguimiento.
  notFollowNoPosition(1),

  /// Posición visible pero sin seguimiento automático.
  notFollow(2),

  /// Siguiendo la ubicación del usuario (el mapa se centra automáticamente).
  follow(3),

  /// Siguiendo y rotando según la orientación del dispositivo.
  /// Este es el modo de navegación activa.
  followAndRotate(4);

  final int value;
  const MyPositionMode(this.value);

  /// Crea desde el valor entero del SDK nativo.
  static MyPositionMode fromValue(int value) {
    return MyPositionMode.values.firstWhere(
      (m) => m.value == value,
      orElse: () => MyPositionMode.notFollowNoPosition,
    );
  }

  /// Indica si el modo tiene ubicación activa.
  bool get hasPosition =>
      this != MyPositionMode.notFollowNoPosition;

  /// Indica si el modo está siguiendo la ubicación.
  bool get isFollowing =>
      this == MyPositionMode.follow ||
      this == MyPositionMode.followAndRotate;

  /// Indica si es el modo de navegación (seguimiento + rotación).
  bool get isNavigationMode =>
      this == MyPositionMode.followAndRotate;
}
