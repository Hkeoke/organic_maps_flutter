package app.organicmaps.flutter

import android.content.Context
import app.organicmaps.sdk.OrganicMaps
import app.organicmaps.sdk.location.BaseLocationProvider
import app.organicmaps.sdk.location.LocationProviderFactory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class OrganicMapsFlutterPlugin: FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    android.util.Log.i("OrganicMapsFlutter", "=== Plugin onAttachedToEngine START ===")
    
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "organic_maps_flutter")
    channel.setMethodCallHandler(this)
    
    // Registrar Platform View con Hybrid Composition habilitado
    // Esto permite que los widgets de Flutter se rendericen encima del mapa
    binding.platformViewRegistry.registerViewFactory(
      "organic_maps_flutter/map_view",
      OrganicMapViewFactory(binding.binaryMessenger, context)
    )
    
    android.util.Log.i("OrganicMapsFlutter", "=== Plugin onAttachedToEngine COMPLETE ===")
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      
      "getDataVersion" -> {
        try {
          val version = app.organicmaps.sdk.Framework.getDataVersion()
          result.success(version.time)
        } catch (e: Exception) {
          result.error("ERROR", e.message, null)
        }
      }
      
      else -> result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
