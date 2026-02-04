import Flutter
import UIKit

/**
 * Platform View que integra el mapa de Organic Maps en Flutter para iOS
 * 
 * NOTA: El SDK de iOS (CoreApi) no incluye una vista de mapa lista para usar como Android.
 * La vista EAGLView está en la app principal (iphone/Maps/Classes/EAGLView).
 * 
 * Para un plugin completo, necesitarías:
 * 1. Copiar EAGLView y sus dependencias al plugin
 * 2. O crear un framework que incluya toda la UI
 * 3. O usar el CoreApi solo para APIs (sin renderizado)
 * 
 * Por ahora, esta implementación usa CoreApi para las APIs y muestra un placeholder
 * para el renderizado visual.
 */
class OrganicMapView: NSObject, FlutterPlatformView {
  private var _view: UIView
  private var methodChannel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    binaryMessenger messenger: FlutterBinaryMessenger
  ) {
    // Crear vista placeholder
    _view = UIView(frame: frame)
    _view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1.0)
    
    // Agregar label informativo
    let label = UILabel(frame: frame)
    label.text = "Organic Maps\n(iOS rendering requires EAGLView)"
    label.textAlignment = .center
    label.numberOfLines = 0
    label.textColor = .gray
    _view.addSubview(label)
    
    methodChannel = FlutterMethodChannel(
      name: "organic_maps_flutter/map_\(viewId)",
      binaryMessenger: messenger
    )
    
    super.init()
    
    methodChannel.setMethodCallHandler(handle)
  }

  func view() -> UIView {
    return _view
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    // Usar CoreApi para las APIs
    switch call.method {
    case "setCenter":
      guard let args = call.arguments as? [String: Any],
            let lat = args["latitude"] as? Double,
            let lon = args["longitude"] as? Double,
            let zoom = args["zoom"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      
      // Usar Framework del CoreApi
      // Framework.setViewportCenter(lat, lon, zoom)
      result(nil)
      
    case "zoom":
      guard let args = call.arguments as? [String: Any],
            let mode = args["mode"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      
      // Framework.scale(mode == "in" ? .in : .out)
      result(nil)
      
    case "getCenter":
      // let center = Framework.getScreenRectCenter()
      result([
        "latitude": 0.0,
        "longitude": 0.0
      ])
      
    case "set3dMode":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      
      // Framework.set3dMode(enabled)
      result(nil)
      
    case "setTrafficEnabled":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        return
      }
      
      // MWMMapOverlayManager.setTrafficEnabled(enabled)
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
