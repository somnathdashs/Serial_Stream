import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help Guide"),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 237, 133, 133),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Icon(
                Icons.cloud_off,
                size: 80,
                color: Colors.redAccent.shade200,
              ),
              const SizedBox(height: 20),
              const Text(
                "Trouble Connecting to the Server",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "You might face problems like no show loading, no image loading, or a server error message.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.wifi_off, size: 50, color: Colors.blueAccent),
              const SizedBox(height: 10),
              const Text(
                "To solve this:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const BulletPoint(
                text:
                    "Turn off your internet for a while (10 seconds) and then turn it back on.",
              ),
              const BulletPoint(
                text:
                    "For Wi-Fi, turn off your gateway device (turn off the Wi-Fi switch) and turn it back on.",
              ),
              const SizedBox(height: 20),
              const Icon(Icons.alarm, size: 50, color: Colors.amber),
              const SizedBox(height: 10),
              const Text(
                "If the problem persists:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "The server might really be down. Please wait for 12 hours and check the app again.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              const Text(
                "If the problem continues, please contact us through 'Feedback'.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color.fromARGB(137, 31, 85, 235)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulletPoint extends StatelessWidget {
  final String text;

  const BulletPoint({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "\u2022",
          style: TextStyle(fontSize: 20, color: Colors.black54),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
