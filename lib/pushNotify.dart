import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serial_stream/Variable.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> backgroungMessagingHandeler(RemoteMessage RemoteMessage) async {
  final url = RemoteMessage.data['url'];
  if (url != null) {
    await launchUrl(Uri.parse(url));
  }
}

void _handleNotificationClick(RemoteMessage message) {
  final url = message.data['url'];
  if (url != null) {
    launchUrl(Uri.parse(url));
  }
}

class FirebaseApi {
  final _FirebaseMessaging = FirebaseMessaging.instance;
  final _Firebase_in_app_Messaging = FirebaseInAppMessaging.instance;

  Future<void> initNotification() async {
    try {
      // Request notification permission
      await _FirebaseMessaging.requestPermission();

      // Enable resource management
      try {
        await _Firebase_in_app_Messaging.app
            .setAutomaticResourceManagementEnabled(true);
      } catch (e) {
        print("Error enabling resource management: $e");
        // Continue execution even if this fails
      }

      // Get FCM token
      try {
        final fCMToken = await _FirebaseMessaging.getToken();
        print("FCM Token obtained: ${fCMToken?.substring(0, 5)}...");
      } catch (e) {
        print("Error getting FCM token: $e");
        // Continue execution even if token retrieval fails
      }

      // Set up background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(backgroungMessagingHandeler);
      } catch (e) {
        print("Error setting background message handler: $e");
      }

      // Set up foreground message handlers
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationClick(message);
        });

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          _showAwesomeNotification(message);
        });
      } catch (e) {
        print("Error setting up message listeners: $e");
      }

      // Set up awesome notifications
      try {
        AwesomeNotifications().setListeners(
            onActionReceivedMethod: (receivedAction) async {
          if (receivedAction.payload != null &&
              receivedAction.payload!['url'] != null) {
            String url = receivedAction.payload!['url']!;
            _handleNotificationClick(RemoteMessage(data: {"url": url}));
          } else if (receivedAction.payload != null &&
              receivedAction.payload!['apkPath'] != null) {
            String apkPath = receivedAction.payload!['apkPath']!;
            try {
              OpenFilex.open(apkPath);
            } catch (e) {
              print("Error opening APK file: $e");
            }
          }
        });
      } catch (e) {
        print("Error setting up awesome notifications: $e");
      }
    } catch (e) {
      print("Fatal error initializing notifications: $e");
      // Rethrow to inform caller of failure
      rethrow;
    }
  }

  void _showAwesomeNotification(RemoteMessage message) {
    try {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
          channelKey: 'basic_channel',
          title: message.notification?.title ?? 'No Title',
          body: message.notification?.body ?? 'No Body',
          payload: {'url': message.data["url"] ?? ""},
          notificationLayout: NotificationLayout.Default,
        ),
      );
    } catch (e) {
      print("Error showing notification: $e");
    }
  }
}

