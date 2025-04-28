import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:serial_stream/main.dart';

Future<void> updateConnectionStatus(List<ConnectivityResult> results) async {
  if (results.contains(ConnectivityResult.none)) {
    // No internet connection
    navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (context) => const NoInternetScreen()),
    );
  }
}


class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({Key? key}) : super(key: key);

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _subscription =
        _connectivity.onConnectivityChanged.listen(_checkForReconnection);
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _checkForReconnection(List<ConnectivityResult> results) async {
    if (!results.contains(ConnectivityResult.none)) {
      // Reconnected to the internet
      if (mounted) {
        Navigator.pop(context); // Close the "No Internet" screen
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  child: Image.asset(
                    'asserts/nointernet.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  radius: 50.0,
                ),
                const SizedBox(height: 40),
                Text(
                  "No Internet Connection",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "It looks like you're offline.\nPlease check your connection.",
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
                    // Close the app manually
                    SystemNavigator.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
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
