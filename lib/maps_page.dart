import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';




const String mapboxAccessToken = "sk.eyJ1IjoiYXRoYXJ2YW1wMDQiLCJhIjoiY203bHFkNDE1MGVxNTJscXEydDVzNWI5dSJ9.cYEiC2CRD5kT2dg0r_b9gQ";



const String googleMapsApiKey = "AIzaSyDMX2Xl8EAjMSy1J9iXO9W26E86X5Jlg9k"; // Replace with your API key

class MapsPage extends StatefulWidget {
  @override
  _MapsPageState createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  late GoogleMapController _mapController;
  LatLng _currentPosition = LatLng(19.0760, 72.8777); // Default: Mumbai
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _route = [];
  String _travelTime = "";

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleMapsApiKey);
  final gmaps.GoogleMapsDirections _directions = gmaps.GoogleMapsDirections(apiKey: googleMapsApiKey);

  List<Prediction> _suggestions = [];
  bool _searchingForStart = true;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    _mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14));
  }

  Future<void> _fetchRoute() async {
    if (_startLocation == null || _endLocation == null) return;

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

      _mapController.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
              _startLocation!.latitude < _endLocation!.latitude ? _startLocation!.latitude : _endLocation!.latitude,
              _startLocation!.longitude < _endLocation!.longitude ? _startLocation!.longitude : _endLocation!.longitude),
          northeast: LatLng(
              _startLocation!.latitude > _endLocation!.latitude ? _startLocation!.latitude : _endLocation!.latitude,
              _startLocation!.longitude > _endLocation!.longitude ? _startLocation!.longitude : _endLocation!.longitude),
        ),
        100.0,
      ));
    }
  }


  Future<void> _searchLocation(String query, bool isStart) async {
    final response = await _places.autocomplete(query);

    if (response.isOkay) {
      setState(() {
        _suggestions = response.predictions;
        _searchingForStart = isStart;
      });
    }
  }

  Future<void> _selectLocation(Prediction prediction) async {
    final details = await _places.getDetailsByPlaceId(prediction.placeId!);
    final location = details.result.geometry!.location;
    LatLng newLocation = LatLng(location.lat, location.lng);

    setState(() {
      if (_searchingForStart) {
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

  Future<void> _startNavigation() async {
    if (_startLocation == null || _endLocation == null) return;

    MapBoxNavigation.instance.startNavigation(
      wayPoints: [
        WayPoint(name: "Start", latitude: _startLocation!.latitude, longitude: _startLocation!.longitude),
        WayPoint(name: "End", latitude: _endLocation!.latitude, longitude: _endLocation!.longitude),
      ],
      options: MapBoxOptions(
        mode: MapBoxNavigationMode.driving, // Use walking/cycling if needed
        simulateRoute: false, // Set to true for testing
        language: "en",
        units: VoiceUnits.metric,
        // allowUTurnAtWayPoints: true,
        voiceInstructionsEnabled: true, // Enable turn-by-turn voice instructions
        bannerInstructionsEnabled: true,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("In-App Navigation")),
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
              Polyline(
                polylineId: PolylineId("route"),
                points: _route,
                color: Colors.blue,
                width: 5,
              ),
            },
            myLocationEnabled: true,
          ),

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
                      onTap: () => _selectLocation(prediction),
                    );
                  }).toList(),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              children: [
                if (_travelTime.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text("Estimated Time: $_travelTime", style: TextStyle(fontSize: 16)),
                  ),
                SizedBox(height: 10),
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _fetchRoute,
                      child: Text("Show Route"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _startNavigation, // Start turn-by-turn navigation
                      child: Text("Start Navigation"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
                ),

              ],
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
