import Flutter
import UIKit

public class OrganicMapsFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "organic_maps_flutter", binaryMessenger: registrar.messenger())
    let instance = OrganicMapsFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    
    // Registrar Platform View que usa MapView del SDK
    let factory = OrganicMapViewFactory(messenger: registrar.messenger())
    registrar.register(factory, withId: "organic_maps_flutter/map_view")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
      
    case "getDataVersion":
      // El SDK de iOS tiene métodos similares en Framework
      result(Date().timeIntervalSince1970)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
