import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/Background.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Routes/Route.dart';
import 'package:serial_stream/Screens/Home.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/pushNotify.dart';
import 'package:workmanager/workmanager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize notifications
  await NotificationService.init();

  // Initialize WorkManager
  Workmanager().initialize(
    callbackDispatcher, // Background task handler
    isInDebugMode: false, // Set true for debugging
  );

  Backend.initialized();

  runApp(const BetterFeedback(child: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool spalse_screen = true;
  @override
  void initState() {
    super.initState();


    scheduleTaskFor6PM();
    Firebase.initializeApp().then((onValue) {
      FirebaseApi().initNotification().then((onValue) {
        FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
                alert: true, badge: true, sound: true)
            .then((onValue) {
          FirebaseMessaging.instance.getInitialMessage().then(
            (value) {
              AwesomeNotifications().initialize(
                null,
                [
                  NotificationChannel(
                    channelKey: 'basic_channel',
                    channelName: 'Foreground Notifications',
                    channelDescription:
                        'Notification channel for basic notifications',
                    defaultColor: const Color(0xFF9D50DD),
                    ledColor: Colors.white,
                    importance: NotificationImportance.High,
                    channelShowBadge: true,
                  ),
                  NotificationChannel(
                    channelKey: 'progress_channel',
                    channelName: 'Foreground Notifications',
                    channelDescription:
                        'Notification channel for downloading progress',
                    defaultColor: const Color.fromARGB(255, 207, 98, 240),
                    ledColor: Colors.white,
                    importance: NotificationImportance.High,
                    channelShowBadge: true,
                  )
                ],
              );
              setState(() {
                spalse_screen = false;
              });
            },
          ).catchError((error) {
            setState(() {
              spalse_screen = false;
            });
          });
        }).catchError((error) {
          setState(() {
            spalse_screen = false;
          });
        });
      }).catchError((error) {
        setState(() {
          spalse_screen = false;
        });
      });
    }).catchError((error) {
      setState(() {
        spalse_screen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return spalse_screen
        ? MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'asserts/logo.png', // Replace with your app icon path
                      width: 100,
                      height: 100,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Serial Stream', // Replace with your app name
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Loading...',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 40),
                    Text(
                      'Made with ❤️ by @somnathdashs',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey),
                    )
                  ],
                ),
              ),
            ))
        : MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateRoute: AppRoutes.generateRoute,
            home: MyHomePage(),
            navigatorKey: navigatorKey,
          );
  }
}
