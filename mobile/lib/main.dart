import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

/// The main application widget for the Music Room app.
class MyApp extends StatelessWidget {
  /// Creates a new instance of [MyApp].
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Music Room'))),
    );
  }
}
