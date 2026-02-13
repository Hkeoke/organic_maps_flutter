package app.organicmaps.flutter

import android.content.Context
import android.util.Log
import app.organicmaps.sdk.Framework
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Plugin principal de Organic Maps para Flutter.
 *
 * Se encarga de:
 * - Registrar el canal de métodos global
 * - Registrar la PlatformView factory para el mapa
 */
class OrganicMapsFlutterPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "organic_maps_flutter")
    channel.setMethodCallHandler(this)

    // Registrar Platform View con Hybrid Composition
    binding.platformViewRegistry.registerViewFactory(
      "organic_maps_flutter/map_view",
      OrganicMapViewFactory(binding.binaryMessenger, context)
    )

    Log.i(TAG, "Plugin attached to engine")
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }

      "getDataVersion" -> {
        try {
          val version = Framework.getDataVersion()
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

  companion object {
    private const val TAG = "OrganicMapsPlugin"
  }
}
