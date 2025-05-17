import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/VideoPlayer/Player.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/main.dart';
// import 'package:workmanager/workmanager.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Notification service to handle showing notifications
class NotificationService {
  static final _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      final InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            if (response.payload != null) {
              var data = jsonDecode(response.payload!);
              navigatorKey.currentState!.pushNamed(
                PlayerScreenRoute,
                arguments: [
                  data["url"],
                  data["epishodeName"],
                  data["showImageUrl"],
                  data["epishodesQueue"],
                  data["channel"]
                ],
              );
            }
          } catch (e) {
            print("Error processing notification response: $e");
          }
        },
      );
    } catch (e) {
      print("Error initializing notifications: $e");
      // Rethrow to let caller know initialization failed
      rethrow;
    }
  }

  static Future<void> showDebugNotification(String title, String body) async {
    AndroidNotificationDetails androidDetails =
        const AndroidNotificationDetails(
      'DDebug_CHANNEL',
      'Debug',
      channelDescription: 'Just Debug.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformDetails);
  }

  static Future<void> showNotification(
      String title, String body, String ThumbnailUrl, String? Channel_url,
      {payload}) async {
    var thumimage = await http.readBytes(
      Uri.parse(ThumbnailUrl),
    );
    Uint8List? channelimage;
    if (Channel_url!=null){
      channelimage = await http.readBytes(
        Uri.parse(Channel_url),
      );
    }
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'SUB_CHANNEL',
      'Subscribe channel',
      channelDescription:
          'This will be use to botify you when any new epeshode is available from you subscribe.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      styleInformation: _buildBigPictureStyleInformation(
          title, body, thumimage, channelimage),
      largeIcon: channelimage!=null ? ByteArrayAndroidBitmap(channelimage) : FilePathAndroidBitmap('asserts/logo.png'),
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformDetails,
        payload: payload);
  }

  static BigPictureStyleInformation? _buildBigPictureStyleInformation(
    String title,
    String body,
    Uint8List thumimage,
    Uint8List? channelimage,
  ) {
    return BigPictureStyleInformation(
      ByteArrayAndroidBitmap(thumimage),
      largeIcon: channelimage!=null ? ByteArrayAndroidBitmap(channelimage) : FilePathAndroidBitmap('asserts/logo.png'),
      contentTitle: title,
      htmlFormatContentTitle: true,
      summaryText: body,
      htmlFormatSummaryText: true,
    );
  }
}

var Not_Notify = [];

/// Background fetch task
Future<void> fetchAndShowNotifications() async {
  try {
    var _value = await Localstorage.getData(Localstorage.Subscribe);

    if (_value is! List) {
      return;
    }

    var value =
        Not_Notify.isNotEmpty ? List.from(Not_Notify) : List.from(_value);

    for (var i = 0; i < value.length; i++) {
      var data = jsonDecode(value[i]);
      var notification = await Backend.fetchNotification(data["url"]);

      if (notification["status"]) {
        var allEpisodes = notification["all"] as List;
        var mainData = notification["data"];
        var imageUrl =
            await Backend.scrapeHDImage(data["name"], data["channel"]);
        var channelUrl = await Backend.GoogleSearchImage(
                "${data["channel"]} TV channel LOGO") ??
            "";

        for (var episode in mainData) {
          var currentIndex = allEpisodes.indexOf(episode);
          var episodesQueue =
              allEpisodes.sublist(0, currentIndex == -1 ? 0 : currentIndex);

          await NotificationService.showNotification(
            '"${data["name"]}" - A new episode is now available on ${data["channel"]}.',
            episode["title"].toString().replaceAll(data["name"], ""),
            imageUrl,
            channelUrl,
            payload: jsonEncode({
              "url": episode["url"],
              "epishodeName": episode["title"],
              "showImageUrl": imageUrl,
              "epishodesQueue": episodesQueue,
              "channel": data["channel"],
            }),
          );
          Player.loadVideo(episode["url"]);

          if (Not_Notify.contains(data)) {
            Not_Notify.remove(data);
            if (Not_Notify.isNotEmpty) {
              // Workmanager().cancelByUniqueName("fetchNotificationsTask_v1_1");
              await Localstorage.addIsTodayNotify(DateTime.now().toString());
            }
          }
        }
      } else {
        if (!Not_Notify.contains(data)) {
          Not_Notify.add(jsonEncode(data));
        }
      }
    }
  } catch (e) {
    // Error
  }
}

/// WorkManager callback dispatcher
@pragma('vm:entry-point')
void callbackDispatcher() {
  // Workmanager().executeTask((task, inputData) {
  //   return NotificationService.init().then((_) {
  //     return fetchAndShowNotifications().then((_) {
  //       return Future.value(true);
  //     });
  //   }).catchError((error) {
  //     return Future.value(false);
  //   });
  // });
}

/// Schedule the task dynamically
void scheduleTaskFor6PM() {
  try {
    // Empty function since workmanager is disabled
    print("Background task scheduling disabled");
    
    /* 
    Workmanager().registerPeriodicTask(
      "fetchNotificationsTask_v1_1",
      "fetchNotifications",
      frequency: Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    */
  } catch (e) {
    print("Error in scheduleTaskFor6PM: $e");
  }
}

/// Schedule stop task at 9 PM
void scheduleStopTask() {
  try {
    final now = DateTime.now();
    final stopTime = DateTime(now.year, now.month, now.day, 23, 59); // 9 PM

    final stopDelay = now.isBefore(stopTime)
        ? stopTime.difference(now)
        : Duration(); // If it's already past 9 PM, no delay

    Future.delayed(stopDelay, () {
      // Workmanager().cancelByUniqueName("fetchNotificationsTask_v1_1");
      print("Background task would be stopped here if enabled");
    });
  } catch (e) {
    print("Error in scheduleStopTask: $e");
  }
}
