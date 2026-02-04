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
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import app.organicmaps.sdk.downloader.CountryItem
import app.organicmaps.sdk.downloader.MapManager

/**
 * Foreground service for map downloads.
 * Required for Android to allow background network operations.
 */
class DownloaderService : Service(), MapManager.StorageCallback {
  
  companion object {
    private const val TAG = "DownloaderService"
    private const val NOTIFICATION_ID = 12345
    private const val CHANNEL_ID = "map_downloads"
    
    fun startForegroundService(context: Context) {
      android.util.Log.i(TAG, "Starting foreground service")
      ContextCompat.startForegroundService(context, Intent(context, DownloaderService::class.java))
    }
  }
  
  private var subscriptionSlot: Int = 0
  
  override fun onCreate() {
    super.onCreate()
    android.util.Log.i(TAG, "onCreate")
    
    // Subscribe to download events
    subscriptionSlot = MapManager.nativeSubscribe(this)
    android.util.Log.i(TAG, "Subscribed to MapManager with slot: $subscriptionSlot")
  }
  
  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    android.util.Log.i(TAG, "onStartCommand - Downloading: ${MapManager.nativeIsDownloading()}")
    
    val notification = buildNotification()
    
    try {
      val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
      } else {
        0
      }
      ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, type)
      android.util.Log.i(TAG, "Service promoted to foreground")
    } catch (e: Exception) {
      android.util.Log.e(TAG, "Failed to promote service to foreground", e)
    }
    
    return START_NOT_STICKY
  }
  
  override fun onBind(intent: Intent?): IBinder? = null
  
  override fun onStatusChanged(data: MutableList<MapManager.StorageCallbackData>) {
    val isDownloading = MapManager.nativeIsDownloading()
    val hasFailed = data.any { it.isLeafNode && it.newStatus == CountryItem.STATUS_FAILED }
    
    android.util.Log.i(TAG, "onStatusChanged - Downloading: $isDownloading, Failed: $hasFailed")
    
    if (!isDownloading) {
      if (hasFailed) {
        // Detach service from notification to keep it after service stops
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
    android.util.Log.d(TAG, "onProgress - $countryId: $progress% ($bytesDownloaded / $bytesTotal)")
    
    // Update notification with progress
    val notification = buildNotification(countryId, progress)
    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    notificationManager.notify(NOTIFICATION_ID, notification)
  }
  
  override fun onDestroy() {
    super.onDestroy()
    android.util.Log.i(TAG, "onDestroy")
    
    if (subscriptionSlot != 0) {
      MapManager.nativeUnsubscribe(subscriptionSlot)
      subscriptionSlot = 0
    }
  }
  
  private fun buildNotification(countryName: String? = null, progress: Int = 0): Notification {
    createNotificationChannel()
    
    val title = if (countryName != null) {
      "Downloading $countryName"
    } else {
      "Downloading maps"
    }
    
    val text = if (progress > 0) {
      "$progress%"
    } else {
      "Preparing download..."
    }
    
    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle(title)
      .setContentText(text)
      .setSmallIcon(android.R.drawable.stat_sys_download)
      .setProgress(100, progress, progress == 0)
      .setOngoing(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
  }
  
  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Map Downloads",
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        description = "Shows progress of map downloads"
      }
      
      val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      notificationManager.createNotificationChannel(channel)
    }
  }
}
