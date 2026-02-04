package app.organicmaps.flutter

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class OrganicMapViewFactory(
  private val messenger: BinaryMessenger,
  private val context: Context
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    val creationParams = args as? Map<String, Any>
    return OrganicMapView(this.context, messenger, viewId, creationParams)
  }
}
