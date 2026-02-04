import 'package:flutter/material.dart';
import 'package:organic_maps_flutter/organic_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Organic Maps
  await OrganicMapsFlutter.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Organic Maps Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  OrganicMapController? _controller;
  String _status = 'Inicializando...';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organic Maps Flutter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: OrganicMapView(
              onMapCreated: _onMapCreated,
              compassEnabled: true,
              myLocationEnabled: true,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black87,
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'search',
            onPressed: _searchExample,
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'route',
            onPressed: _routeExample,
            child: const Icon(Icons.directions),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'bookmark',
            onPressed: _bookmarkExample,
            child: const Icon(Icons.bookmark),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(OrganicMapController controller) {
    _controller = controller;
    setState(() {
      _status = 'Mapa listo';
    });

    // Centrar en Madrid
    controller.setCenter(
      latitude: 40.4168,
      longitude: -3.7038,
      zoom: 12,
    );
  }

  Future<void> _searchExample() async {
    if (_controller == null) return;

    setState(() {
      _status = 'Buscando restaurantes...';
    });

    try {
      final results = await _controller!.searchEverywhere('restaurante');
      setState(() {
        _status = 'Encontrados ${results.length} resultados';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en búsqueda: $e';
      });
    }
  }

  Future<void> _routeExample() async {
    if (_controller == null) return;

    setState(() {
      _status = 'Calculando ruta...';
    });

    try {
      final route = await _controller!.buildRoute(
        start: const LatLng(40.4168, -3.7038),
        end: const LatLng(40.4200, -3.7000),
        type: RouterType.vehicle,
      );

      setState(() {
        _status =
            'Ruta: ${route.distanceFormatted} - ${route.durationFormatted}';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en ruta: $e';
      });
    }
  }

  Future<void> _bookmarkExample() async {
    if (_controller == null) return;

    setState(() {
      _status = 'Creando bookmark...';
    });

    try {
      final id = await _controller!.createBookmark(
        latitude: 40.4168,
        longitude: -3.7038,
        name: 'Madrid Centro',
        description: 'Plaza del Sol',
      );

      setState(() {
        _status = 'Bookmark creado: $id';
      });
    } catch (e) {
      setState(() {
        _status = 'Error creando bookmark: $e';
      });
    }
  }
}
