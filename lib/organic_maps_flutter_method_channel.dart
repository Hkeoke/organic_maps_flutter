import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'organic_maps_flutter_platform_interface.dart';

/// An implementation of [OrganicMapsFlutterPlatform] that uses method channels.
class MethodChannelOrganicMapsFlutter extends OrganicMapsFlutterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('organic_maps_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
