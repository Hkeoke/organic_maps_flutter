package app.organicmaps.flutter

import android.content.Context
import android.util.Log
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
import app.organicmaps.sdk.search.SearchEngine
import app.organicmaps.sdk.search.SearchListener
import app.organicmaps.sdk.search.SearchResult
import app.organicmaps.sdk.location.LocationHelper
import app.organicmaps.sdk.location.LocationState
import app.organicmaps.sdk.location.TrackRecorder
import app.organicmaps.sdk.editor.Editor
import app.organicmaps.sdk.downloader.MapManager
import app.organicmaps.sdk.downloader.CountryItem
import app.organicmaps.sdk.PlacePageActivationListener
import app.organicmaps.sdk.widget.placepage.PlacePageData

/**
 * Platform View que integra el SDK completo de Organic Maps con Flutter.
 *
 * Responsabilidades:
 * - Inicialización del motor de mapas y rendering
 * - Manejo de GPS y modos de posición
 * - Búsqueda, routing/navegación, bookmarks
 * - Descarga/eliminación de mapas offline
 * - Capas de tráfico, subway, isolines
 * - Track recording (grabación de trayecto)
 */
class OrganicMapView(
  context: Context,
  messenger: BinaryMessenger,
  id: Int,
  creationParams: Map<String, Any>?
) : PlatformView, MethodChannel.MethodCallHandler, PlacePageActivationListener {

  companion object {
    private const val TAG = "OrganicMapView"
    private var organicMaps: app.organicmaps.sdk.OrganicMaps? = null
    private var initializationStarted = false
    private val initLock = Object()

    init {
      try {
        System.loadLibrary("organicmaps")
      } catch (e: Exception) {
        Log.e(TAG, "Failed to load native library", e)
      }
    }
  }

  private val containerView = android.widget.FrameLayout(context)
  private val mapView = SDKMapView(context)
  private lateinit var mapController: app.organicmaps.sdk.MapController
  private val methodChannel = MethodChannel(messenger, "organic_maps_flutter/map_$id")
  private val context: Context = context

  private var locationHelper: LocationHelper? = null
  private var storageCallbackSlot: Int = 0
  private var mapReady = false

  // ==================== STORAGE CALLBACK ====================

  private val storageCallback = object : MapManager.StorageCallback {
    override fun onStatusChanged(data: MutableList<MapManager.StorageCallbackData>) {
      val updates = data.map { item ->
        mapOf(
          "countryId" to item.countryId,
          "status" to mapStatusToString(item.newStatus)
        )
      }
      postToFlutter("onCountriesChanged", updates)
    }

    override fun onProgress(countryId: String, localSize: Long, remoteSize: Long) {
      val progress = if (remoteSize > 0) (localSize * 100 / remoteSize).toInt() else 0
      postToFlutter("onCountryProgress", mapOf(
        "countryId" to countryId,
        "progress" to progress
      ))
    }
  }

  // ==================== INICIALIZACIÓN ====================

  init {
    methodChannel.setMethodCallHandler(this)

    synchronized(initLock) {
      if (organicMaps == null && !initializationStarted) {
        initializationStarted = true
        initializeOrganicMaps()
      }
    }

    waitForFrameworkAndInitialize()
  }

  private fun initializeOrganicMaps() {
    containerView.post {
      try {
        // ConnectionState DEBE inicializarse ANTES de OrganicMaps
        app.organicmaps.sdk.util.ConnectionState.INSTANCE.initialize(context)

        val locationProviderFactory = object : app.organicmaps.sdk.location.LocationProviderFactory {
          override fun isGoogleLocationAvailable(context: Context): Boolean = false
          override fun getProvider(
            context: Context,
            listener: app.organicmaps.sdk.location.BaseLocationProvider.Listener
          ): app.organicmaps.sdk.location.BaseLocationProvider {
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

        organicMaps?.init(Runnable {
          Log.i(TAG, "Framework ready")
        })
      } catch (e: Exception) {
        Log.e(TAG, "Error initializing OrganicMaps", e)
      }
    }
  }

  private fun waitForFrameworkAndInitialize() {
    if (organicMaps != null && organicMaps!!.arePlatformAndCoreInitialized()) {
      initializeMapView(organicMaps!!)
    } else {
      containerView.postDelayed({ waitForFrameworkAndInitialize() }, 100)
    }
  }

  private fun initializeMapView(organicMaps: app.organicmaps.sdk.OrganicMaps) {
    locationHelper = organicMaps.locationHelper

    // Inicializar RoutingController
    RoutingController.get().initialize(organicMaps.locationHelper)
    RoutingController.get().attach(createRoutingContainer())

    // Crear MapController
    mapController = app.organicmaps.sdk.MapController(
      mapView,
      organicMaps.locationHelper,
      createMapRenderingListener(),
      null,
      false
    )

    // Configurar selección de objetos en el mapa
    configureMapInteraction()

    // Llamar lifecycle
    startLifecycle()

    // Listener de modo de posición
    LocationState.nativeSetListener(createLocationModeListener())

    // Suscribir a eventos de descarga
    storageCallbackSlot = MapManager.nativeSubscribe(storageCallback)

    // Agregar mapView al container
    containerView.addView(mapView, android.widget.FrameLayout.LayoutParams(
      android.widget.FrameLayout.LayoutParams.MATCH_PARENT,
      android.widget.FrameLayout.LayoutParams.MATCH_PARENT
    ))
  }

  // ==================== FACTORIES DE LISTENERS ====================

  private fun createRoutingContainer(): RoutingController.Container {
    return object : RoutingController.Container {
      override fun showRoutePlan(show: Boolean, completionListener: Runnable?) {
        completionListener?.run()
      }

      override fun showNavigation(show: Boolean) {}
      override fun updateMenu() {}

      override fun onNavigationStarted() {
        postToFlutter("onNavigationStarted", null)
      }

      override fun onNavigationCancelled() {
        // Restaurar modo 3D al cancelar
        safeExecute { Framework.nativeSet3dMode(false, false) }
        postToFlutter("onNavigationCancelled", null)
      }

      override fun onBuiltRoute() {
        val routeInfo = RoutingController.get().cachedRoutingInfo
        val data = mapOf(
          "totalDistance" to (routeInfo?.distToTarget?.mDistanceStr ?: "0 m"),
          "totalTime" to (routeInfo?.totalTimeInSeconds ?: 0)
        )
        postToFlutter("onRouteBuilt", data)
      }

      override fun onCommonBuildError(lastResultCode: Int, lastMissingMaps: Array<out String>) {
        Log.e(TAG, "Route build error: $lastResultCode, missing: ${lastMissingMaps.joinToString()}")
      }

      override fun updateBuildProgress(progress: Int, router: Router) {}
    }
  }

  private fun createMapRenderingListener(): app.organicmaps.sdk.MapRenderingListener {
    return object : app.organicmaps.sdk.MapRenderingListener {
      override fun onRenderingCreated() {
        mapReady = true
        methodChannel.invokeMethod("onMapReady", null)
      }

      override fun onRenderingRestored() {}
    }
  }

  private fun createLocationModeListener(): LocationState.ModeChangeListener {
    return object : LocationState.ModeChangeListener {
      override fun onMyPositionModeChanged(newMode: Int) {
        // Gestionar LocationHelper según el modo
        when (newMode) {
          LocationState.NOT_FOLLOW_NO_POSITION -> {
            if (locationHelper?.isActive == true) locationHelper?.stop()
          }
          else -> {
            if (app.organicmaps.sdk.util.LocationUtils.checkLocationPermission(context)) {
              safeExecute { locationHelper?.restartWithNewMode() }
            }
          }
        }

        postToFlutter("onMyPositionModeChanged", mapOf(
          "mode" to newMode,
          "modeName" to LocationState.nameOf(newMode)
        ))
      }
    }
  }

  private fun configureMapInteraction() {
    val gestureDetector = android.view.GestureDetector(context,
      object : android.view.GestureDetector.SimpleOnGestureListener() {
        override fun onSingleTapConfirmed(e: android.view.MotionEvent): Boolean {
          SDKMap.onClick(e.x, e.y)
          return true
        }
      }
    )

    Framework.nativePlacePageActivationListener(this)

    mapView.setOnTouchListener { _, event ->
      gestureDetector.onTouchEvent(event)
      false
    }
  }

  private fun startLifecycle() {
    safeExecute {
      val lifecycleOwner = object : androidx.lifecycle.LifecycleOwner {
        override val lifecycle: androidx.lifecycle.Lifecycle
          get() = androidx.lifecycle.LifecycleRegistry(this).apply {
            currentState = androidx.lifecycle.Lifecycle.State.RESUMED
          }
      }
      mapController.onStart(lifecycleOwner)
      mapController.onResume(lifecycleOwner)
    }
  }

  // ==================== PLATFORM VIEW ====================

  override fun getView(): View = containerView

  override fun dispose() {
    methodChannel.setMethodCallHandler(null)
    LocationState.nativeRemoveListener()
    RoutingController.get().detach()

    if (storageCallbackSlot != 0) {
      MapManager.nativeUnsubscribe(storageCallbackSlot)
      storageCallbackSlot = 0
    }

    safeExecute {
      val lifecycleOwner = object : androidx.lifecycle.LifecycleOwner {
        override val lifecycle: androidx.lifecycle.Lifecycle
          get() = androidx.lifecycle.LifecycleRegistry(this).apply {
            currentState = androidx.lifecycle.Lifecycle.State.DESTROYED
          }
      }
      mapController.onPause(lifecycleOwner)
      mapController.onStop(lifecycleOwner)
      mapController.onDestroy(lifecycleOwner)
    }

    locationHelper?.stop()
  }

  // ==================== METHOD CALL HANDLER ====================

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    try {
      when (call.method) {
        // Navegación del mapa
        "setCenter" -> handleSetCenter(call, result)
        "zoom" -> handleZoom(call, result)
        "showRect" -> handleShowRect(call, result)
        "rotate" -> handleRotate(call, result)
        "zoomToPoint" -> handleZoomToPoint(call, result)
        "getViewport" -> handleGetViewport(call, result)

        // Búsqueda
        "searchEverywhere" -> handleSearchEverywhere(call, result)
        "searchInViewport" -> handleSearchInViewport(call, result)
        "cancelSearch" -> handleCancelSearch(result)

        // Routing
        "buildRoute" -> handleBuildRoute(call, result)
        "followRoute" -> handleFollowRoute(result)
        "stopNavigation" -> handleStopNavigation(result)
        "getRouteFollowingInfo" -> handleGetRouteFollowingInfo(result)

        // Bookmarks
        "createBookmark" -> handleCreateBookmark(call, result)
        "deleteBookmark" -> handleDeleteBookmark(call, result)
        "getBookmarks" -> handleGetBookmarks(result)
        "showBookmark" -> handleShowBookmark(call, result)

        // Track recording
        "startTrackRecording" -> handleStartTrackRecording(result)
        "stopTrackRecording" -> handleStopTrackRecording(result)
        "saveTrack" -> handleSaveTrack(call, result)
        "isTrackRecording" -> handleIsTrackRecording(result)

        // Ubicación
        "updateLocation" -> result.success(null) // Manejado nativamente
        "switchMyPositionMode" -> handleSwitchMyPositionMode(result)
        "startLocationUpdates" -> handleStartLocationUpdates(result)
        "stopLocationUpdates" -> handleStopLocationUpdates(result)
        "getMyPosition" -> handleGetMyPosition(result)

        // Capas
        "setTrafficEnabled" -> handleSetTrafficEnabled(call, result)
        "isTrafficEnabled" -> result.success(TrafficManager.INSTANCE.isEnabled)
        "setTransitEnabled" -> handleSetTransitEnabled(call, result)
        "setSubwayEnabled" -> handleSetSubwayEnabled(call, result)
        "isSubwayEnabled" -> result.success(SubwayManager.isEnabled())
        "setIsolinesEnabled" -> handleSetIsolinesEnabled(call, result)
        "isIsolinesEnabled" -> result.success(IsolinesManager.isEnabled())

        // TTS
        "setTtsEnabled" -> result.success(null) // TODO: Implementar con TtsPlayer
        "isTtsEnabled" -> result.success(false)
        "setTtsVolume" -> result.success(null)
        "getTtsVolume" -> result.success(1.0)

        // Configuración
        "set3dMode" -> handleSet3dMode(call, result)
        "setAutoZoom" -> handleSetAutoZoom(call, result)
        "setMapStyle" -> handleSetMapStyle(call, result)
        "getMapStyle" -> handleGetMapStyle(result)

        // Editor
        "canEditFeature" -> result.success(Editor.nativeShouldEnableEditPlace())
        "startEdit" -> { Editor.nativeStartEdit(); result.success(null) }
        "saveEditedFeature" -> result.success(Editor.nativeSaveEditedFeature())
        "createMapObject" -> handleCreateMapObject(call, result)

        // Gestión de mapas
        "getCountries" -> handleGetCountries(result)
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

  // ==================== MAP NAVIGATION ====================

  private fun handleSetCenter(call: MethodCall, result: MethodChannel.Result) {
    val lat = call.requireDouble("latitude", result) ?: return
    val lon = call.requireDouble("longitude", result) ?: return
    val zoom = call.argument<Int>("zoom") ?: 12

    Framework.nativeSetViewportCenter(lat, lon, zoom)
    result.success(null)
  }

  private fun handleZoom(call: MethodCall, result: MethodChannel.Result) {
    val mode = call.argument<String>("mode") ?: "zoomIn"
    if (mode == "zoomIn") SDKMap.zoomIn() else SDKMap.zoomOut()
    result.success(null)
  }

  private fun handleShowRect(call: MethodCall, result: MethodChannel.Result) {
    val minLat = call.requireDouble("minLat", result) ?: return
    val minLon = call.requireDouble("minLon", result) ?: return
    val maxLat = call.requireDouble("maxLat", result) ?: return
    val maxLon = call.requireDouble("maxLon", result) ?: return

    // Centrar en el punto medio del rectángulo con zoom apropiado
    val centerLat = (minLat + maxLat) / 2.0
    val centerLon = (minLon + maxLon) / 2.0
    Framework.nativeSetViewportCenter(centerLat, centerLon, 12)
    result.success(null)
  }

  private fun handleRotate(call: MethodCall, result: MethodChannel.Result) {
    // El SDK maneja la rotación internamente a través del motor de rendering
    result.success(null)
  }

  private fun handleZoomToPoint(call: MethodCall, result: MethodChannel.Result) {
    val lat = call.requireDouble("latitude", result) ?: return
    val lon = call.requireDouble("longitude", result) ?: return
    val zoom = call.argument<Int>("zoom") ?: 12
    val animate = call.argument<Boolean>("animate") ?: true

    Framework.nativeZoomToPoint(lat, lon, zoom, animate)
    result.success(null)
  }

  private fun handleGetViewport(call: MethodCall, result: MethodChannel.Result) {
    val center = Framework.nativeGetScreenRectCenter()
    result.success(mapOf(
      "centerLat" to center[0],
      "centerLon" to center[1],
      "zoom" to 12.0, // Framework no expone zoom directo, usar valor nominal
      "azimuth" to 0.0
    ))
  }

  // ==================== BÚSQUEDA ====================

  private fun handleSearchEverywhere(call: MethodCall, result: MethodChannel.Result) {
    val query = call.requireString("query", result) ?: return
    val timestamp = System.currentTimeMillis()

    val searchListener = createSearchListener(result)
    SearchEngine.INSTANCE.addListener(searchListener)

    val location = locationHelper?.savedLocation
    val searchStarted = SearchEngine.INSTANCE.search(
      context, query, false, timestamp,
      location != null,
      location?.latitude ?: 0.0,
      location?.longitude ?: 0.0
    )

    if (!searchStarted) {
      SearchEngine.INSTANCE.removeListener(searchListener)
      result.error("SEARCH_FAILED", "Failed to start search", null)
    }
  }

  private fun handleSearchInViewport(call: MethodCall, result: MethodChannel.Result) {
    val query = call.requireString("query", result) ?: return
    val timestamp = System.currentTimeMillis()

    val searchListener = createSearchListener(result)
    SearchEngine.INSTANCE.addListener(searchListener)
    SearchEngine.INSTANCE.searchInteractive(context, query, false, timestamp, true)
  }

  private fun handleCancelSearch(result: MethodChannel.Result) {
    SearchEngine.INSTANCE.cancel()
    result.success(null)
  }

  private fun createSearchListener(result: MethodChannel.Result): SearchListener {
    return object : SearchListener {
      private val results = mutableListOf<Map<String, Any>>()

      override fun onResultsUpdate(results: Array<SearchResult>, timestamp: Long) {
        results.forEach { sr ->
          this.results.add(mapOf(
            "name" to sr.name,
            "description" to (sr.description?.description ?: ""),
            "latitude" to sr.lat,
            "longitude" to sr.lon,
            "type" to searchTypeToString(sr.type)
          ))
        }
      }

      override fun onResultsEnd(timestamp: Long) {
        result.success(this.results)
        SearchEngine.INSTANCE.removeListener(this)
      }
    }
  }

  // ==================== ROUTING ====================

  private fun handleBuildRoute(call: MethodCall, result: MethodChannel.Result) {
    val startLat = call.requireDouble("startLat", result) ?: return
    val startLon = call.requireDouble("startLon", result) ?: return
    val endLat = call.requireDouble("endLat", result) ?: return
    val endLon = call.requireDouble("endLon", result) ?: return
    val type = call.argument<String>("type") ?: "vehicle"

    val router = routerFromString(type)

    // MY_POSITION como inicio = comportamiento GPS real con recálculo
    val startPoint = MapObject.createMapObject(
      app.organicmaps.sdk.bookmarks.data.FeatureId.EMPTY,
      MapObject.MY_POSITION, "Mi Ubicación", "",
      startLat, startLon
    )

    val endPoint = MapObject.createMapObject(
      app.organicmaps.sdk.bookmarks.data.FeatureId.EMPTY,
      MapObject.POI, "Destino", "",
      endLat, endLon
    )

    try {
      RoutingController.get().prepare(startPoint, endPoint, router)
      result.success(mapOf(
        "success" to true,
        "totalDistance" to "Calculando...",
        "totalTime" to "Calculando..."
      ))
    } catch (e: Exception) {
      Log.e(TAG, "Error building route", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleFollowRoute(result: MethodChannel.Result) {
    if (!RoutingController.get().isBuilt) {
      result.error("NOT_READY", "Route is not built yet", null)
      return
    }

    try {
      // Asegurar ubicación activa
      if (locationHelper?.isActive != true) locationHelper?.start()

      // Configurar modo navegación: 3D + AutoZoom + estilo vehículo
      Framework.nativeSet3dMode(true, true)
      Framework.nativeSetAutoZoomEnabled(true)
      MapStyle.set(MapStyle.VehicleClear)

      // Iniciar navegación
      RoutingController.get().start()

      // Ajustar offset de perspectiva de conductor
      safeExecute {
        val density = context.resources.displayMetrics.density
        mapController.updateMyPositionRoutingOffset((200 * density).toInt())
      }

      // Forzar modo FOLLOW_AND_ROTATE (navegación)
      containerView.postDelayed({
        forceNavigationMode()
      }, 200)

      result.success(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error starting navigation", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleStopNavigation(result: MethodChannel.Result) {
    try {
      RoutingController.get().cancel()

      // Restaurar estado visual
      safeExecute {
        mapController.updateMyPositionRoutingOffset(0)
        MapStyle.set(MapStyle.Clear)
      }

      result.success(null)
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping navigation", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleGetRouteFollowingInfo(result: MethodChannel.Result) {
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

  // ==================== BOOKMARKS ====================

  private fun handleCreateBookmark(call: MethodCall, result: MethodChannel.Result) {
    val lat = call.requireDouble("latitude", result) ?: return
    val lon = call.requireDouble("longitude", result) ?: return
    val name = call.argument<String>("name") ?: "Bookmark"

    val bookmark = BookmarkManager.INSTANCE.addNewBookmark(lat, lon)
    if (bookmark != null) {
      val colorIndex = bookmark.icon?.color ?: BookmarkManager.INSTANCE.lastEditedColor
      BookmarkManager.INSTANCE.setBookmarkParams(
        bookmark.bookmarkId, name, colorIndex,
        call.argument<String>("description") ?: ""
      )
      result.success(bookmark.bookmarkId.toString())
    } else {
      result.error("ERROR", "Failed to create bookmark", null)
    }
  }

  private fun handleDeleteBookmark(call: MethodCall, result: MethodChannel.Result) {
    val bookmarkId = call.requireLong("bookmarkId", result) ?: return
    BookmarkManager.INSTANCE.deleteBookmark(bookmarkId)
    result.success(null)
  }

  private fun handleGetBookmarks(result: MethodChannel.Result) {
    val bookmarks = mutableListOf<Map<String, Any>>()

    BookmarkManager.INSTANCE.categories.forEach { category ->
      for (i in 0 until category.bookmarksCount) {
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
    val bookmarkId = call.requireLong("bookmarkId", result) ?: return
    BookmarkManager.INSTANCE.showBookmarkOnMap(bookmarkId)
    result.success(null)
  }

  // ==================== TRACK RECORDING ====================

  private fun handleStartTrackRecording(result: MethodChannel.Result) {
    try {
      if (!app.organicmaps.sdk.util.LocationUtils.checkFineLocationPermission(context)) {
        result.error("PERMISSION_DENIED", "Fine location permission required", null)
        return
      }

      if (locationHelper?.isActive != true) locationHelper?.start()

      TrackRecorder.nativeSetEnabled(true)
      TrackRecorder.nativeStartTrackRecording()

      result.success(mapOf(
        "success" to true,
        "isRecording" to TrackRecorder.nativeIsTrackRecordingEnabled()
      ))
    } catch (e: Exception) {
      Log.e(TAG, "Error starting track recording", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleStopTrackRecording(result: MethodChannel.Result) {
    try {
      val wasEmpty = TrackRecorder.nativeIsTrackRecordingEmpty()
      TrackRecorder.nativeStopTrackRecording()

      // Deshabilitar GpsTracker si no estamos navegando
      if (!RoutingController.get().isNavigating) {
        TrackRecorder.nativeSetEnabled(false)
      }

      result.success(mapOf(
        "success" to true,
        "wasEmpty" to wasEmpty
      ))
    } catch (e: Exception) {
      Log.e(TAG, "Error stopping track recording", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleSaveTrack(call: MethodCall, result: MethodChannel.Result) {
    try {
      val name = call.argument<String>("name") ?: "Track ${System.currentTimeMillis()}"

      if (TrackRecorder.nativeIsTrackRecordingEmpty()) {
        result.error("EMPTY_TRACK", "No track data to save", null)
        return
      }

      TrackRecorder.nativeSaveTrackRecordingWithName(name)
      result.success(mapOf("success" to true, "name" to name))
    } catch (e: Exception) {
      Log.e(TAG, "Error saving track", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleIsTrackRecording(result: MethodChannel.Result) {
    try {
      val isRecording = TrackRecorder.nativeIsTrackRecordingEnabled()
      result.success(mapOf(
        "isRecording" to isRecording,
        "isEmpty" to if (isRecording) TrackRecorder.nativeIsTrackRecordingEmpty() else true,
        "isGpsTrackerEnabled" to TrackRecorder.nativeIsEnabled()
      ))
    } catch (e: Exception) {
      Log.e(TAG, "Error checking track status", e)
      result.error("ERROR", e.message, null)
    }
  }

  // ==================== UBICACIÓN ====================

  private fun handleSwitchMyPositionMode(result: MethodChannel.Result) {
    safeExecute { LocationState.nativeSwitchToNextMode() }
    result.success(null)
  }

  private fun handleStartLocationUpdates(result: MethodChannel.Result) {
    if (app.organicmaps.sdk.util.LocationUtils.checkLocationPermission(context)) {
      locationHelper?.start()
      result.success(null)
    } else {
      result.error("PERMISSION_DENIED", "Location permissions not granted", null)
    }
  }

  private fun handleStopLocationUpdates(result: MethodChannel.Result) {
    locationHelper?.stop()
    result.success(null)
  }

  private fun handleGetMyPosition(result: MethodChannel.Result) {
    val location = locationHelper?.savedLocation
    if (location != null) {
      result.success(mapOf(
        "latitude" to location.latitude,
        "longitude" to location.longitude,
        "accuracy" to location.accuracy.toDouble(),
        "altitude" to location.altitude,
        "bearing" to location.bearing.toDouble(),
        "speed" to location.speed.toDouble(),
        "timestamp" to location.time
      ))
    } else {
      result.success(null)
    }
  }

  // ==================== CAPAS Y CONFIGURACIÓN ====================

  private fun handleSetTrafficEnabled(call: MethodCall, result: MethodChannel.Result) {
    TrafficManager.INSTANCE.setEnabled(call.argument<Boolean>("enabled") ?: false)
    result.success(null)
  }

  private fun handleSetTransitEnabled(call: MethodCall, result: MethodChannel.Result) {
    Framework.nativeSetTransitSchemeEnabled(call.argument<Boolean>("enabled") ?: false)
    result.success(null)
  }

  private fun handleSetSubwayEnabled(call: MethodCall, result: MethodChannel.Result) {
    SubwayManager.setEnabled(call.argument<Boolean>("enabled") ?: false)
    result.success(null)
  }

  private fun handleSetIsolinesEnabled(call: MethodCall, result: MethodChannel.Result) {
    IsolinesManager.setEnabled(call.argument<Boolean>("enabled") ?: false)
    result.success(null)
  }

  private fun handleSet3dMode(call: MethodCall, result: MethodChannel.Result) {
    val enabled = call.argument<Boolean>("enabled") ?: false
    Framework.nativeSet3dMode(enabled, call.argument<Boolean>("buildings") ?: enabled)
    result.success(null)
  }

  private fun handleSetAutoZoom(call: MethodCall, result: MethodChannel.Result) {
    Framework.nativeSetAutoZoomEnabled(call.argument<Boolean>("enabled") ?: false)
    result.success(null)
  }

  private fun handleSetMapStyle(call: MethodCall, result: MethodChannel.Result) {
    val style = call.argument<String>("style") ?: "defaultLight"
    MapStyle.set(mapStyleFromString(style))
    result.success(null)
  }

  private fun handleGetMapStyle(result: MethodChannel.Result) {
    result.success(mapStyleToString(MapStyle.get()))
  }

  private fun handleCreateMapObject(call: MethodCall, result: MethodChannel.Result) {
    val type = call.requireString("type", result) ?: return
    Editor.nativeCreateMapObject(type)
    result.success(null)
  }

  // ==================== GESTIÓN DE MAPAS ====================

  private fun handleGetCountries(result: MethodChannel.Result) {
    val countries = mutableListOf<CountryItem>()
    val location = locationHelper?.savedLocation

    MapManager.nativeListItems(
      null,
      location?.latitude ?: 0.0,
      location?.longitude ?: 0.0,
      location != null,
      false,
      countries
    )

    val countryMaps = countries.map { country ->
      country.update()
      mapOf(
        "id" to country.id,
        "name" to country.name,
        "parentId" to country.directParentId,
        "sizeBytes" to country.size,
        "totalSizeBytes" to country.totalSize,
        "downloadedBytes" to country.downloadedBytes,
        "bytesToDownload" to country.bytesToDownload,
        "status" to mapStatusToString(country.status),
        "downloadProgress" to country.progress.toInt(),
        "childCount" to country.childCount,
        "totalChildCount" to country.totalChildCount,
        "description" to (country.description ?: ""),
        "present" to country.present
      )
    }

    result.success(countryMaps)
  }

  private fun handleDownloadCountry(call: MethodCall, result: MethodChannel.Result) {
    val countryId = call.requireString("countryId", result) ?: return

    try {
      val connectionState = app.organicmaps.sdk.util.ConnectionState.INSTANCE
      if (!connectionState.isConnected()) {
        result.error("NO_INTERNET", "No internet connection", null)
        return
      }

      // Auto-habilitar datos móviles si es necesario
      if (connectionState.isMobileConnected() && !connectionState.isWifiConnected()) {
        if (!MapManager.nativeIsDownloadOn3gEnabled()) {
          MapManager.nativeEnableDownloadOn3g()
        }
      }

      if (!MapManager.nativeHasSpaceToDownloadCountry(countryId)) {
        result.error("NO_SPACE", "Not enough space", null)
        return
      }

      // Foreground service ANTES de descargar (requerido Android)
      DownloaderService.startForegroundService(context)
      MapManager.startDownload(countryId)

      result.success(mapOf("requiresConfirmation" to false))
    } catch (e: Exception) {
      Log.e(TAG, "Error downloading country", e)
      result.error("ERROR", e.message, null)
    }
  }

  private fun handleDeleteCountry(call: MethodCall, result: MethodChannel.Result) {
    val countryId = call.requireString("countryId", result) ?: return
    MapManager.nativeDelete(countryId)
    result.success(null)
  }

  private fun handleCancelDownload(call: MethodCall, result: MethodChannel.Result) {
    val countryId = call.requireString("countryId", result) ?: return
    MapManager.nativeCancel(countryId)
    result.success(null)
  }

  private fun handleSetMobileDataPolicy(call: MethodCall, result: MethodChannel.Result) {
    if (call.argument<Boolean>("enabled") == true) {
      MapManager.nativeEnableDownloadOn3g()
    }
    result.success(null)
  }

  // ==================== PLACE PAGE ====================

  override fun onPlacePageActivated(data: PlacePageData) {
    if (data is MapObject) {
      postToFlutter("onMapTap", mapOf(
        "latitude" to data.lat,
        "longitude" to data.lon,
        "name" to data.title,
        "address" to data.subtitle
      ))
    }
  }

  override fun onPlacePageDeactivated() {}
  override fun onSwitchFullScreenMode() {}

  // ==================== UTILIDADES ====================

  /** Envía un método al canal de Flutter en el hilo principal. */
  private fun postToFlutter(method: String, arguments: Any?) {
    containerView.post {
      methodChannel.invokeMethod(method, arguments)
    }
  }

  /** Ejecuta un bloque capturando excepciones silenciosamente. */
  private inline fun safeExecute(block: () -> Unit) {
    try {
      block()
    } catch (e: Exception) {
      Log.w(TAG, "Safe execution failed: ${e.message}")
    }
  }

  /** Fuerza el modo FOLLOW_AND_ROTATE ciclando modos si es necesario. */
  private fun forceNavigationMode() {
    safeExecute {
      var currentMode = LocationState.getMode()
      val targetMode = LocationState.FOLLOW_AND_ROTATE
      var attempts = 0

      while (currentMode != targetMode && attempts < 10) {
        LocationState.nativeSwitchToNextMode()
        currentMode = LocationState.getMode()
        attempts++
      }
    }
  }

  // ==================== CONVERSIONES ====================

  private fun mapStatusToString(status: Int): String = when (status) {
    CountryItem.STATUS_DONE -> "downloaded"
    CountryItem.STATUS_PROGRESS, CountryItem.STATUS_APPLYING, CountryItem.STATUS_ENQUEUED, CountryItem.STATUS_PARTLY -> "downloading"
    CountryItem.STATUS_UPDATABLE -> "updateAvailable"
    CountryItem.STATUS_FAILED -> "error"
    else -> "notDownloaded"
  }

  private fun searchTypeToString(type: Int): String = when (type) {
    SearchResult.TYPE_PURE_SUGGEST -> "pure_suggest"
    SearchResult.TYPE_SUGGEST -> "suggest"
    SearchResult.TYPE_RESULT -> "result"
    else -> "unknown"
  }

  private fun routerFromString(type: String): Router = when (type) {
    "pedestrian" -> Router.Pedestrian
    "bicycle" -> Router.Bicycle
    "transit" -> Router.Transit
    else -> Router.Vehicle
  }

  private fun mapStyleFromString(style: String): MapStyle = when (style) {
    "defaultDark" -> MapStyle.Dark
    "vehicleLight" -> MapStyle.VehicleClear
    "vehicleDark" -> MapStyle.VehicleDark
    "outdoorsLight" -> MapStyle.OutdoorsClear
    "outdoorsDark" -> MapStyle.OutdoorsDark
    else -> MapStyle.Clear
  }

  private fun mapStyleToString(style: MapStyle): String = when (style) {
    MapStyle.Dark -> "defaultDark"
    MapStyle.VehicleClear -> "vehicleLight"
    MapStyle.VehicleDark -> "vehicleDark"
    MapStyle.OutdoorsClear -> "outdoorsLight"
    MapStyle.OutdoorsDark -> "outdoorsDark"
    else -> "defaultLight"
  }
}

// ==================== EXTENSIONES ====================

/** Extensión para validar argumentos requeridos de tipo Double. */
private fun MethodCall.requireDouble(key: String, result: MethodChannel.Result): Double? {
  val value = argument<Double>(key)
  if (value == null) {
    result.error("INVALID_ARGS", "$key required", null)
  }
  return value
}

/** Extensión para validar argumentos requeridos de tipo String. */
private fun MethodCall.requireString(key: String, result: MethodChannel.Result): String? {
  val value = argument<String>(key)
  if (value == null) {
    result.error("INVALID_ARGS", "$key required", null)
  }
  return value
}

/** Extensión para validar argumentos requeridos de tipo Long (desde String). */
private fun MethodCall.requireLong(key: String, result: MethodChannel.Result): Long? {
  val value = argument<String>(key)?.toLongOrNull()
  if (value == null) {
    result.error("INVALID_ARGS", "$key required", null)
  }
  return value
}
