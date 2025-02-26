import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

const String googleMapsApiKey = "AIzaSyDMX2Xl8EAjMSy1J9iXO9W26E86X5Jlg9k"; // Replace with your API key

class MapsPage extends StatefulWidget {
  @override
  _MapsPageState createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  late GoogleMapController mapController;
  LatLng _currentPosition = LatLng(19.0760, 72.8777); // Default: Mumbai
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _route = [];
  Timer? _journeyTimer;
  int _currentIndex = 0;
  bool _journeyStarted = false;
  List<Prediction> _suggestions = [];

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleMapsApiKey);
  final gmaps.GoogleMapsDirections _directions = gmaps.GoogleMapsDirections(apiKey: googleMapsApiKey);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, return an error message
      print("Location services are disabled.");
      return;
    }

    // Check and request permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are permanently denied, we cannot request permissions.
      print("Location permission permanently denied. Please enable it from settings.");
      return;
    }

    // Fetch current position after permission is granted
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition));
  }


  String _travelTime = ""; // Holds the estimated time

  Future<void> _fetchRoute() async {
    if (_startLocation == null || _endLocation == null) {
      print("Start or End location not set");
      return;
    }

    final response = await _directions.directionsWithLocation(
      gmaps.Location(lat: _startLocation!.latitude, lng: _startLocation!.longitude),
      gmaps.Location(lat: _endLocation!.latitude, lng: _endLocation!.longitude),
      travelMode: gmaps.TravelMode.driving,
    );

    if (response.isOkay && response.routes.isNotEmpty) {
      final route = response.routes[0];
      String durationText = route.legs.first.duration.text;

      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(route.overviewPolyline.points);

      setState(() {
        _route = result.map((point) => LatLng(point.latitude, point.longitude)).toList();
        _travelTime = durationText;
      });

      print("Route fetched successfully with ${_route.length} points.");
    } else {
      print("Failed to fetch route: ${response.status}");
    }
  }



  void _startJourney() {
    if (_journeyStarted || _route.isEmpty) return;
    _journeyStarted = true;
    _currentIndex = 0;

    _journeyTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_currentIndex < _route.length - 1) {
        LatLng nextPosition = _route[_currentIndex + 1];
        _moveCarSmoothly(_currentPosition, nextPosition);
        _currentIndex++;
      } else {
        _stopJourney();
      }
    });
  }

  void _moveCarSmoothly(LatLng start, LatLng end) async {
    const int steps = 10;
    for (int i = 1; i <= steps; i++) {
      double lat = start.latitude + (end.latitude - start.latitude) * (i / steps);
      double lng = start.longitude + (end.longitude - start.longitude) * (i / steps);

      await Future.delayed(Duration(milliseconds: 100));
      setState(() {
        _currentPosition = LatLng(lat, lng);
      });

      mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    }
  }

  void _stopJourney() {
    _journeyTimer?.cancel();
    _journeyStarted = false;
  }

  Future<void> _searchLocation(String query, bool isStart) async {
    final response = await _places.autocomplete(query);

    if (response.isOkay) {
      setState(() {
        _suggestions = response.predictions;
      });
    } else {
      print("Failed to find location: ${response.status}");
    }
  }

  Future<void> _selectLocation(Prediction prediction, bool isStart) async {
    final details = await _places.getDetailsByPlaceId(prediction.placeId!);
    final location = details.result.geometry!.location;
    LatLng newLocation = LatLng(location.lat, location.lng);

    setState(() {
      if (isStart) {
        _startLocation = newLocation;
        _startController.text = details.result.name;
      } else {
        _endLocation = newLocation;
        _endController.text = details.result.name;
      }
      _suggestions = [];
    });

    _fetchRoute();
  }

  @override
  void dispose() {
    _journeyTimer?.cancel();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Navigation")),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 14),
            markers: {
              if (_startLocation != null) Marker(markerId: MarkerId("start"), position: _startLocation!),
              if (_endLocation != null) Marker(markerId: MarkerId("end"), position: _endLocation!),
            },
            polylines: {
              if (_route.isNotEmpty)
                Polyline(
                  polylineId: PolylineId("route"),
                  points: _route,
                  color: Colors.blue,
                  width: 5,
                ),
            },
            myLocationEnabled: true,
          ),

          // Search fields
          Positioned(
            top: 20,
            left: 10,
            right: 10,
            child: Column(
              children: [
                _buildSearchField(_startController, "Enter start location", true),
                SizedBox(height: 10),
                _buildSearchField(_endController, "Enter destination", false),
              ],
            ),
          ),

          if (_suggestions.isNotEmpty)
            Positioned(
              top: 120,
              left: 10,
              right: 10,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: _suggestions.map((prediction) {
                    return ListTile(
                      title: Text(prediction.description!),
                      onTap: () => _selectLocation(prediction, _suggestions.indexOf(prediction) == 0),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(TextEditingController controller, String hint, bool isStart) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(hintText: hint, border: OutlineInputBorder()),
      onChanged: (value) => _searchLocation(value, isStart),
    );
  }
}
