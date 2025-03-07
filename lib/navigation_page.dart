// import 'package:flutter/material.dart';
// import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';
//
// class NavigationPage extends StatefulWidget {
//   final WayPoint startLocation;
//   final WayPoint endLocation;
//
//   NavigationPage({required this.startLocation, required this.endLocation});
//
//   @override
//   _NavigationPageState createState() => _NavigationPageState();
// }
//
// class _NavigationPageState extends State<NavigationPage> {
//   late MapBoxNavigation _mapBoxNavigation;
//   bool _isNavigating = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _mapBoxNavigation = MapBoxNavigation.instance;
//     _startNavigation();
//   }
//
//   Future<void> _startNavigation() async {
//     await _mapBoxNavigation.startNavigation(
//       wayPoints: [widget.startLocation, widget.endLocation],
//       options: MapBoxOptions(
//         mode: MapBoxNavigationMode.driving,
//         simulateRoute: false,
//         language: "en",
//         units: VoiceUnits.metric,
//       ),
//     );
//
//     setState(() {
//       _isNavigating = true;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text("Navigation")),
//       body: Center(
//         child: _isNavigating ? Text("Navigating...") : CircularProgressIndicator(),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_mapbox_navigation/flutter_mapbox_navigation.dart';

class NavigationPage extends StatefulWidget {
  /// Pass a list of waypoints (start, checkpoints, destination)
  final List<WayPoint> waypoints;

  NavigationPage({required this.waypoints});

  @override
  _NavigationPageState createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  late MapBoxNavigation _mapBoxNavigation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _mapBoxNavigation = MapBoxNavigation.instance;
    _startNavigation();
  }

  Future<void> _startNavigation() async {
    await _mapBoxNavigation.startNavigation(
      wayPoints: widget.waypoints,
      options: MapBoxOptions(
        mode: MapBoxNavigationMode.driving,
        simulateRoute: false,
        language: "en",
        units: VoiceUnits.metric,
      ),
    );

    setState(() {
      _isNavigating = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Navigation")),
      body: Center(
        child: _isNavigating
            ? const Text("Navigating...")
            : const CircularProgressIndicator(),
      ),
    );
  }
}
