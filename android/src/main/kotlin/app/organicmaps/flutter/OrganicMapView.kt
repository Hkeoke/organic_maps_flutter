package app.organicmaps.flutter

import android.content.Context
import android.location.Location
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView
import app.organicmaps.sdk.MapView as SDKMapView
import app.organicmaps.sdk.Framework
import app.organicmaps.sdk.Map as SDKMap
import app.organicmaps.sdk.Router
import app.organicmaps.sdk.MapStyle
import app.organicmaps.sdk.bookmarks.data.BookmarkManager
import app.organicmaps.sdk.bookmarks.data.MapObject
import app.organicmaps.sdk.maplayer.traffic.TrafficManager
import app.organicmaps.sdk.maplayer.subway.SubwayManager
import app.organicmaps.sdk.maplayer.isolines.IsolinesManager
import app.organicmaps.sdk.routing.RoutingController
import app.organicmaps.sdk.routing.RouteMarkType
import app.organicmaps.sdk.search.SearchEngine
import app.organicmaps.sdk.search.SearchListener
import app.organicmaps.sdk.search.SearchResult
import app.organicmaps.sdk.location.LocationHelper
import app.organicmaps.sdk.location.LocationListener
import app.organicmaps.sdk.location.LocationState
import app.organicmaps.sdk.location.TrackRecorder
import app.organicmaps.sdk.editor.Editor
import app.organicmaps.sdk.editor.data.FeatureCategory
import app.organicmaps.sdk.downloader.MapManager
import app.organicmaps.sdk.downloader.CountryItem
import app.organicmaps.sdk.PlacePageActivationListener
import app.organicmaps.sdk.widget.placepage.PlacePageData

/**
 * Platform View COMPLETA que usa el 100% del SDK de Organic Maps
 */
