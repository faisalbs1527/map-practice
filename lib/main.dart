import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Map'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Initial location for the map (can be any default position)
  LatLng _currentLocation = LatLng(23.777176, 90.399452);
  LatLng _mapCenter = LatLng(23.777176, 90.399452);
  LatLng? _selectedLocation; // To store the selected location
  List<LatLng> _routePoints = []; // For storing route points
  bool _showRouteButton = false;
  late MapController _mapController;
  bool _showCircle = false;
  double _zoom = 16;
  double _circleRadius = 120; // Initial zoom level
  bool _showSuggestion = false;

  final _controller = TextEditingController();

  List<dynamic> _placeList = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation(); // Fetch location when the app starts
  }

  Future<void> _onSubmit() async {
    setState(() {
      _controller.clear();
      _placeList = [];
      _showSuggestion = false;
    });
  }

  void getSuggestion(String input) async {
    print('Query---------------------------------------> $input');
    const String PLACES_API_KEY =
        "5b3ce3597851110001cf6248236c1ac3f18f47378b0f6ac1697f2549";
    if (input.isEmpty) return;
    try {
      String baseURL = 'https://api.openrouteservice.org/geocode/search';
      String request = '$baseURL?api_key=$PLACES_API_KEY&text=$input&size=5';
      var response = await http.get(Uri.parse(request));
      var data = json.decode(response.body);
      if (kDebugMode) {
        print('mydata');
        print(data);
      }
      if (response.statusCode == 200) {
        setState(() {
          if (input.isNotEmpty) _showSuggestion = true;
          _placeList = json.decode(response.body)['features'];
        });
      } else {
        print("Error fetching suggestions: ${response.body}");
      }
    } catch (e) {
      print(e);
    }
  }

  void _selectLocation(dynamic suggestion) {
    final coordinates = suggestion['geometry']['coordinates'];
    final double lng = coordinates[0];
    final double lat = coordinates[1];

    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _showRouteButton = true;
      _showCircle = false;
      _placeList = [];
    });

    // Move the map to the selected location
    _mapController.move(_selectedLocation!, 16);
  }

  Future<void> _onMyLocationClick() async {
    setState(() {
      _showCircle = true;
    });
    _getCurrentLocation();
  }

  // Function to get current location
  Future<void> _getCurrentLocation() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // If location service is disabled, show an error
      print('Location services are disabled');
      return;
    }

    // Request permission to access location
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print('Location permission denied');
      return;
    }

    // Fetch the current location
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print('Current Position: ${position.latitude}, ${position.longitude}');
    setState(() {
      _currentLocation =
          LatLng(position.latitude, position.longitude); // Update location
    });
    _mapController.move(_currentLocation, _zoom);
  }

  void _zoomIn() {
    setState(() {
      if (_zoom < 18) {
        _zoom += 1;
      }
      _mapController.move(_mapCenter, _zoom); // Recenter and update zoom
    });
  }

  // Function to handle zoom out
  void _zoomOut() {
    setState(() {
      if (_zoom > 2) {
        _zoom -= 1;
      }
      _mapController.move(_mapCenter, _zoom); // Recenter and update zoom
    });
  }

  void _updateMapCenter(LatLng center) {
    setState(() {
      _mapCenter = center;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: _zoom,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _updateMapCenter(position
                        .center); // Update center only when the user interacts
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                if (_showCircle)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _currentLocation,
                        radius: _circleRadius,
                        // Adjust the size of the circle
                        color: Colors.blue.withOpacity(0.3),
                        // Circle color
                        borderColor: Colors.blue,
                        // Border color of the circle
                        borderStrokeWidth: 2, // Border width
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                    if (_selectedLocation != null)
                      Marker(
                        point: _selectedLocation!,
                        child: const Icon(
                          Icons.flag,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                  ],
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.blue,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
              ],
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onSubmitted: (_) => _onSubmit(),
                      onChanged: (value) {
                        getSuggestion(value);
                        setState(() {
                          if (value.isEmpty) {
                            _showSuggestion = false;
                            _placeList = [];
                          }
                        });
                      },
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Search Location",
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  if (_showSuggestion && _placeList.isNotEmpty)
                    Container(
                      color: Colors.white,
                      child: ListView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: _placeList.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () async {
                              _selectLocation(_placeList[index]);
                            },
                            child: ListTile(
                              title: Text(
                                  _placeList[index]["properties"]["label"]),
                            ),
                          );
                        },
                      ),
                    )
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_showRouteButton)
            FloatingActionButton(
              onPressed: _drawRoute,
              heroTag: null,
              child: const Icon(Icons.directions),
            ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _onMyLocationClick, // Location icon on the button
            heroTag: null, // Recenter map on current location
            child: const Icon(
              Icons.my_location,
              size: 28.0,
            ), // Ensure each FAB has a unique hero tag
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton(
                onPressed: _zoomIn,
                heroTag: null, // Zoom in functionality
                child: const Icon(
                  Icons.add,
                  size: 32.0,
                ), // Ensure each FAB has a unique hero tag
              ),
              const SizedBox(width: 10),
              // Zoom Out Button
              FloatingActionButton(
                onPressed: _zoomOut,
                heroTag: null, // Zoom out functionality
                child: const Icon(
                  Icons.remove,
                  size: 32.0,
                ), // Ensure each FAB has a unique hero tag
              ),
            ],
          ),
        ],
      ),
    );
  }
  // Function to draw route
  Future<void> _drawRoute() async {
    if (_selectedLocation == null) return;

    const String ROUTE_API_KEY = '5b3ce3597851110001cf6248236c1ac3f18f47378b0f6ac1697f2549';
    final String baseURL =
        'https://api.openrouteservice.org/v2/directions/driving-car';
    final String request =
        '$baseURL?api_key=$ROUTE_API_KEY&start=${_currentLocation.longitude},${_currentLocation.latitude}&end=${_selectedLocation!.longitude},${_selectedLocation!.latitude}';

    try {
      final response = await http.get(Uri.parse(request));
      if (response.statusCode == 200) {
        final routeData = json.decode(response.body);
        final coordinates =
        routeData['features'][0]['geometry']['coordinates'] as List;
        setState(() {
          _routePoints = coordinates
              .map((point) => LatLng(point[1], point[0]))
              .toList();
        });
        _adjustZoomToRoute();
      } else {
        print('Error fetching route: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Adjust zoom level to fit the route
  void _adjustZoomToRoute() {
    if (_routePoints.isEmpty) return;

    // Calculate the bounds of the route
    double minLat = _routePoints[0].latitude;
    double maxLat = _routePoints[0].latitude;
    double minLng = _routePoints[0].longitude;
    double maxLng = _routePoints[0].longitude;

    for (var point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Create bounds
    LatLngBounds bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );

    // Calculate the zoom level dynamically
    final zoom = _calculateZoom(bounds);

    // Move map to the center and zoom level
    _mapController.move(bounds.center, zoom);
  }

  double _calculateZoom(LatLngBounds bounds) {
    // Calculate the size of the route in terms of the distance between the bounds
    final distance = Geolocator.distanceBetween(
      bounds.southWest.latitude,
      bounds.southWest.longitude,
      bounds.northEast.latitude,
      bounds.northEast.longitude,
    );
    print("distance--------------------------> $distance");

    // Define a base zoom level
    double zoom = 18.0;

    // Adjust the zoom level based on the distance
    if (distance < 5000) {
      zoom = 16.0; // Close-up zoom
    } else if (distance < 6000) {
      zoom = 14.0;
    } else if (distance < 8000) {
      zoom = 12.0;
    } else {
      zoom = 10.0; // Farther zoom
    }

    return zoom;
  }
}
