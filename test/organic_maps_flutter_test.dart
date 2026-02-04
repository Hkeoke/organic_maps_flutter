import 'package:flutter_test/flutter_test.dart';
import 'package:organic_maps_flutter/organic_maps_flutter.dart';
import 'package:organic_maps_flutter/organic_maps_flutter_platform_interface.dart';
import 'package:organic_maps_flutter/organic_maps_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockOrganicMapsFlutterPlatform
    with MockPlatformInterfaceMixin
    implements OrganicMapsFlutterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final OrganicMapsFlutterPlatform initialPlatform = OrganicMapsFlutterPlatform.instance;

  test('$MethodChannelOrganicMapsFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelOrganicMapsFlutter>());
  });

  test('getPlatformVersion', () async {
    MockOrganicMapsFlutterPlatform fakePlatform = MockOrganicMapsFlutterPlatform();
    OrganicMapsFlutterPlatform.instance = fakePlatform;

    expect(await OrganicMapsFlutter.getPlatformVersion(), '42');
  });
}