class OrganicMapView(
  context: Context,
  messenger: BinaryMessenger,
  id: Int,
  creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler, PlacePageActivationListener {
  
  private val containerView: android.widget.FrameLayout = android.widget.FrameLayout(context)
  private val mapView: SDKMapView = SDKMapView(context)
  private lateinit var mapController: app.organicmaps.sdk.MapController
  private val methodChannel: MethodChannel = MethodChannel(messenger, "organic_maps_flutter/map_$id")
  private val context: Context = context
  
  // LocationHelper para GPS
  private var locationHelper: LocationHelper? = null
  
  // Callback para descargas de mapas
  private var storageCallbackSlot: Int = 0
  private val storageCallback = object : MapManager.StorageCallback {
    override fun onStatusChanged(data: MutableList<MapManager.StorageCallbackData>) {
      android.util.Log.i("OrganicMapView", "=== onStatusChanged called with ${data.size} items ===")
      
      val updates = data.map { item ->
        android.util.Log.i("OrganicMapView", "Country: ${item.countryId}, newStatus: ${item.newStatus}, errorCode: ${item.errorCode}, isLeaf: ${item.isLeafNode}")
        
        // FIX: Removed dependency on CountryItem which is not available
        // Passing raw status integer to Flutter or simplified string
        val statusString = when (item.newStatus) {
            1 -> "downloaded" // STATUS_DONE
            2, 3 -> "downloading" // STATUS_PROGRESS, STATUS_APPLYING
            4 -> "downloading" // STATUS_ENQUEUED
            5 -> "updateAvailable" // STATUS_UPDATABLE
            6 -> "error" // STATUS_FAILED
            else -> "notDownloaded"
        }
        mapOf(
          "countryId" to item.countryId,
          "status" to statusString
        )
      }
      
      containerView.post {
        methodChannel.invokeMethod("onCountriesChanged", updates)
      }
    }

    override fun onProgress(countryId: String, localSize: Long, remoteSize: Long) {
      val progress = if (remoteSize > 0) (localSize * 100 / remoteSize).toInt() else 0
      android.util.Log.d("OrganicMapView", "Download progress: $countryId - $progress% ($localSize / $remoteSize bytes)")
      
      containerView.post {
        methodChannel.invokeMethod("onCountryProgress", mapOf(
          "countryId" to countryId,
          "progress" to progress
        ))
      }
    }
  }
  
  companion object {
    private var organicMaps: app.organicmaps.sdk.OrganicMaps? = null
    private var initializationStarted = false
    private val initLock = Object()
    
    init {
      try {
        System.loadLibrary("organicmaps")
        android.util.Log.i("OrganicMapView", "Native library loaded")
      } catch (e: Exception) {
        android.util.Log.e("OrganicMapView", "Failed to load native library", e)
      }
    }
  }
  
  init {
    methodChannel.setMethodCallHandler(this)
    android.util.Log.i("OrganicMapView", "OrganicMapView created, starting initialization...")
    
    // Inicializar OrganicMaps si no está inicializado
    synchronized(initLock) {
      if (organicMaps == null && !initializationStarted) {
        initializationStarted = true
        initializeOrganicMaps()
      }
    }
    
    // Esperar a que el Framework esté listo
    waitForFrameworkAndInitialize()
  }
  
  private fun initializeOrganicMaps() {
    // Ejecutar en el main thread porque LocationHelper necesita un Looper
    containerView.post {
      try {
        android.util.Log.i("OrganicMapView", "Creating OrganicMaps instance on main thread...")
        
        // CRITICAL: Initialize ConnectionState BEFORE creating OrganicMaps
        // because nativeInitPlatform will call ConnectionState.getConnectionState()
        app.organicmaps.sdk.util.ConnectionState.INSTANCE.initialize(context)
        android.util.Log.i("OrganicMapView", "ConnectionState initialized")
        
        val locationProviderFactory = object : app.organicmaps.sdk.location.LocationProviderFactory {
          override fun isGoogleLocationAvailable(context: android.content.Context): Boolean = false
          override fun getProvider(context: android.content.Context, listener: app.organicmaps.sdk.location.BaseLocationProvider.Listener): app.organicmaps.sdk.location.BaseLocationProvider {
            // Usar AndroidNativeProvider en lugar de null
            android.util.Log.i("OrganicMapView", "Creating AndroidNativeProvider")
            return app.organicmaps.sdk.location.AndroidNativeProvider(context, listener)
          }
        }
        
        organicMaps = app.organicmaps.sdk.OrganicMaps(
          context,
          "flutter",
          context.packageName,
          1,
          "1.0.0",
          "${context.packageName}.provider",
          locationProviderFactory
        )
        
        android.util.Log.i("OrganicMapView", "OrganicMaps instance created, calling init()...")
        
        organicMaps?.init(Runnable {
          android.util.Log.i("OrganicMapView", "=== FRAMEWORK READY ===")
        })
        
        android.util.Log.i("OrganicMapView", "init() called")
      } catch (e: Exception) {
        android.util.Log.e("OrganicMapView", "Error initializing OrganicMaps", e)
        e.printStackTrace()
      }
    }
  }
  
  private fun waitForFrameworkAndInitialize() {
    if (organicMaps != null && organicMaps!!.arePlatformAndCoreInitialized()) {
      // Framework está listo
      initializeMapView(organicMaps!!)
    } else {
      // Esperar 100ms y reintentar
      android.util.Log.i("OrganicMapView", "Waiting for Framework...")
      containerView.postDelayed({
        waitForFrameworkAndInitialize()
      }, 100)
    }
  }
  
  private fun initializeMapView(organicMaps: app.organicmaps.sdk.OrganicMaps) {
    android.util.Log.i("OrganicMapView", "Framework is ready, initializing MapView")
    
    locationHelper = organicMaps.locationHelper
    android.util.Log.i("OrganicMapView", "LocationHelper obtained: ${locationHelper != null}")
    
    // Inicializar RoutingController
    RoutingController.get().initialize(organicMaps.locationHelper)
    android.util.Log.i("OrganicMapView", "RoutingController initialized")
    
    // Adjuntar un Container al RoutingController para que funcione correctamente
    RoutingController.get().attach(object : RoutingController.Container {
      override fun showRoutePlan(show: Boolean, completionListener: Runnable?) {
        android.util.Log.i("OrganicMapView", "showRoutePlan: $show")
        completionListener?.run()
      }
      
      override fun showNavigation(show: Boolean) {
        android.util.Log.i("OrganicMapView", "showNavigation: $show")
      }
      
      override fun updateMenu() {
        android.util.Log.d("OrganicMapView", "updateMenu")
      }
      
      override fun onNavigationStarted() {
        android.util.Log.i("OrganicMapView", "")
        android.util.Log.i("OrganicMapView", "🎉 ========== ON NAVIGATION STARTED CALLBACK ==========")
        android.util.Log.i("OrganicMapView", "✅ Navigation started callback triggered!")
        
        // Log final state
        android.util.Log.i("OrganicMapView", "🗺️ Final routing state:")
        android.util.Log.i("OrganicMapView", "  - isPlanning: ${RoutingController.get().isPlanning}")
        android.util.Log.i("OrganicMapView", "  - isNavigating: ${RoutingController.get().isNavigating}")
        android.util.Log.i("OrganicMapView", "  - isBuilt: ${RoutingController.get().isBuilt}")
        android.util.Log.i("OrganicMapView", "  - myPositionMode: ${LocationState.getMode()} (${LocationState.nameOf(LocationState.getMode())})")
        android.util.Log.i("OrganicMapView", "  - locationHelper.isActive: ${locationHelper?.isActive}")
        
        // Check 3D mode
        val params3d = Framework.Params3dMode()
        Framework.nativeGet3dMode(params3d)
        android.util.Log.i("OrganicMapView", "🎬 3D mode state:")
        android.util.Log.i("OrganicMapView", "  - enabled: ${params3d.enabled}")
        android.util.Log.i("OrganicMapView", "  - buildings: ${params3d.buildings}")
        
        android.util.Log.i("OrganicMapView", "")
        android.util.Log.i("OrganicMapView", "✅ NAVIGATION IS NOW ACTIVE!")
        android.util.Log.i("OrganicMapView", "✅ Motor should be following route automatically")
        android.util.Log.i("OrganicMapView", "======================================================")
        android.util.Log.i("OrganicMapView", "")
        
        containerView.post {
          methodChannel.invokeMethod("onNavigationStarted", null)
        }
      }
      
      override fun onNavigationCancelled() {
        android.util.Log.i("OrganicMapView", "Navigation cancelled")
        
        // Deshabilitar modo 3D cuando se cancela la navegación
        try {
          Framework.nativeSet3dMode(false, false)
          android.util.Log.i("OrganicMapView", "3D mode disabled")
        } catch (e: Exception) {
          android.util.Log.e("OrganicMapView", "Error disabling 3D mode", e)
        }
        
        containerView.post {
          methodChannel.invokeMethod("onNavigationCancelled", null)
        }
      }
      
      override fun onBuiltRoute() {
        android.util.Log.i("OrganicMapView", "")
        android.util.Log.i("OrganicMapView", "🎉 ========== ON BUILT ROUTE CALLBACK ==========")
        android.util.Log.i("OrganicMapView", "✅ Route built successfully!")
        
        // Log routing state BEFORE starting navigation
        android.util.Log.i("OrganicMapView", "🗺️ Routing state BEFORE start():")
        android.util.Log.i("OrganicMapView", "  - isPlanning: ${RoutingController.get().isPlanning}")
        android.util.Log.i("OrganicMapView", "  - isNavigating: ${RoutingController.get().isNavigating}")
        android.util.Log.i("OrganicMapView", "  - isBuilt: ${RoutingController.get().isBuilt}")
        android.util.Log.i("OrganicMapView", "  - buildState: ${RoutingController.get().buildState}")
        
        // Log location state
        val location = locationHelper?.savedLocation
        android.util.Log.i("OrganicMapView", "📍 Location state:")
        android.util.Log.i("OrganicMapView", "  - hasLocation: ${location != null}")
        android.util.Log.i("OrganicMapView", "  - locationHelper.isActive: ${locationHelper?.isActive}")
        android.util.Log.i("OrganicMapView", "  - myPositionMode BEFORE: ${LocationState.getMode()} (${LocationState.nameOf(LocationState.getMode())})")
        
        // Get route info
        val routeInfo = RoutingController.get().cachedRoutingInfo
        var distanceStr = "0 m"
        var timeSeconds = 0
        
        if (routeInfo != null) {
          android.util.Log.i("OrganicMapView", "📊 Route info:")
          android.util.Log.i("OrganicMapView", "  - distToTarget: ${routeInfo.distToTarget?.mDistanceStr}")
          android.util.Log.i("OrganicMapView", "  - totalTimeInSeconds: ${routeInfo.totalTimeInSeconds}")
          android.util.Log.i("OrganicMapView", "  - distToTurn: ${routeInfo.distToTurn?.mDistanceStr}")
          android.util.Log.i("OrganicMapView", "  - nextStreet: ${routeInfo.nextStreet}")
          
          distanceStr = routeInfo.distToTarget?.mDistanceStr ?: "0 m"
          timeSeconds = routeInfo.totalTimeInSeconds
        } else {
          android.util.Log.w("OrganicMapView", "⚠️ No cached routing info available")
        }

        // Enviar información de la ruta a Flutter
        containerView.post {
            methodChannel.invokeMethod("onRouteBuilt", mapOf(
                "totalDistance" to distanceStr,
                "totalTime" to timeSeconds
            ))
        }
        
        // NOTA: No iniciamos la navegación automáticamente.
        // Esperamos a que el usuario presione el botón "Empezar" en la UI de Flutter.
        // Cuando eso ocurra, Flutter llamará a 'followRoute', que ejecutará RoutingController.get().start()
      }
      
      override fun onCommonBuildError(lastResultCode: Int, lastMissingMaps: Array<out String>) {
        android.util.Log.e("OrganicMapView", "Route build error: $lastResultCode, missing maps: ${lastMissingMaps.joinToString()}")
      }
      
      override fun updateBuildProgress(progress: Int, router: Router) {
        android.util.Log.d("OrganicMapView", "Route build progress: $progress%")
      }
    })
    android.util.Log.i("OrganicMapView", "RoutingController Container attached")
    
    // Crear MapController que configura correctamente el Map con LocationHelper
    mapController = app.organicmaps.sdk.MapController(
      mapView,
      organicMaps.locationHelper,
      object : app.organicmaps.sdk.MapRenderingListener {
        override fun onRenderingCreated() {
          android.util.Log.i("OrganicMapView", "=== onRenderingCreated CALLED ===")
          // Notificar a Flutter que el mapa está listo
          methodChannel.invokeMethod("onMapReady", null)
          
          // Log location permission status
          val hasPermission = app.organicmaps.sdk.util.LocationUtils.checkLocationPermission(context)
          android.util.Log.i("OrganicMapView", "Has location permission: $hasPermission")
          android.util.Log.i("OrganicMapView", "Current location mode: ${LocationState.getMode()} (${LocationState.nameOf(LocationState.getMode())})")
          android.util.Log.i("OrganicMapView", "LocationHelper isActive: ${locationHelper?.isActive}")
          
          // NOTE: We don't call resumeLocationInForeground() here because:
          // 1. The initial mode is NOT_FOLLOW_NO_POSITION (mode 1)
          // 2. resumeLocationInForeground() refuses to start if mode is NOT_FOLLOW_NO_POSITION
          // 3. Location will start automatically when user presses the location button
          //    which triggers onMyPositionModeChanged() -> restartWithNewMode() -> start()
        }
        override fun onRenderingRestored() {
          android.util.Log.i("OrganicMapView", "=== onRenderingRestored CALLED ===")
        }
      },
      null, // callbackUnsupported
      false // launchByDeepLink
    )
    
    android.util.Log.i("OrganicMapView", "MapController created, calling lifecycle methods...")
    
    // Configurar listener de tap en el mapa usando GestureDetector
    val gestureDetector = android.view.GestureDetector(context, object : android.view.GestureDetector.SimpleOnGestureListener() {
      override fun onSingleTapConfirmed(e: android.view.MotionEvent): Boolean {
        android.util.Log.i("OrganicMapView", "👆 onSingleTapConfirmed at x=${e.x}, y=${e.y}")
        
        // Delegar al motor para que procese el tap (selección de objeto o punto)
        SDKMap.onClick(e.x, e.y)
        
        return true
      }
    })
    
    // Registrar el listener de selección de objetos
    Framework.nativePlacePageActivationListener(this)

    mapView.setOnTouchListener { _, event ->
      android.util.Log.d("OrganicMapView", "👆 Touch event: action=${event.action}, x=${event.x}, y=${event.y}")
      gestureDetector.onTouchEvent(event)
      false // No consumir el evento para que el mapa siga funcionando
    }
    
    // Llamar los métodos del ciclo de vida manualmente
    try {
      val dummyLifecycleOwner = object : androidx.lifecycle.LifecycleOwner {
        override val lifecycle: androidx.lifecycle.Lifecycle
          get() = androidx.lifecycle.LifecycleRegistry(this).apply {
            currentState = androidx.lifecycle.Lifecycle.State.RESUMED
          }
      }
      
      mapController.onStart(dummyLifecycleOwner)
      android.util.Log.i("OrganicMapView", "onStart called")
      
      mapController.onResume(dummyLifecycleOwner)
      android.util.Log.i("OrganicMapView", "onResume called")
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "Error calling lifecycle methods", e)
      e.printStackTrace()
    }
    
    android.util.Log.i("OrganicMapView", "MapController created with LocationHelper")
    
    // Configurar listener de cambio de modo de ubicación
    LocationState.nativeSetListener(object : LocationState.ModeChangeListener {
      override fun onMyPositionModeChanged(newMode: Int) {
        android.util.Log.i("OrganicMapView", "")
        android.util.Log.i("OrganicMapView", "📍 ========== POSITION MODE CHANGED ==========")
        android.util.Log.i("OrganicMapView", "📍 Position mode changed to: $newMode (${LocationState.nameOf(newMode)})")
        
        // Log detailed mode information
        when (newMode) {
          LocationState.NOT_FOLLOW_NO_POSITION -> {
            android.util.Log.i("OrganicMapView", "  Mode: NOT_FOLLOW_NO_POSITION (1) - No location, no following")
          }
          LocationState.NOT_FOLLOW -> {
            android.util.Log.i("OrganicMapView", "  Mode: NOT_FOLLOW (2) - Has location but not following")
          }
          LocationState.FOLLOW -> {
            android.util.Log.i("OrganicMapView", "  Mode: FOLLOW (3) - Following user location (map moves)")
          }
          LocationState.FOLLOW_AND_ROTATE -> {
            android.util.Log.i("OrganicMapView", "  Mode: FOLLOW_AND_ROTATE (4) - NAVIGATION MODE (map rotates with heading)")
            android.util.Log.i("OrganicMapView", "  ✅ THIS IS THE NAVIGATION MODE!")
          }
        }
        
        // Log routing state
        android.util.Log.i("OrganicMapView", "🗺️ Current routing state:")
        android.util.Log.i("OrganicMapView", "  - isNavigating: ${RoutingController.get().isNavigating}")
        android.util.Log.i("OrganicMapView", "  - isBuilt: ${RoutingController.get().isBuilt}")
        android.util.Log.i("OrganicMapView", "  - locationHelper.isActive: ${locationHelper?.isActive}")
        
        // Check if location was disabled by the user
        if (LocationState.getMode() == LocationState.NOT_FOLLOW_NO_POSITION) {
          android.util.Log.i("OrganicMapView", "⚠️ Location updates stopped by user manually")
          if (locationHelper?.isActive == true) {
            locationHelper?.stop()
          }
        } else {
          // Check for location permissions
          if (!app.organicmaps.sdk.util.LocationUtils.checkLocationPermission(context)) {
            android.util.Log.w("OrganicMapView", "❌ Location permissions not granted")
          } else {
            // Restart location with new mode - this will call start() if not active
            try {
              android.util.Log.i("OrganicMapView", "🔄 Calling restartWithNewMode()...")
              locationHelper?.restartWithNewMode()
              android.util.Log.i("OrganicMapView", "✅ LocationHelper restarted, isActive: ${locationHelper?.isActive}")
            } catch (e: Exception) {
              android.util.Log.e("OrganicMapView", "❌ Error calling restartWithNewMode", e)
              e.printStackTrace()
            }
          }
        }
        
        android.util.Log.i("OrganicMapView", "==============================================")
        android.util.Log.i("OrganicMapView", "")
        
        // Notificar a Flutter del cambio de modo
        containerView.post {
          methodChannel.invokeMethod("onMyPositionModeChanged", mapOf(
            "mode" to newMode,
            "modeName" to LocationState.nameOf(newMode)
          ))
        }
      }
    })
    android.util.Log.i("OrganicMapView", "LocationState listener configured")
    
    // Suscribir a eventos de descarga
    storageCallbackSlot = MapManager.nativeSubscribe(storageCallback)
    android.util.Log.i("OrganicMapView", "StorageCallback subscribed with slot: $storageCallbackSlot")
    
    // AHORA sí agregar el mapView al container - esto disparará surfaceCreated
    containerView.addView(mapView, android.widget.FrameLayout.LayoutParams(
      android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
      android.widget.FrameLayout.LayoutParams.MATCH_PARENT
    ))
    android.util.Log.i("OrganicMapView", "MapView added to container")
  }
  
  override fun getView(): View = containerView
  
  override fun dispose() {
    android.util.Log.i("OrganicMapView", "Disposing OrganicMapView")
    methodChannel.setMethodCallHandler(null)
    LocationState.nativeRemoveListener()
    
    // Desadjuntar RoutingController
    RoutingController.get().detach()
    
    if (storageCallbackSlot != 0) {
      MapManager.nativeUnsubscribe(storageCallbackSlot)
      storageCallbackSlot = 0
    }
    
    // Llamar lifecycle methods antes de detener LocationHelper
    try {
      val dummyLifecycleOwner = object : androidx.lifecycle.LifecycleOwner {
        override val lifecycle: androidx.lifecycle.Lifecycle
          get() = androidx.lifecycle.LifecycleRegistry(this).apply {
            currentState = androidx.lifecycle.Lifecycle.State.DESTROYED
          }
      }
      
      mapController.onPause(dummyLifecycleOwner)
      mapController.onStop(dummyLifecycleOwner)
      mapController.onDestroy(dummyLifecycleOwner)
      android.util.Log.i("OrganicMapView", "Lifecycle methods called on dispose")
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "Error calling lifecycle methods on dispose", e)
    }
    
    locationHelper?.stop()
  }
  
  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        // ==================== NAVEGACIÓN DEL MAPA ====================
        "setCenter" -> handleSetCenter(call, result)
        "zoom" -> handleZoom(call, result)
        "showRect" -> handleShowRect(call, result)
        "rotate" -> handleRotate(call, result)
        "zoomToPoint" -> handleZoomToPoint(call, result)
        "getViewport" -> handleGetViewport(call, result)
        
        // ==================== BÚSQUEDA ====================
        "searchEverywhere" -> handleSearchEverywhere(call, result)
        "searchInViewport" -> handleSearchInViewport(call, result)
        "cancelSearch" -> handleCancelSearch(call, result)
        
        // ==================== ROUTING ====================
        "buildRoute" -> handleBuildRoute(call, result)
        "followRoute" -> handleFollowRoute(call, result)
        "stopNavigation" -> handleStopNavigation(call, result)
        "getRouteFollowingInfo" -> handleGetRouteFollowingInfo(call, result)
        
        // ==================== BOOKMARKS ====================
        "createBookmark" -> handleCreateBookmark(call, result)
        "deleteBookmark" -> handleDeleteBookmark(call, result)
        "getBookmarks" -> handleGetBookmarks(call, result)
        "showBookmark" -> handleShowBookmark(call, result)
        
        // ==================== TRACKING GPS ====================
        "startTrackRecording" -> handleStartTrackRecording(call, result)
        "stopTrackRecording" -> handleStopTrackRecording(call, result)
        "saveTrack" -> handleSaveTrack(call, result)
        "isTrackRecording" -> handleIsTrackRecording(call, result)
        
        // ==================== UBICACIÓN ====================
        "updateLocation" -> handleUpdateLocation(call, result)
        "switchMyPositionMode" -> handleSwitchMyPositionMode(call, result)
        "startLocationUpdates" -> handleStartLocationUpdates(call, result)
        "stopLocationUpdates" -> handleStopLocationUpdates(call, result)
        "getMyPosition" -> handleGetMyPosition(call, result)
        
        // ==================== TRÁFICO ====================
        "setTrafficEnabled" -> handleSetTrafficEnabled(call, result)
        "isTrafficEnabled" -> handleIsTrafficEnabled(call, result)
        "setTransitEnabled" -> handleSetTransitEnabled(call, result)
        
        // ==================== CAPAS DEL MAPA ====================
        "setSubwayEnabled" -> handleSetSubwayEnabled(call, result)
        "isSubwayEnabled" -> handleIsSubwayEnabled(call, result)
        "setIsolinesEnabled" -> handleSetIsolinesEnabled(call, result)
        "isIsolinesEnabled" -> handleIsIsolinesEnabled(call, result)
        
        // ==================== TTS / VOZ ====================
        "setTtsEnabled" -> handleSetTtsEnabled(call, result)
        "isTtsEnabled" -> handleIsTtsEnabled(call, result)
        "setTtsVolume" -> handleSetTtsVolume(call, result)
        "getTtsVolume" -> handleGetTtsVolume(call, result)
        
        // ==================== CONFIGURACIÓN ====================
        "set3dMode" -> handleSet3dMode(call, result)
        "setAutoZoom" -> handleSetAutoZoom(call, result)
        "setMapStyle" -> handleSetMapStyle(call, result)
        "getMapStyle" -> handleGetMapStyle(call, result)
        
        // ==================== EDITOR ====================
        "canEditFeature" -> handleCanEditFeature(call, result)
        "startEdit" -> handleStartEdit(call, result)
        "saveEditedFeature" -> handleSaveEditedFeature(call, result)
        "createMapObject" -> handleCreateMapObject(call, result)
        
        // ==================== GESTIÓN DE MAPAS ====================
        "getCountries" -> handleGetCountries(call, result)
        "downloadCountry" -> handleDownloadCountry(call, result)
        "deleteCountry" -> handleDeleteCountry(call, result)
        "cancelDownload" -> handleCancelDownload(call, result)
        "setMobileDataPolicy" -> handleSetMobileDataPolicy(call, result)
        
        else -> result.notImplemented()
      }
    } catch (e: Exception) {
      result.error("ERROR", e.message, e.stackTraceToString())
    }
  }
  
  // ==================== IMPLEMENTACIONES ====================
  
  private fun handleSetCenter(call: MethodCall, result: MethodChannel.Result) {
    val lat = call.argument<Double>("latitude") ?: return result.error("INVALID_ARGS", "latitude required", null)
    val lon = call.argument<Double>("longitude") ?: return result.error("INVALID_ARGS", "longitude required", null)
    val zoom = call.argument<Int>("zoom") ?: 12
    
    Framework.nativeSetViewportCenter(lat, lon, zoom)
    result.success(null)
  }
  
  private fun handleZoom(call: MethodCall, result: MethodChannel.Result) {
    val mode = call.argument<String>("mode") ?: "zoomIn"
    
    if (mode == "zoomIn") {
      SDKMap.zoomIn()
    } else {
      SDKMap.zoomOut()
    }
    result.success(null)
  }
  
  private fun handleShowRect(call: MethodCall, result: MethodChannel.Result) {
    val minLat = call.argument<Double>("minLat") ?: return result.error("INVALID_ARGS", "minLat required", null)
    val minLon = call.argument<Double>("minLon") ?: return result.error("INVALID_ARGS", "minLon required", null)
    val maxLat = call.argument<Double>("maxLat") ?: return result.error("INVALID_ARGS", "maxLat required", null)
    val maxLon = call.argument<Double>("maxLon") ?: return result.error("INVALID_ARGS", "maxLon required", null)
    
    Framework.nativeSetViewportCenter((minLat + maxLat) / 2, (minLon + maxLon) / 2, 12)
    result.success(null)
  }
  
  private fun handleRotate(call: MethodCall, result: MethodChannel.Result) {
    // El SDK maneja rotación internamente
    result.success(null)
  }
  
  private fun handleZoomToPoint(call: MethodCall, result: MethodChannel.Result) {
    val lat = call.argument<Double>("latitude") ?: return result.error("INVALID_ARGS", "latitude required", null)
    val lon = call.argument<Double>("longitude") ?: return result.error("INVALID_ARGS", "longitude required", null)
    val zoom = call.argument<Int>("zoom") ?: 12
    val animate = call.argument<Boolean>("animate") ?: true
    
    Framework.nativeZoomToPoint(lat, lon, zoom, animate)
    result.success(null)
  }
  
  private fun handleGetViewport(call: MethodCall, result: MethodChannel.Result) {
    val center = Framework.nativeGetScreenRectCenter()
    result.success(mapOf(
      "centerLat" to center[0],
      "centerLon" to center[1]
    ))
  }
  
  private fun handleSearchEverywhere(call: MethodCall, result: MethodChannel.Result) {
    val query = call.argument<String>("query") ?: return result.error("INVALID_ARGS", "query required", null)
    val timestamp = System.currentTimeMillis()
    
    android.util.Log.i("OrganicMapView", "🔍 handleSearchEverywhere called with query: \"$query\"")
    
    val searchListener = object : SearchListener {
      private val results = mutableListOf<Map<String, Any>>()
      
      override fun onResultsUpdate(results: Array<SearchResult>, timestamp: Long) {
        android.util.Log.i("OrganicMapView", "🔍 onResultsUpdate: ${results.size} results received")
        results.forEach { searchResult ->
          android.util.Log.d("OrganicMapView", "  - ${searchResult.name} (${searchResult.lat}, ${searchResult.lon})")
          
          // Convertir el tipo int a String
          val typeString = when (searchResult.type) {
            SearchResult.TYPE_PURE_SUGGEST -> "pure_suggest"
            SearchResult.TYPE_SUGGEST -> "suggest"
            SearchResult.TYPE_RESULT -> "result"
            else -> "unknown"
          }
          
          this.results.add(mapOf(
            "name" to searchResult.name,
            "description" to (searchResult.description?.description ?: ""),
            "latitude" to searchResult.lat,
            "longitude" to searchResult.lon,
            "type" to typeString
          ))
        }
      }
      
      override fun onResultsEnd(timestamp: Long) {
        android.util.Log.i("OrganicMapView", "✅ onResultsEnd: Total ${this.results.size} results, sending to Flutter")
        result.success(this.results)
        SearchEngine.INSTANCE.removeListener(this)
      }
    }
    
    SearchEngine.INSTANCE.addListener(searchListener)
    android.util.Log.i("OrganicMapView", "🔍 SearchListener added")
    
    val location = locationHelper?.savedLocation
    val lat = location?.latitude ?: 0.0
    val lon = location?.longitude ?: 0.0
    val hasLocation = location != null
    
    android.util.Log.i("OrganicMapView", "🔍 Location: hasLocation=$hasLocation, lat=$lat, lon=$lon")
    android.util.Log.i("OrganicMapView", "🔍 Calling SearchEngine.search()...")
    
    val searchStarted = SearchEngine.INSTANCE.search(context, query, false, timestamp, hasLocation, lat, lon)
    
    if (searchStarted) {
      android.util.Log.i("OrganicMapView", "✅ Search started successfully")
    } else {
      android.util.Log.w("OrganicMapView", "❌ Search failed to start")
      result.error("SEARCH_FAILED", "Failed to start search", null)
      SearchEngine.INSTANCE.removeListener(searchListener)
    }
  }
  
  private fun handleSearchInViewport(call: MethodCall, result: MethodChannel.Result) {
    val query = call.argument<String>("query") ?: return result.error("INVALID_ARGS", "query required", null)
    val timestamp = System.currentTimeMillis()
    
    val searchListener = object : SearchListener {
      private val results = mutableListOf<Map<String, Any>>()
      
      override fun onResultsUpdate(results: Array<SearchResult>, timestamp: Long) {
        results.forEach { searchResult ->
          // Convertir el tipo int a String
          val typeString = when (searchResult.type) {
            SearchResult.TYPE_PURE_SUGGEST -> "pure_suggest"
            SearchResult.TYPE_SUGGEST -> "suggest"
            SearchResult.TYPE_RESULT -> "result"
            else -> "unknown"
          }
          
          this.results.add(mapOf(
            "name" to searchResult.name,
            "description" to (searchResult.description?.description ?: ""),
            "latitude" to searchResult.lat,
            "longitude" to searchResult.lon,
            "type" to typeString
          ))
        }
      }
      
      override fun onResultsEnd(timestamp: Long) {
        result.success(this.results)
        SearchEngine.INSTANCE.removeListener(this)
      }
    }
    
    SearchEngine.INSTANCE.addListener(searchListener)
    SearchEngine.INSTANCE.searchInteractive(context, query, false, timestamp, true)
  }
  
  private fun handleCancelSearch(call: MethodCall, result: MethodChannel.Result) {
    SearchEngine.INSTANCE.cancel()
    result.success(null)
  }
  
  private fun handleBuildRoute(call: MethodCall, result: MethodChannel.Result) {
    val startLat = call.argument<Double>("startLat") ?: return result.error("INVALID_ARGS", "startLat required", null)
    val startLon = call.argument<Double>("startLon") ?: return result.error("INVALID_ARGS", "startLon required", null)
    val endLat = call.argument<Double>("endLat") ?: return result.error("INVALID_ARGS", "endLat required", null)
    val endLon = call.argument<Double>("endLon") ?: return result.error("INVALID_ARGS", "endLon required", null)
    val type = call.argument<String>("type") ?: "vehicle"
    
    android.util.Log.i("OrganicMapView", "🗺️ ========== BUILD ROUTE ==========")
    android.util.Log.i("OrganicMapView", "🗺️ From: ($startLat, $startLon)")
    android.util.Log.i("OrganicMapView", "🗺️ To: ($endLat, $endLon)")
    android.util.Log.i("OrganicMapView", "🗺️ Type: $type")
    
    // Log current routing state BEFORE building
    android.util.Log.i("OrganicMapView", "🗺️ Current routing state:")
    android.util.Log.i("OrganicMapView", "  - isPlanning: ${RoutingController.get().isPlanning}")
    android.util.Log.i("OrganicMapView", "  - isNavigating: ${RoutingController.get().isNavigating}")
    android.util.Log.i("OrganicMapView", "  - isBuilt: ${RoutingController.get().isBuilt}")
    android.util.Log.i("OrganicMapView", "  - isBuilding: ${RoutingController.get().isBuilding}")
    android.util.Log.i("OrganicMapView", "  - buildState: ${RoutingController.get().buildState}")
    
    // Log location state
    val location = locationHelper?.savedLocation
    android.util.Log.i("OrganicMapView", "🗺️ Location state:")
    android.util.Log.i("OrganicMapView", "  - hasLocation: ${location != null}")
    android.util.Log.i("OrganicMapView", "  - locationHelper.isActive: ${locationHelper?.isActive}")
    android.util.Log.i("OrganicMapView", "  - myPositionMode: ${LocationState.getMode()} (${LocationState.nameOf(LocationState.getMode())})")
    if (location != null) {
      android.util.Log.i("OrganicMapView", "  - location: (${location.latitude}, ${location.longitude})")
      android.util.Log.i("OrganicMapView", "  - accuracy: ${location.accuracy}m")
      android.util.Log.i("OrganicMapView", "  - speed: ${location.speed}m/s")
      android.util.Log.i("OrganicMapView", "  - bearing: ${location.bearing}°")
    }
    
    val router = when (type) {
      "pedestrian" -> Router.Pedestrian
      "bicycle" -> Router.Bicycle
      "transit" -> Router.Transit
      else -> Router.Vehicle
    }
    
    android.util.Log.i("OrganicMapView", "🗺️ Router type: $router")
    
    // Crear puntos de inicio y fin
    // Modificado para usar MY_POSITION para el punto de inicio
    // Esto es CRÍTICO para que la navegación funcione como GPS real (recalculando desde tu ubicación)
    // y para que el modo "FollowAndRotate" funcione correctamente.
    val startPoint = MapObject.createMapObject(
      app.organicmaps.sdk.bookmarks.data.FeatureId.EMPTY,
      MapObject.MY_POSITION,
      "Mi Ubicación",
      "",
      startLat,
      startLon
    )
    
    val endPoint = MapObject.createMapObject(
      app.organicmaps.sdk.bookmarks.data.FeatureId.EMPTY,
      MapObject.POI,
      "End",
      "",
      endLat,
      endLon
    )
    
    android.util.Log.i("OrganicMapView", "🗺️ MapObjects created:")
    android.util.Log.i("OrganicMapView", "  - startPoint: ${startPoint.name} (${startPoint.lat}, ${startPoint.lon})")
    android.util.Log.i("OrganicMapView", "  - endPoint: ${endPoint.name} (${endPoint.lat}, ${endPoint.lon})")
    android.util.Log.i("OrganicMapView", "  - startPoint.isMyPosition: ${startPoint.isMyPosition}")
    android.util.Log.i("OrganicMapView", "  - endPoint.isMyPosition: ${endPoint.isMyPosition}")
    
    try {
      // Preparar la ruta - esto automáticamente inicia la navegación cuando está lista
      android.util.Log.i("OrganicMapView", "🗺️ Calling RoutingController.prepare()...")
      RoutingController.get().prepare(startPoint, endPoint, router)
      android.util.Log.i("OrganicMapView", "✅ RoutingController.prepare() called successfully")
      android.util.Log.i("OrganicMapView", "✅ Navigation will start AUTOMATICALLY when route is built (in onBuiltRoute callback)")
      
      // Log state AFTER prepare
      android.util.Log.i("OrganicMapView", "🗺️ Routing state AFTER prepare:")
      android.util.Log.i("OrganicMapView", "  - isPlanning: ${RoutingController.get().isPlanning}")
      android.util.Log.i("OrganicMapView", "  - isNavigating: ${RoutingController.get().isNavigating}")
      android.util.Log.i("OrganicMapView", "  - isBuilt: ${RoutingController.get().isBuilt}")
      android.util.Log.i("OrganicMapView", "  - isBuilding: ${RoutingController.get().isBuilding}")
      android.util.Log.i("OrganicMapView", "  - buildState: ${RoutingController.get().buildState}")
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error calling prepare()", e)
      e.printStackTrace()
      result.error("ERROR", e.message, null)
      return
    }
    
    result.success(mapOf(
      "success" to true,
      "totalDistance" to "Calculando...",
      "totalTime" to "Calculando..."
    ))
  }
  
  private fun handleFollowRoute(call: MethodCall, result: MethodChannel.Result) {
    android.util.Log.i("OrganicMapView", "")
    android.util.Log.i("OrganicMapView", "🚗 ========== FOLLOW ROUTE (MANUAL START) ==========")
    android.util.Log.i("OrganicMapView", "🗺️ Current state:")
    
    if (!RoutingController.get().isBuilt) {
      result.error("NOT_READY", "Route is not built yet", null)
      return
    }
    
    try {
      // 1. Asegurar que el helper de ubicación esté activo
      if (locationHelper?.isActive != true) {
         android.util.Log.i("OrganicMapView", "🔄 Starting location updates before navigation...")
         locationHelper?.start()
      }

      // 2. Habilitar modo 3D explícitamente y Edificios 3D y AutoZoom, y Estilo de Vehículo
      android.util.Log.i("OrganicMapView", "🎬 Enabling 3D mode & Vehicle Style...")
      Framework.nativeSet3dMode(true, true)
      Framework.nativeSetAutoZoomEnabled(true)
      
      // Cambiar estilo a Vehículo (esto cambia el icono a flecha de navegación)
      app.organicmaps.sdk.MapStyle.set(app.organicmaps.sdk.MapStyle.VehicleClear)
      
      // 3. Iniciar la navegación (esto debería cambiar el modo a FOLLOW_AND_ROTATE interinamente)
      android.util.Log.i("OrganicMapView", "🎬 Calling RoutingController.start()...")
      RoutingController.get().start()
      android.util.Log.i("OrganicMapView", "✅ RoutingController.start() called")
      
      // 4. Ajustar el offset de la flecha de navegación (simulando perspectiva de conductor)
      try {
        val density = context.resources.displayMetrics.density
        // Un offset positivo mueve la flecha hacia abajo. 200dp es un valor razonable.
        val offsetPixels = (200 * density).toInt() 
        mapController.updateMyPositionRoutingOffset(offsetPixels)
        android.util.Log.i("OrganicMapView", "📍 Adjusted navigation routing offset: ${offsetPixels}px")
      } catch (e: Exception) {
        android.util.Log.e("OrganicMapView", "⚠️ Failed to set routing offset", e)
      }
      
      // 5. FORZAR el cambio de modo de cámara a FOLLOW_AND_ROTATE (Modo 4)
      // Implementación robusta tipo "while loop" para asegurar que llegamos al modo correcto
      containerView.postDelayed({
          try {
              var currentMode = LocationState.getMode()
              val targetMode = LocationState.FOLLOW_AND_ROTATE
              var attempts = 0
              val maxAttempts = 10
              
              android.util.Log.i("OrganicMapView", "� Forcing mode switch. Current: $currentMode, Target: $targetMode")
              
              while (currentMode != targetMode && attempts < maxAttempts) {
                  android.util.Log.i("OrganicMapView", "  - Attempt ${attempts + 1}: Switching next mode...")
                  LocationState.nativeSwitchToNextMode()
                  currentMode = LocationState.getMode()
                  android.util.Log.i("OrganicMapView", "  - New mode: $currentMode")
                  attempts++
              }
              
              if (currentMode == targetMode) {
                  android.util.Log.i("OrganicMapView", "✅ Successfully forced Navigation Mode (FOLLOW_AND_ROTATE)")
              } else {
                  android.util.Log.w("OrganicMapView", "⚠️ Failed to reach Navigation Mode after $maxAttempts attempts")
              }
          } catch (e: Exception) {
              android.util.Log.e("OrganicMapView", "❌ Error forcing mode switch", e)
          }
      }, 200) // Pequeño delay inicial para estabilidad

      result.success(null)
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error starting navigation", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleStopNavigation(call: MethodCall, result: MethodChannel.Result) {
    android.util.Log.i("OrganicMapView", "🛑 ========== STOP NAVIGATION ==========")
    
    try {
      RoutingController.get().cancel()
      
      // Restaurar el offset de la flecha a 0 (centro) y estilo Normal
      try {
        mapController.updateMyPositionRoutingOffset(0)
        app.organicmaps.sdk.MapStyle.set(app.organicmaps.sdk.MapStyle.Clear)
        android.util.Log.i("OrganicMapView", "📍 Reset routing offset to 0 and Style to Clear")
      } catch (e: Exception) {
         // ignorer
      }
      
      android.util.Log.i("OrganicMapView", "✅ Navigation cancelled")
      result.success(null)
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error stopping navigation", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleGetRouteFollowingInfo(call: MethodCall, result: MethodChannel.Result) {
    val info = Framework.nativeGetRouteFollowingInfo()
    if (info != null) {
      result.success(mapOf(
        "distanceToTarget" to info.distToTarget.mDistanceStr,
        "distanceToTurn" to info.distToTurn.mDistanceStr,
        "timeToTarget" to info.totalTimeInSeconds,
        "turnSuffix" to (info.nextStreet ?: "")
      ))
    } else {
      result.success(null)
    }
  }
  
  private fun handleCreateBookmark(call: MethodCall, result: MethodChannel.Result) {
    val lat = call.argument<Double>("latitude") ?: return result.error("INVALID_ARGS", "latitude required", null)
    val lon = call.argument<Double>("longitude") ?: return result.error("INVALID_ARGS", "longitude required", null)
    val name = call.argument<String>("name") ?: "Bookmark"
    
    val bookmark = BookmarkManager.INSTANCE.addNewBookmark(lat, lon)
    if (bookmark != null) {
      val colorIndex = bookmark.icon?.color ?: BookmarkManager.INSTANCE.lastEditedColor
      BookmarkManager.INSTANCE.setBookmarkParams(
        bookmark.bookmarkId,
        name,
        colorIndex,
        call.argument<String>("description") ?: ""
      )
      result.success(bookmark.bookmarkId.toString())
    } else {
      result.error("ERROR", "Failed to create bookmark", null)
    }
  }
  
  private fun handleDeleteBookmark(call: MethodCall, result: MethodChannel.Result) {
    val bookmarkId = call.argument<String>("bookmarkId")?.toLongOrNull() 
      ?: return result.error("INVALID_ARGS", "bookmarkId required", null)
    
    BookmarkManager.INSTANCE.deleteBookmark(bookmarkId)
    result.success(null)
  }
  
  private fun handleGetBookmarks(call: MethodCall, result: MethodChannel.Result) {
    val categories = BookmarkManager.INSTANCE.categories
    val bookmarks = mutableListOf<Map<String, Any>>()
    
    categories.forEach { category ->
      val count = category.bookmarksCount
      for (i in 0 until count) {
        val bmkId = BookmarkManager.INSTANCE.getBookmarkIdByPosition(category.id, i)
        val info = BookmarkManager.INSTANCE.getBookmarkInfo(bmkId)
        if (info != null) {
          bookmarks.add(mapOf(
            "id" to bmkId.toString(),
            "name" to info.name,
            "latitude" to info.lat,
            "longitude" to info.lon,
            "description" to BookmarkManager.INSTANCE.getBookmarkDescription(bmkId)
          ))
        }
      }
    }
    
    result.success(bookmarks)
  }
  
  private fun handleShowBookmark(call: MethodCall, result: MethodChannel.Result) {
    val bookmarkId = call.argument<String>("bookmarkId")?.toLongOrNull()
      ?: return result.error("INVALID_ARGS", "bookmarkId required", null)
    
    BookmarkManager.INSTANCE.showBookmarkOnMap(bookmarkId)
    result.success(null)
  }
  
  private fun handleStartTrackRecording(call: MethodCall, result: MethodChannel.Result) {
    try {
      android.util.Log.i("OrganicMapView", "🎬 Starting track recording...")
      
      // 1. Verificar permisos de ubicación
      if (!app.organicmaps.sdk.util.LocationUtils.checkFineLocationPermission(context)) {
        android.util.Log.e("OrganicMapView", "❌ Fine location permission not granted")
        result.error("PERMISSION_DENIED", "Fine location permission is required for track recording", null)
        return
      }
      
      // 2. Asegurar que el LocationHelper esté activo
      if (locationHelper?.isActive != true) {
        android.util.Log.i("OrganicMapView", "🔄 Starting location updates for track recording...")
        locationHelper?.start()
      }
      
      // 3. Habilitar el GpsTracker (conectarlo al Framework)
      android.util.Log.i("OrganicMapView", "🔄 Enabling GPS Tracker...")
      TrackRecorder.nativeSetEnabled(true)
      
      // 4. Iniciar la grabación
      android.util.Log.i("OrganicMapView", "🔄 Starting track recording...")
      TrackRecorder.nativeStartTrackRecording()
      
      android.util.Log.i("OrganicMapView", "✅ Track recording started successfully")
      result.success(mapOf(
        "success" to true,
        "isRecording" to TrackRecorder.nativeIsTrackRecordingEnabled()
      ))
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error starting track recording", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleStopTrackRecording(call: MethodCall, result: MethodChannel.Result) {
    try {
      android.util.Log.i("OrganicMapView", "🛑 Stopping track recording...")
      
      val wasEmpty = TrackRecorder.nativeIsTrackRecordingEmpty()
      TrackRecorder.nativeStopTrackRecording()
      
      // Opcional: Deshabilitar el GpsTracker para ahorrar batería
      // Solo si no estamos en navegación
      if (!RoutingController.get().isNavigating) {
        TrackRecorder.nativeSetEnabled(false)
        android.util.Log.i("OrganicMapView", "📍 GPS Tracker disabled (not navigating)")
      }
      
      android.util.Log.i("OrganicMapView", "✅ Track recording stopped. Was empty: $wasEmpty")
      result.success(mapOf(
        "success" to true,
        "wasEmpty" to wasEmpty
      ))
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error stopping track recording", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleSaveTrack(call: MethodCall, result: MethodChannel.Result) {
    try {
      val name = call.argument<String>("name") ?: "Track ${System.currentTimeMillis()}"
      
      android.util.Log.i("OrganicMapView", "💾 Saving track with name: $name")
      
      // Verificar si hay datos para guardar
      if (TrackRecorder.nativeIsTrackRecordingEmpty()) {
        android.util.Log.w("OrganicMapView", "⚠️ Track is empty, nothing to save")
        result.error("EMPTY_TRACK", "No track data to save. The recording was empty.", null)
        return
      }
      
      TrackRecorder.nativeSaveTrackRecordingWithName(name)
      
      android.util.Log.i("OrganicMapView", "✅ Track saved: $name")
      result.success(mapOf(
        "success" to true,
        "name" to name
      ))
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error saving track", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleIsTrackRecording(call: MethodCall, result: MethodChannel.Result) {
    try {
      val isRecording = TrackRecorder.nativeIsTrackRecordingEnabled()
      val isEmpty = if (isRecording) TrackRecorder.nativeIsTrackRecordingEmpty() else true
      val isGpsTrackerEnabled = TrackRecorder.nativeIsEnabled()
      
      result.success(mapOf(
        "isRecording" to isRecording,
        "isEmpty" to isEmpty,
        "isGpsTrackerEnabled" to isGpsTrackerEnabled
      ))
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "❌ Error checking track recording status", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleUpdateLocation(call: MethodCall, result: MethodChannel.Result) {
    // NOTA: Este método ya no se usa porque la ubicación viene directamente del
    // AndroidNativeProvider que se configura en el LocationHelper.
    // La ubicación nativa del motor de mapas se maneja automáticamente.
    android.util.Log.w("OrganicMapView", "handleUpdateLocation called but location is handled natively")
    result.success(null)
  }
  
  private fun handleSwitchMyPositionMode(call: MethodCall, result: MethodChannel.Result) {
    try {
      // Simplemente llamar al método nativo UNA VEZ
      // El sistema manejará el ciclo de modos automáticamente
      LocationState.nativeSwitchToNextMode()
      android.util.Log.i("OrganicMapView", "Switched to next position mode")
      
      result.success(null)
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "Error switching position mode", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleStartLocationUpdates(call: MethodCall, result: MethodChannel.Result) {
    if (app.organicmaps.sdk.util.LocationUtils.checkLocationPermission(context)) {
      locationHelper?.start()
      android.util.Log.i("OrganicMapView", "Location updates started")
      result.success(null)
    } else {
      android.util.Log.w("OrganicMapView", "Location permissions not granted")
      result.error("PERMISSION_DENIED", "Location permissions not granted", null)
    }
  }
  
  private fun handleStopLocationUpdates(call: MethodCall, result: MethodChannel.Result) {
    locationHelper?.stop()
    result.success(null)
  }
  
  private fun handleGetMyPosition(call: MethodCall, result: MethodChannel.Result) {
    val location = locationHelper?.savedLocation
    if (location != null) {
      result.success(mapOf(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracy" to location.accuracy.toDouble(),
        "altitude" to location.altitude,
        "bearing" to location.bearing.toDouble(),
        "speed" to location.speed.toDouble(),
        "timestamp" to location.time // timestamp en milisegundos desde epoch
      ))
    } else {
      result.success(null)
    }
  }
  
  private fun handleSetTrafficEnabled(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    TrafficManager.INSTANCE.setEnabled(enabled)
    result.success(null)
  }
  
  private fun handleIsTrafficEnabled(call: MethodCall, result: MethodChannel.Result) {
    result.success(TrafficManager.INSTANCE.isEnabled)
  }
  
  private fun handleSetTransitEnabled(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    Framework.nativeSetTransitSchemeEnabled(enabled)
    result.success(null)
  }
  
  private fun handleSet3dMode(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    val buildings = call.argument<Boolean>("buildings") ?: enabled
    Framework.nativeSet3dMode(enabled, buildings)
    result.success(null)
  }
  
  private fun handleSetAutoZoom(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    Framework.nativeSetAutoZoomEnabled(enabled)
    result.success(null)
  }
  
  private fun handleSetMapStyle(call: MethodCall, result: MethodChannel.Result) {
    val style = call.argument<String>("style") ?: "defaultLight"
    val mapStyle = when (style) {
      "defaultDark" -> MapStyle.Dark
      "vehicleLight" -> MapStyle.VehicleClear
      "vehicleDark" -> MapStyle.VehicleDark
      "outdoorsLight" -> MapStyle.OutdoorsClear
      "outdoorsDark" -> MapStyle.OutdoorsDark
      else -> MapStyle.Clear
    }
    MapStyle.set(mapStyle)
    result.success(null)
  }
  
  private fun handleGetMapStyle(call: MethodCall, result: MethodChannel.Result) {
    val style = MapStyle.get()
    val styleName = when (style) {
      MapStyle.Dark -> "defaultDark"
      MapStyle.VehicleClear -> "vehicleLight"
      MapStyle.VehicleDark -> "vehicleDark"
      MapStyle.OutdoorsClear -> "outdoorsLight"
      MapStyle.OutdoorsDark -> "outdoorsDark"
      else -> "defaultLight"
    }
    result.success(styleName)
  }
  
  private fun handleCanEditFeature(call: MethodCall, result: MethodChannel.Result) {
    result.success(Editor.nativeShouldEnableEditPlace())
  }
  
  private fun handleStartEdit(call: MethodCall, result: MethodChannel.Result) {
    Editor.nativeStartEdit()
    result.success(null)
  }
  
  private fun handleSaveEditedFeature(call: MethodCall, result: MethodChannel.Result) {
    val saved = Editor.nativeSaveEditedFeature()
    result.success(saved)
  }
  
  private fun handleCreateMapObject(call: MethodCall, result: MethodChannel.Result) {
    val type = call.argument<String>("type") ?: return result.error("INVALID_ARGS", "type required", null)
    Editor.nativeCreateMapObject(type)
    result.success(null)
  }
  
  private fun handleGetCountries(call: MethodCall, result: MethodChannel.Result) {
    android.util.Log.i("OrganicMapView", "=== Getting countries list ===")
    
    val countries = mutableListOf<CountryItem>()
    
    // Obtener ubicación actual si está disponible
    val location = locationHelper?.savedLocation
    val hasLocation = location != null
    val lat = location?.latitude ?: 0.0
    val lon = location?.longitude ?: 0.0
    
    android.util.Log.i("OrganicMapView", "Location for countries: hasLocation=$hasLocation, lat=$lat, lon=$lon")
    
    // Obtener la lista de países (null = root)
    MapManager.nativeListItems(null, lat, lon, hasLocation, false, countries)
    android.util.Log.i("OrganicMapView", "Found ${countries.size} countries")
    
    val countryMaps = countries.map { country ->
      // Actualizar atributos del país para obtener tamaños y estado real
      country.update()
      
      android.util.Log.d("OrganicMapView", "Country: ${country.id}, size=${country.size}, totalSize=${country.totalSize}, status=${country.status}")
      
      // Mapear status entero del SDK a string que espera Flutter
      val statusString = when (country.status) {
        CountryItem.STATUS_DONE -> "downloaded"
        CountryItem.STATUS_PROGRESS, CountryItem.STATUS_APPLYING -> "downloading"
        CountryItem.STATUS_ENQUEUED -> "downloading"
        CountryItem.STATUS_UPDATABLE -> "updateAvailable"
        CountryItem.STATUS_FAILED -> "error"
        CountryItem.STATUS_DOWNLOADABLE, CountryItem.STATUS_UNKNOWN -> "notDownloaded"
        CountryItem.STATUS_PARTLY -> "downloading"
        else -> "notDownloaded"
      }
      
      mapOf(
        "id" to country.id,
        "name" to country.name,
        "parentId" to country.directParentId,
        "sizeBytes" to country.size,
        "totalSizeBytes" to country.totalSize,
        "downloadedBytes" to country.downloadedBytes,
        "bytesToDownload" to country.bytesToDownload,
        "status" to statusString,
        "downloadProgress" to country.progress.toInt(),
        "childCount" to country.childCount,
        "totalChildCount" to country.totalChildCount,
        "description" to (country.description ?: ""),
        "present" to country.present
      )
    }
    
    android.util.Log.i("OrganicMapView", "Returning ${countryMaps.size} countries to Flutter")
    result.success(countryMaps)
  }
  
  private fun handleDownloadCountry(call: MethodCall, result: MethodChannel.Result) {
    val countryId = call.argument<String>("countryId") 
      ?: return result.error("INVALID_ARGS", "countryId required", null)
    
    android.util.Log.i("OrganicMapView", "=== Starting download for country: $countryId ===")
    
    try {
      // Verificar conexión a internet
      val connectionState = app.organicmaps.sdk.util.ConnectionState.INSTANCE
      val isConnected = connectionState.isConnected()
      val isWifi = connectionState.isWifiConnected()
      val isMobile = connectionState.isMobileConnected()
      android.util.Log.i("OrganicMapView", "Connection status: connected=$isConnected, wifi=$isWifi, mobile=$isMobile")
      
      if (!isConnected) {
        android.util.Log.w("OrganicMapView", "No internet connection available")
        result.error("NO_INTERNET", "No internet connection available", null)
        return
      }
      
      // Si está en datos móviles, verificar si está habilitado el download en 3G
      if (isMobile && !isWifi) {
        val is3gEnabled = MapManager.nativeIsDownloadOn3gEnabled()
        android.util.Log.i("OrganicMapView", "Download on 3G enabled: $is3gEnabled")
        
        // Si no está permitido, habilitar automáticamente
        if (!is3gEnabled) {
          android.util.Log.i("OrganicMapView", "Enabling mobile data downloads automatically")
          MapManager.nativeEnableDownloadOn3g()
        }
      }
      
      // Verificar si hay espacio suficiente
      val hasSpace = MapManager.nativeHasSpaceToDownloadCountry(countryId)
      android.util.Log.i("OrganicMapView", "Has space to download: $hasSpace")
      
      if (!hasSpace) {
        android.util.Log.w("OrganicMapView", "Not enough space to download $countryId")
        result.error("NO_SPACE", "Not enough space to download map", null)
        return
      }
      
      // Verificar si ya está descargando
      val isDownloading = MapManager.nativeIsDownloading()
      android.util.Log.i("OrganicMapView", "Is currently downloading: $isDownloading")
      
      // CRITICAL: Start foreground service BEFORE downloading
      // This is required for Android to allow background network operations
      DownloaderService.startForegroundService(context)
      android.util.Log.i("OrganicMapView", "Foreground service started")
      
      // Iniciar descarga
      MapManager.startDownload(countryId)
      android.util.Log.i("OrganicMapView", "Download started for $countryId")
      
      result.success(mapOf("requiresConfirmation" to false))
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "Error starting download", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleSetMobileDataPolicy(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: true
    
    try {
      if (enabled) {
        MapManager.nativeEnableDownloadOn3g()
        android.util.Log.i("OrganicMapView", "Mobile data downloads enabled")
      }
      // Note: There's no native method to disable 3G downloads, it's a one-time enable
      
      result.success(null)
    } catch (e: Exception) {
      android.util.Log.e("OrganicMapView", "Error setting mobile data policy", e)
      result.error("ERROR", e.message, null)
    }
  }
  
  private fun handleDeleteCountry(call: MethodCall, result: MethodChannel.Result) {
    val countryId = call.argument<String>("countryId")
      ?: return result.error("INVALID_ARGS", "countryId required", null)
    
    MapManager.nativeDelete(countryId)
    result.success(null)
  }
  
  private fun handleCancelDownload(call: MethodCall, result: MethodChannel.Result) {
    val countryId = call.argument<String>("countryId")
      ?: return result.error("INVALID_ARGS", "countryId required", null)
    
    MapManager.nativeCancel(countryId)
    result.success(null)
  }
  
  // ==================== CAPAS DEL MAPA ====================
  
  private fun handleSetSubwayEnabled(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    SubwayManager.setEnabled(enabled)
    result.success(null)
  }
  
  private fun handleIsSubwayEnabled(call: MethodCall, result: MethodChannel.Result) {
    result.success(SubwayManager.isEnabled())
  }
  
  private fun handleSetIsolinesEnabled(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    IsolinesManager.setEnabled(enabled)
    result.success(null)
  }
  
  private fun handleIsIsolinesEnabled(call: MethodCall, result: MethodChannel.Result) {
    result.success(IsolinesManager.isEnabled())
  }
  
  // ==================== TTS / VOZ ====================
  
  private fun handleSetTtsEnabled(call: MethodCall, result: MethodChannel.Result) {
    // val enabled = call.argument<Boolean>("enabled") ?: false
    // TtsPlayer.setEnabled(enabled)
    result.success(null)
  }
  
  private fun handleIsTtsEnabled(call: MethodCall, result: MethodChannel.Result) {
    // result.success(TtsPlayer.isEnabled())
    result.success(false)
  }
  
  private fun handleSetTtsVolume(call: MethodCall, result: MethodChannel.Result) {
    // val volume = call.argument<Double>("volume")?.toFloat() ?: 1.0f
    // TtsPlayer.INSTANCE.volume = volume
    result.success(null)
  }
  
  private fun handleGetTtsVolume(call: MethodCall, result: MethodChannel.Result) {
    // result.success(TtsPlayer.INSTANCE.volume.toDouble())
    result.success(1.0)
  }
  // IMPLEMENTACIÓN DE PlacePageActivationListener
  // Esto se llama cuando el motor selecciona un punto en el mapa (poi, custom point, etc.)
  override fun onPlacePageActivated(data: PlacePageData) {
    android.util.Log.i("OrganicMapView", "📍 onPlacePageActivated triggered")
    
    if (data is MapObject) {
      val lat = data.lat
      val lon = data.lon
      val title = data.title
      val subtitle = data.subtitle
      
      android.util.Log.i("OrganicMapView", "✅ MapObject selected: $title ($subtitle)")
      android.util.Log.i("OrganicMapView", "  - Lat: $lat, Lon: $lon")
      
      // Enviar coordenadas a Flutter
      containerView.post {
        methodChannel.invokeMethod("onMapTap", mapOf(
          "latitude" to lat,
          "longitude" to lon,
          "name" to title,
          "address" to subtitle
        ))
      }
    } else {
      android.util.Log.w("OrganicMapView", "⚠️ Selected object is NOT a MapObject: ${data.javaClass.simpleName}")
    }
  }

  override fun onPlacePageDeactivated() {
    android.util.Log.i("OrganicMapView", "🚫 onPlacePageDeactivated")
    // Opcional: Notificar a Flutter que se deseleccionó
  }

  override fun onSwitchFullScreenMode() {
    android.util.Log.i("OrganicMapView", "📺 onSwitchFullScreenMode triggered")
  }
}
