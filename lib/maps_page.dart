import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
import 'package:geolocator/geolocator.dart';

const String mapboxAccessToken = "sk.eyJ1IjoiYXRoYXJ2YW1wMDQiLCJhIjoiY203bHFkNDE1MGVxNTJscXEydDVzNWI5dSJ9.cYEiC2CRD5kT2dg0r_b9gQ";

class MapsPage extends StatefulWidget {
  @override
  _MapsPageState createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  Position? _currentPosition;
  WayPoint? _startLocation;
  WayPoint? _endLocation;
  late MapBoxNavigation _directions;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _directions = MapBoxNavigation();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _startNavigation() async {
    if (_startLocation != null && _endLocation != null) {
      setState(() {
        _isNavigating = true;
      });

      await _directions.startNavigation(
        wayPoints: [_startLocation!, _endLocation!],
        options: MapBoxOptions(
          mode: MapBoxNavigationMode.driving,
          simulateRoute: false,
          language: "en",
          units: VoiceUnits.metric,
        ),
      );

      setState(() {
        _isNavigating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapbox Navigation")),
      body: Stack(
        children: [
          _currentPosition == null
              ? Center(child: CircularProgressIndicator())
              : FlutterMap(
            options: MapOptions(
              center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  if (_startLocation == null) {
                    _startLocation = WayPoint(name: "Start", latitude: point.latitude, longitude: point.longitude);
                  } else {
                    _endLocation = WayPoint(name: "End", latitude: point.latitude, longitude: point.longitude);
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                "https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=$mapboxAccessToken",
                additionalOptions: {
                  'accessToken': mapboxAccessToken,
                },
              ),
              MarkerLayer(
                markers: [
                  if (_startLocation != null)
                    Marker(
                      point: LatLng(_startLocation!.latitude ?? 0.0, _startLocation!.longitude ?? 0.0),
                      width: 40,
                      height: 40,
                      builder: (ctx) => Icon(Icons.location_pin, color: Colors.green, size: 40),
                    ),
                  if (_endLocation != null)
                    Marker(
                      point: LatLng(_endLocation!.latitude ?? 0.0, _endLocation!.longitude ?? 0.0),
                      width: 40,
                      height: 40,
                      builder: (ctx) => Icon(Icons.location_pin, color: Colors.red, size: 40),
                    ),
                ],
              ),

            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: ElevatedButton(
              onPressed: _startNavigation,
              child: Text(_isNavigating ? "Navigating..." : "Start Navigation"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}
