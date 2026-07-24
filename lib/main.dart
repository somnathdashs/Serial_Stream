import 'dart:io';
import 'dart:math';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/Background.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Routes/Route.dart';
import 'package:serial_stream/Screens/Home.dart';
import 'package:serial_stream/Screens/VerifyScreen.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/app_theme.dart';
import 'package:serial_stream/pushNotify.dart';
import 'package:serial_stream/services/analytics_service.dart';
import 'package:serial_stream/services/analytics_route_observer.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:device_preview/device_preview.dart';
import 'package:workmanager/workmanager.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// Initialize Analytics Service
final AnalyticsService analyticsService = AnalyticsService();
// Initialize custom route observer
final AnalyticsRouteObserver routeObserver = AnalyticsRouteObserver();
bool isAdmin = false;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase first
    await Firebase.initializeApp();

    // Initialize Firebase Analytics
    final FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    final FirebaseAnalyticsObserver observer =
        FirebaseAnalyticsObserver(analytics: analytics);

    // Initialize notifications
    await NotificationService.init();

    // Initialize other services
    Backend.initialized();
    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerOneOffTask("fetchNotificationsTask_v3", "fetchNotifications");

    // Run the app with error catching
    runApp(DevicePreview(
    enabled: false,
    builder: (context) => BetterFeedback(child: MyApp())));
  } catch (e) {
    // Log error to analytics (will auto-initialize Firebase if needed)
    analyticsService.logError(
        errorType: 'initialization_error',
        errorMessage: e.toString(),
        errorDetails: 'Error occurred during app initialization');

    // Fallback to basic app if initialization fails
    print("Error during app initialization: $e");
    runApp(DevicePreview(
    enabled: false,
    builder: (context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'App failed to initialize properly',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Please restart the application',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    )));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool spalse_screen = true;
  bool initFailed = false;
  DateTime? appStartTime;
  FirebaseAnalyticsObserver? observer;
  bool isVerified = false;

  // For handling app links
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();

    // Load persisted theme preference
    Localstorage.getData('theme_mode').then((val) {
      if (val == 'light') themeNotifier.value = ThemeMode.light;
      else themeNotifier.value = ThemeMode.dark;
    });

    checkVerify().then((value) {
      isVerified = value;
    });

    appStartTime = DateTime.now();
    _initializeAnalyticsObserver();
    analyticsService.logAppOpen();
    analyticsService.logSessionStart();

    try {
      scheduleTaskFor6PM();
    } catch (e) {
      analyticsService.logError(
          errorType: 'schedule_task_error', errorMessage: e.toString());
    }

    initAppLinks();
    _initializeFirebase();
  }

  Future<void> _initializeAnalyticsObserver() async {
    try {
      final analytics = await analyticsService.analytics;
      observer = FirebaseAnalyticsObserver(analytics: analytics);
    } catch (e) {
      print("Error initializing analytics observer: $e");
    }
  }

  // Initialize app_links for handling deep links
  Future<void> initAppLinks() async {
    // Handle app links when app is already running in foreground
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      handleAppLink(uri);
    }, onError: (error) {
      // Handle exception by warning the user
      print('Error handling app link: $error');
      analyticsService.logError(
          errorType: 'app_link_error', errorMessage: error.toString());
    });

    // Handle links that opened the app from terminated state
    try {
      // Getting the initial link that opened the app from the terminated state
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        handleAppLink(initialLink);
      }
    } catch (e) {
      // Handle exception
      print('Error getting initial app link: $e');
      analyticsService.logError(
          errorType: 'initial_app_link_error', errorMessage: e.toString());
    }
  }

  // Process the incoming app link
  void handleAppLink(Uri uri) async {
    analyticsService.logEvent(
        name: 'app_link_received', parameters: {'link': uri.toString()});

    // Handle the specific link format "serialstream://verify=true"
    if (uri.scheme == 'serialstream') {
      final params = uri.queryParameters;

      // Check for verification parameter
      if (uri.toString() == 'serialstream://verify=true' ||
          params['verify'] == 'true' ||
          params['verify'] == true) {
        handleVerification();
      }
      if (uri.toString() == 'serialstream://admin=true' ||
          params['admin'] == 'true' ||
          params['admin'] == true) {
        await Localstorage.setData(Localstorage.isAdmin, true);
        handleVerification();
      }
      if (uri.toString() == 'serialstream://admin=false' ||
          params['admin'] == 'false' ||
          params['admin'] == false) {
        isAdmin = false;
        await Localstorage.setData(Localstorage.isAdmin, false);
      }
      if (uri.toString().startsWith('serialstream://admin=true&screen=') ||
          params['verify'] == 'false' ||
          params['verify'] == false) {
        if (params["screen"].toString().isNotEmpty) {
          Navigator.pushNamed(
              navigatorKey.currentContext!, params["screen"].toString());
        }
      }
    }
    // Handle the specific URL format "https://serial.stream/verify/?v=true"
    else if ((uri.toString().startsWith('@https://serial.stream') ||
        uri.toString().startsWith('https://serial.stream'))) {
      // Check if the path contains 'verify'
      if (uri.path.contains('/verify') || uri.path == '/verify') {
        // Check for v=true in query parameters
        if (uri.queryParameters['v'] == 'true' ||
            uri.queryParameters['verify'] == true) {
          // handleVerification();
        }
      }
    }
  }

  // Handle verification logic
  void handleVerification() {
    analyticsService
        .logEvent(name: 'user_verified', parameters: {'method': 'app_link'});

    set_verify().then((onValue) {
      Navigator.pushReplacementNamed(
          navigatorKey.currentContext!, HomeScreenRoute);
    });
  }

  @override
  void dispose() {
    // Cancel app link subscription
    _linkSubscription?.cancel();

    // Log session end with duration when app is closed
    if (appStartTime != null) {
      final sessionDurationInSeconds =
          DateTime.now().difference(appStartTime!).inSeconds;
      analyticsService.logSessionEnd(durationSeconds: sessionDurationInSeconds);
    }
    super.dispose();
  }

  Future<void> _initializeFirebase() async {
    try {
      // Initialize Firebase first
      await Firebase.initializeApp();

      // Configure analytics data collection
      await analyticsService.setAnalyticsCollectionEnabled(true);

      // Set default parameters for all events
      final analytics = await analyticsService.analytics;

      // Then initialize notification service
      try {
        await FirebaseApi().initNotification();
      } catch (e) {
        print("Error initializing notifications: $e");
        analyticsService.logError(
            errorType: 'notification_init_error', errorMessage: e.toString());
      }

      // Configure notification presentation options
      try {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
                alert: true, badge: true, sound: true);

        // Get initial message
        await FirebaseMessaging.instance.getInitialMessage();

        // Initialize awesome notifications
        await AwesomeNotifications().initialize(
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

        // Log successful notification setup
        analyticsService.logFeatureUse(
            featureName: 'notifications_initialized');
      } catch (e) {
        print("Error setting up Firebase services: $e");
        analyticsService.logError(
            errorType: 'firebase_services_error', errorMessage: e.toString());
      }

      // Update UI state
      if (mounted) {
        setState(() {
          spalse_screen = false;
        });
        // Log successful app load
        analyticsService.logFeatureUse(
            featureName: 'app_loaded_successfully',
            parameters: {
              'load_time_ms':
                  DateTime.now().difference(appStartTime!).inMilliseconds
            });
      }
    } catch (e) {
      print("Firebase initialization error: $e");
      analyticsService.logError(
          errorType: 'firebase_init_error', errorMessage: e.toString());
      if (mounted) {
        setState(() {
          spalse_screen = false;
          initFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<NavigatorObserver> navigatorObservers = [routeObserver];
    final screenSize = MediaQuery.of(context).size;
    final shortestSide = screenSize.shortestSide;
    final aspectRatio = screenSize.width / screenSize.height;
    final bool isAndroidTV =
        Platform.isAndroid && (shortestSide > 600 || aspectRatio > 1.5);

    if (observer != null) navigatorObservers.add(observer!);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, themeMode, _) {
        if (initFailed) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 80, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text('Unable to initialize Firebase',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Please check your connection and restart the app',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        analyticsService.logUserEngagement(
                            engagementType: 'button_click',
                            parameters: {'button': 'retry_firebase_init'});
                        _initializeFirebase();
                      },
                      child: const Text('Retry'),
                    )
                  ],
                ),
              ),
            ),
          );
        }

        if (spalse_screen) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            home: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('asserts/logo.png', width: 100, height: 100),
                    const SizedBox(height: 20),
                    const Text('Serial Stream',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Loading...',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 40),
                    Text('Made with ❤️ by @somnathdashs',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          );
        }

        analyticsService.logScreenView(screenName: 'main_app');
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          onGenerateRoute: AppRoutes.generateRoute,
          home: isAndroidTV
              ? const MyHomePage()
              : (!isVerified ?  VerifyScreen() : const MyHomePage()),
          navigatorKey: navigatorKey,
          navigatorObservers: navigatorObservers,
        );
      },
    );
  }
}
