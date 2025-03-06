import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'manager_page.dart';
import 'driver_page.dart';
import 'maps_page.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = false;

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
  }

  Future<void> _navigateBasedOnRole(BuildContext context) async {
    setState(() => _isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No user found. Please login again.')));
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('Users')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();  // Instead of `single()`, use `maybeSingle()` to avoid crashing if no data is found

      setState(() => _isLoading = false);

      if (response == null || response['role'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User role not found!')));
        return;
      }

      String role = response['role'];

      if (role == "Manager") {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ManagerPage()));
      } else if (role == "Driver") {
        Navigator.push(context, MaterialPageRoute(builder: (context) => DriverPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role not recognized!')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching role: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () => _navigateBasedOnRole(context),
              child: Text("Go to Role Page"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (context) => MapsPage())),
              child: Text("Open Maps"),
            ),
          ],
        ),
      ),
    );
  }
}
