import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SelectTruckPage extends StatefulWidget {
  final int deliveryId;

  SelectTruckPage({required this.deliveryId});

  @override
  _SelectTruckPageState createState() => _SelectTruckPageState();
}

class _SelectTruckPageState extends State<SelectTruckPage> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _trucks = [];

  @override
  void initState() {
    super.initState();
    _fetchAvailableTrucks();
  }

  Future<void> _fetchAvailableTrucks() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client
          .from('truck')
          .select()
          .eq('status', 'Free')
          .order('truck_id', ascending: true);

      setState(() {
        _trucks = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching trucks: $e')));
    }
  }

  Future<void> _assignTruck(int truckId) async {
    setState(() => _isLoading = true);

    try {
      final timestamp = DateTime.now().toUtc().toIso8601String();

      // Insert into delivery_truck_mapping
      await Supabase.instance.client.from('delivery_truck_mapping').insert({
        'delivery_id': widget.deliveryId,
        'truck_id': truckId,
        'assignment_status': 'Active',
        'assigned_at': timestamp,
        'updated_at': timestamp,
      });

      // Update truck status to 'Busy' and set updated_at timestamp
      await Supabase.instance.client.from('truck').update({
        'status': 'Busy',
        'updated_at': timestamp, // Explicitly update timestamp
      }).eq('truck_id', truckId);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Truck $truckId assigned successfully!")));

      // Refresh the truck list
      _fetchAvailableTrucks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error assigning truck: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select a Truck')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _trucks.isEmpty
          ? Center(child: Text("No available trucks"))
          : ListView.builder(
        itemCount: _trucks.length,
        itemBuilder: (context, index) {
          final truck = _trucks[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: ListTile(
              title: Text("Truck ID: ${truck['truck_id']}"),
              subtitle: Text("Capacity: ${truck['capacity']} tons"),
              trailing: Icon(Icons.local_shipping, color: Colors.blue),
              onTap: () => _assignTruck(truck['truck_id']),
            ),
          );
        },
      ),
    );
  }
}
