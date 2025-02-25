import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "https://msgpgdutdgqfnprbgqru.supabase.co/",
    anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1zZ3BnZHV0ZGdxZm5wcmJncXJ1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDA0MjIwMjMsImV4cCI6MjA1NTk5ODAyM30.ro_GXs4E_aDl8iK9EvEUdKtDhJOmgpOUTtvneq_i7yg",
  );

  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Supabase Auth',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthStateHandler(),
    );
  }
}

class AuthStateHandler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final session = Supabase.instance.client.auth.currentSession;
        return session != null ? HomePage() : LoginPage();
      },
    );
  }
}