Future<void> checkAppUpdateWithQuery(BuildContext context,
    {notify = false}) async {
  if (notify) {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Checking for Updates"),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Please wait..."),
            ],
          ),
        );
      },
    );
  }
  final versionsCollection =
      FirebaseFirestore.instance.collection('appVersions');

  final snapshot = await versionsCollection.get();
  if (snapshot.docs.isEmpty) return;

  final packageInfo = await PackageInfo.fromPlatform();
  final currentVersion = packageInfo.version;

  for (var doc in snapshot.docs) {
    final data = doc.data();

    final serverVersion = data['name'] as String?;
    final lastDateTimestamp = data['LastDate'] as Timestamp?;
    final apkUrl = data['url'] as String?;
    final Description = data['des'] as String?;

    if (serverVersion == null || apkUrl == null || lastDateTimestamp == null)
      continue;

    if (serverVersion == currentVersion && notify) {
      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("App is Up-to-Date"),
            content:
                Text("You are already using the latest version of the app."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("OK"),
              ),
            ],
          );
        },
      );
    }

    if ( serverVersion.compareTo(currentVersion) >= 0) {
      if (notify) {
        await showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("Update Available"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("A new version ($serverVersion) is available."),
                  SizedBox(height: 10),
                  Text("Description:"),
                  Text(Description ?? "No description provided."),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Later"),
                ),
                TextButton(
                  onPressed: () async {
                    final directory = await getExternalStorageDirectory();
                    final apkPath = '${directory!.path}/latest_app.apk';
                    final apkFile = File(apkPath);

                    if (!apkFile.existsSync()) {
                      await _downloadApkSilentlyWithProgress(apkUrl, apkFile,
                          onProgress: (received, total) {
                        final progress = ((received / total) * 100).toInt();
                        if (progress == 100) {
                          AwesomeNotifications().dismiss(
                              1564865); // Close the progress notification
                        }
                        AwesomeNotifications().createNotification(
                          content: NotificationContent(
                            id: 1564865,
                            channelKey: 'progress_channel',
                            title: 'Downloading Update',
                            body: 'Downloading... $progress%',
                            notificationLayout: NotificationLayout.ProgressBar,
                            progress: progress.toDouble(),
                          ),
                        );
                      });

                      AwesomeNotifications().createNotification(
                        content: NotificationContent(
                          id: Random().nextInt(100000),
                          channelKey: 'basic_channel',
                          title: 'Download Complete',
                          body: 'Tap to install the update.',
                          payload: {'apkPath': apkFile.path},
                        ),
                      );
                    }

                    if (apkFile.existsSync()) {
                      OpenFilex.open(apkFile.path);
                    } else {
                      AwesomeNotifications()
                          .dismiss(1564865); // Close the progress notification
                      AwesomeNotifications().createNotification(
                        content: NotificationContent(
                          id: Random().nextInt(100000),
                          channelKey: 'basic_channel',
                          title: 'Download Failed',
                          body:
                              'The update could not be downloaded. Please try again.',
                        ),
                      );
                      _launchURL(apkUrl);
                    }
                  },
                  child: Text("Update"),
                ),
              ],
            );
          },
        );
      } else {
        final lastDate = lastDateTimestamp.toDate();
        final isExpired = lastDate.isBefore(DateTime.now());

        final directory = await getExternalStorageDirectory();
        final apkPath = '${directory!.path}/latest_app.apk';
        final apkFile = File(apkPath);

        if (!apkFile.existsSync()) {
          _downloadApkSilentlyWithProgress(apkUrl, apkFile);
        }

        navigateToUpdateScreen(context, isExpired, apkFile, apkUrl);
      }
      break;
    }
  }
}

Future<void> _downloadApkSilentlyWithProgress(String url, File file,
    {onProgress}) async {
  try {
    final request =
        await http.Client().send(http.Request('GET', Uri.parse(url)));
    final contentLength = request.contentLength ?? 0;

    if (request.statusCode == 200) {
      final fileStream = file.openWrite();

      if (onProgress == null) {
        // Direct download without progress tracking
        await request.stream.pipe(fileStream);
      } else {
        int receivedBytes = 0;

        await request.stream.listen((chunk) {
          receivedBytes += chunk.length;
          fileStream.add(chunk);
          onProgress(receivedBytes, contentLength);
        }).asFuture();
      }

      await fileStream.close();
    }
  } catch (e) {
    // APK download failed
  }
}

class UpdateScreen extends StatelessWidget {
  final bool forceUpdate;
  final File apkFile;
  final String fallbackUrl;

  const UpdateScreen({
    Key? key,
    required this.forceUpdate,
    required this.apkFile,
    required this.fallbackUrl,
  }) : super(key: key);

  void _launchURL(BuildContext context) {
    try {
      OpenFilex.open(fallbackUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to launch download page.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("App Update"),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        automaticallyImplyLeading: !forceUpdate,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.system_update_alt_rounded,
                    size: 80,
                    color: Colors.blueAccent,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Update Available",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "A new version of the app is ready. Update now for the best experience!",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.download_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Update Now",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        if (apkFile.existsSync()) {
                          OpenFilex.open(apkFile.path);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  "Failed to download the update. Please download manually."),
                              action: SnackBarAction(
                                label: "Download",
                                onPressed: () => _launchURL(context),
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blueAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!forceUpdate)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Maybe Later"),
                    ),
                  if (forceUpdate)
                    TextButton(
                      onPressed: () => exit(0),
                      child: const Text(
                        "Close App",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void navigateToUpdateScreen(
    BuildContext context, bool forceUpdate, File apkFile, String fallbackUrl) {
  if (forceUpdate) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => UpdateScreen(
          forceUpdate: forceUpdate,
          apkFile: apkFile,
          fallbackUrl: fallbackUrl,
        ),
      ),
    );
  } else {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UpdateScreen(
          forceUpdate: forceUpdate,
          apkFile: apkFile,
          fallbackUrl: fallbackUrl,
        ),
      ),
    );
  }
}

void _launchURL(String url) async {
  try {
    await OpenFilex.open(url);
  } catch (e) {
    // Could not open URL
  }
}
