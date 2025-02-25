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
  LatLng _currentPosition = LatLng(83.4444, 72.8777); // Default: Mumbai
  LatLng? _startLocation;
  LatLng? _endLocation;
  List<LatLng> _route = [];
  Timer? _journeyTimer;
  int _currentIndex = 0;
  bool _journeyStarted = false;
  List<Prediction> _suggestions = [];
  Set<Polyline> _polylines = {}; // Store polyline paths

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleMapsApiKey);
  final gmaps.GoogleMapsDirections _directions =
  gmaps.GoogleMapsDirections(apiKey: googleMapsApiKey);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition, 14));
  }

  Future<void> _fetchRoute() async {
    if (_startLocation == null || _endLocation == null) return;

    final response = await _directions.directionsWithLocation(
      gmaps.Location(lat: _startLocation!.latitude, lng: _startLocation!.longitude),
      gmaps.Location(lat: _endLocation!.latitude, lng: _endLocation!.longitude),
      travelMode: gmaps.TravelMode.driving,
    );

    if (response.isOkay && response.routes.isNotEmpty) {
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(response.routes[0].overviewPolyline.points);

      setState(() {
        _route = result.map((point) => LatLng(point.latitude, point.longitude)).toList();

        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: PolylineId("route"),
            points: _route,
            color: Colors.blue,
            width: 5,
          ),
        );
      });

      // Move camera to show full route
      mapController.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
              _startLocation!.latitude < _endLocation!.latitude
                  ? _startLocation!.latitude
                  : _endLocation!.latitude,
              _startLocation!.longitude < _endLocation!.longitude
                  ? _startLocation!.longitude
                  : _endLocation!.longitude),
          northeast: LatLng(
              _startLocation!.latitude > _endLocation!.latitude
                  ? _startLocation!.latitude
                  : _endLocation!.latitude,
              _startLocation!.longitude > _endLocation!.longitude
                  ? _startLocation!.longitude
                  : _endLocation!.longitude),
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
      });
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
              if (_startLocation != null)
                Marker(markerId: MarkerId("start"), position: _startLocation!),
              if (_endLocation != null)
                Marker(markerId: MarkerId("end"), position: _endLocation!),
              Marker(
                markerId: MarkerId("car"),
                position: _currentPosition,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              ),
            },
            polylines: _polylines,
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

          // Location suggestions list
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
                      onTap: () => _selectLocation(prediction, true),
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
