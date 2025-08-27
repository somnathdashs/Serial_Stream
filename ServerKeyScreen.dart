import 'package:flutter/material.dart';

class ServerKeyScreen extends StatefulWidget {
  const ServerKeyScreen({Key? key}) : super(key: key);

  @override
  _ServerKeyScreenState createState() => _ServerKeyScreenState();
}

class _ServerKeyScreenState extends State<ServerKeyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Key Screen'),
      ),
      body: const Center(
        child: Text('Server Key Screen Content'),
      ),
    );
  }
}