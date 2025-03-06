import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_search/mapbox_search.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'navigation_page.dart'; // Import NavigationPage
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

const String mapboxAccessToken = "sk.eyJ1IjoiYXRoYXJ2YW1wMDQiLCJhIjoiY203bHFkNDE1MGVxNTJscXEydDVzNWI5dSJ9.cYEiC2CRD5kT2dg0r_b9gQ";
const String mapboxDirectionsAPI = "https://api.mapbox.com/directions/v5/mapbox/driving/";

class MapsPage extends StatefulWidget {
  @override
  _MapsPageState createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  Position? _currentPosition;
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _routeCoords = [];
  List<MapBoxPlace> _suggestions = [];
  bool _isSearchingStart = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _currentPosition = position);
    } catch (e) {
      print("Error fetching location: $e");
    }
  }

  Future<void> _getRoute() async {
    if (_startLocation == null || _endLocation == null) return;

    final url = Uri.parse(
        "$mapboxDirectionsAPI${_startLocation!.longitude},${_startLocation!.latitude};"
            "${_endLocation!.longitude},${_endLocation!.latitude}"
            "?alternatives=false&geometries=geojson&steps=false&access_token=$mapboxAccessToken");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _routeCoords = coordinates.map<LatLng>((coord) => LatLng(coord[1], coord[0])).toList();
        });
      } else {
        print("Error fetching route: ${response.statusCode}");
      }
    } catch (e) {
      print("Route API error: $e");
    }
  }

  void _searchLocation(String query, bool isStart) async {
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final placeSearch = PlacesSearch(apiKey: mapboxAccessToken, country: 'IN', language: 'en', limit: 5);
    final results = await placeSearch.getPlaces(query);

    if (results != null) {
      setState(() {
        _suggestions = results;
        _isSearchingStart = isStart;
      });
    }
  }

  void _selectLocation(MapBoxPlace place) {
    setState(() {
      if (_isSearchingStart) {
        _startController.text = place.placeName!;
        _startLocation = LatLng(place.center![1], place.center![0]);
      } else {
        _destinationController.text = place.placeName!;
        _endLocation = LatLng(place.center![1], place.center![0]);
      }
      _suggestions = [];
      _getRoute();
    });
  }

  void _startNavigation() {
    if (_startLocation == null || _endLocation == null) return;

    final WayPoint startPoint = WayPoint(
      name: _startController.text,
      latitude: _startLocation!.latitude,
      longitude: _startLocation!.longitude,
    );

    final WayPoint endPoint = WayPoint(
      name: _destinationController.text,
      latitude: _endLocation!.latitude,
      longitude: _endLocation!.longitude,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationPage(startLocation: startPoint, endLocation: endPoint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mapbox Navigation")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              controller: _startController,
              decoration: const InputDecoration(labelText: "Start Location"),
              onChanged: (value) => _searchLocation(value, true),
            ),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(labelText: "Destination"),
              onChanged: (value) => _searchLocation(value, false),
            ),

            if (_suggestions.isNotEmpty)
              Container(
                height: 200,
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_suggestions[index].placeName!),
                      onTap: () => _selectLocation(_suggestions[index]),
                    );
                  },
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _getRoute,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text("Show Route"),
                ),
                if (_routeCoords.isNotEmpty)
                  ElevatedButton(
                    onPressed: _startNavigation,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: const Text("Start Navigation"),
                  ),
              ],
            ),

            Expanded(
              child: _currentPosition == null
                  ? const Center(child: CircularProgressIndicator())
                  : FlutterMap(
                options: MapOptions(
                  center: _startLocation ?? LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  zoom: 15.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}"
                        "?access_token=$mapboxAccessToken",
                    additionalOptions: {'accessToken': mapboxAccessToken},
                  ),
                  MarkerLayer(
                    markers: [
                      if (_startLocation != null)
                        Marker(
                          point: _startLocation!,
                          width: 40,
                          height: 40,
                          builder: (ctx) => const Icon(Icons.location_pin, color: Colors.green, size: 40),
                        ),
                      if (_endLocation != null)
                        Marker(
                          point: _endLocation!,
                          width: 40,
                          height: 40,
                          builder: (ctx) => const Icon(Icons.location_pin, color: Colors.red, size: 40),
                        ),
                    ],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeCoords,
                        color: Colors.blue,
                        strokeWidth: 5.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
