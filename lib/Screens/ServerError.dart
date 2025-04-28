import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serial_stream/Screens/HelpScreen.dart';

class ServerProblemScreen extends StatelessWidget {
  const ServerProblemScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(actions: [IconButton(onPressed: (){
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const HelpScreen(),
          ),
        );
      }, icon: Icon(Icons.help_rounded))],),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  child: Image.network(
                    'https://img.freepik.com/premium-vector/server-error-icon_933463-153140.jpg',
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  radius: 50.0,
                ),
                const SizedBox(height: 40),
                Text(
                  "We're Experiencing Technical Issues",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Our server is currently unavailable. We're working hard to resolve the issue. Please try again later.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    // Logic for retry or navigation
                    SystemNavigator.pop();
                    // Navigator.pop(context); // Close the app manually
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Close App",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
