import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'organic_maps_flutter_method_channel.dart';

abstract class OrganicMapsFlutterPlatform extends PlatformInterface {
  /// Constructs a OrganicMapsFlutterPlatform.
  OrganicMapsFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static OrganicMapsFlutterPlatform _instance = MethodChannelOrganicMapsFlutter();

  /// The default instance of [OrganicMapsFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelOrganicMapsFlutter].
  static OrganicMapsFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [OrganicMapsFlutterPlatform] when
  /// they register themselves.
  static set instance(OrganicMapsFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
