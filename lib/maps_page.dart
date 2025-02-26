import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:google_maps_webservice/directions.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _travelTime = "";

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final GoogleMapsPlaces _places = GoogleMapsPlaces(apiKey: googleMapsApiKey);
  final gmaps.GoogleMapsDirections _directions = gmaps.GoogleMapsDirections(apiKey: googleMapsApiKey);

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print("Location permission denied.");
        return;
      }
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });

    mapController.animateCamera(CameraUpdate.newLatLng(_currentPosition));
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

      // Zoom to fit the entire route
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
    } else {
      print("Failed to fetch route: ${response.status}");
    }
  }

  Future<void> _searchLocation(String query, bool isStart) async {
    final response = await _places.autocomplete(query);

    if (response.isOkay) {
      setState(() {
        _suggestions = response.predictions;
        _searchingForStart = isStart;
      });
    } else {
      print("Failed to find location: ${response.status}");
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

  Future<void> _openGoogleMapsNavigation() async {
    if (_startLocation == null || _endLocation == null) return;

    final String url =
        "https://www.google.com/maps/dir/?api=1&origin=${_startLocation!.latitude},${_startLocation!.longitude}&destination=${_endLocation!.latitude},${_endLocation!.longitude}&travelmode=driving";

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print("Could not open Google Maps.");
    }
  }

  Future<void> openGoogleMaps() async {
    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&origin=19.2183307,72.9780897&destination=19.1758825,72.95211929999999&travelmode=driving");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      print("Could not open Google Maps.");
    }
  }

  List<Prediction> _suggestions = [];
  bool _searchingForStart = true;

  @override
  void dispose() {
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
                ElevatedButton(
                  onPressed: _openGoogleMapsNavigation,
                  child: Text("Start Navigation"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
