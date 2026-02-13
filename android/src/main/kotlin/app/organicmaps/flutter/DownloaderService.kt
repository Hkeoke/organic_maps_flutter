package app.organicmaps.flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import app.organicmaps.sdk.downloader.CountryItem
import app.organicmaps.sdk.downloader.MapManager

/**
 * Foreground service para descargas de mapas offline.
 *
 * Requerido por Android para operaciones de red en segundo plano.
 * Muestra una notificación persistente con el progreso de descarga
 * y se auto-detiene cuando la descarga finaliza.
 */
class DownloaderService : Service(), MapManager.StorageCallback {

  companion object {
    private const val TAG = "DownloaderService"
    private const val NOTIFICATION_ID = 12345
    private const val CHANNEL_ID = "map_downloads"

    fun startForegroundService(context: Context) {
      ContextCompat.startForegroundService(
        context, Intent(context, DownloaderService::class.java)
      )
    }
  }

  private var subscriptionSlot: Int = 0

  override fun onCreate() {
    super.onCreate()
    subscriptionSlot = MapManager.nativeSubscribe(this)
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    val notification = buildNotification()

    try {
      val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
      } else {
        0
      }
      ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
    } catch (e: Exception) {
      Log.e(TAG, "Failed to promote to foreground", e)
    }

    return START_NOT_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStatusChanged(data: MutableList<MapManager.StorageCallbackData>) {
    val isDownloading = MapManager.nativeIsDownloading()
    val hasFailed = data.any { it.isLeafNode && it.newStatus == CountryItem.STATUS_FAILED }

    if (!isDownloading) {
      if (hasFailed) {
        // Mantener notificación visible tras error
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
          stopForeground(STOP_FOREGROUND_DETACH)
        } else {
          @Suppress("DEPRECATION")
          stopForeground(false)
        }
      }
      stopSelf()
    }
  }

  override fun onProgress(countryId: String, bytesDownloaded: Long, bytesTotal: Long) {
    val progress = if (bytesTotal > 0) (bytesDownloaded * 100 / bytesTotal).toInt() else 0
    val notification = buildNotification(countryId, progress)
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    nm.notify(NOTIFICATION_ID, notification)
  }

  override fun onDestroy() {
    super.onDestroy()
    if (subscriptionSlot != 0) {
      MapManager.nativeUnsubscribe(subscriptionSlot)
      subscriptionSlot = 0
    }
  }

  private fun buildNotification(countryName: String? = null, progress: Int = 0): Notification {
    ensureNotificationChannel()

    val title = countryName?.let { "Descargando $it" } ?: "Descargando mapas"
    val text = if (progress > 0) "$progress%" else "Preparando descarga..."

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle(title)
      .setContentText(text)
      .setSmallIcon(android.R.drawable.stat_sys_download)
      .setProgress(100, progress, progress == 0)
      .setOngoing(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
  }

  private fun ensureNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Descargas de mapas",
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        description = "Progreso de descarga de mapas offline"
      }

      (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
        .createNotificationChannel(channel)
    }
  }
}
