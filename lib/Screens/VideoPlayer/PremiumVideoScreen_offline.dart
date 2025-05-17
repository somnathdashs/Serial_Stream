import 'dart:io';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/main.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

GlobalKey _betterPlayerKey = GlobalKey();

class PremiumVideoScreen_Offline extends StatefulWidget {
  final String videoFilePath;
  final String epishodeName;


  PremiumVideoScreen_Offline({
    required this.videoFilePath,
    required this.epishodeName,
  });
  
  @override
  _PremiumVideoScreen_OfflineScreenState createState() => _PremiumVideoScreen_OfflineScreenState();
}

class _PremiumVideoScreen_OfflineScreenState extends State<PremiumVideoScreen_Offline> with WidgetsBindingObserver {
  late BetterPlayerController _betterPlayerController;
  String EpeDate = "";
  bool AutoPlay = true;

  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Keep screen awake while video is playing
    WakelockPlus.enable();
    
    if (widget.epishodeName.isNotEmpty) {
      // Extract date from the title
      final dateRegex = RegExp(
          r'\b(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4}|\d{4}[-/]\d{1,2}[-/]\d{1,2})\b',
          caseSensitive: false);
      final match = dateRegex.firstMatch(widget.epishodeName);
      if (match != null) {
        final dateString = match
            .group(0)!
            .replaceAll(RegExp(r'(st|nd|rd|th)', caseSensitive: false), '')
            .trim();
        EpeDate = dateString;
      }
    }
    
    // Use file data source for local files
    BetterPlayerDataSource betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      widget.videoFilePath,
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: widget.epishodeName,
        imageUrl: "asserts/logo.png",
        activityName: "Player",
      ),
    );
    
    _betterPlayerController = BetterPlayerController(
        BetterPlayerConfiguration(
          autoPlay: true,
          autoDetectFullscreenDeviceOrientation: true,
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
          ],
          allowedScreenSleep: false, // Prevent screen from sleeping
          handleLifecycle: true, // Handle app lifecycle events
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enableSkips: true,
            enableFullscreen: true,
            enablePlayPause: true,
            enableMute: true,
            enableProgressText: true,
            overflowMenuCustomItems: [
              if (isAdmin) BetterPlayerOverflowMenuItem(
                Icons.share_rounded,
                "Share",
                () async {
                  Share.shareXFiles([XFile(widget.videoFilePath)]);
                },
              ),

              BetterPlayerOverflowMenuItem(
                Icons.picture_in_picture_alt_rounded,
                "Play in PIP mode",
                () async {
                  if (await _betterPlayerController
                      .isPictureInPictureSupported()) {
                    _betterPlayerController
                        .enablePictureInPicture(_betterPlayerKey);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Picture-in-Picture mode is not supported on this device."),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        betterPlayerDataSource: betterPlayerDataSource);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Handle app lifecycle states for better compatibility
    if (state == AppLifecycleState.resumed) {
      // App is visible - ensure wakelock is enabled
      WakelockPlus.enable();
    } else if (state == AppLifecycleState.paused) {
      // App is not visible - can release wakelock if needed
      if (_betterPlayerController.isVideoInitialized() ?? false) {
        if (!(_betterPlayerController.isPlaying() ?? false)) {
          WakelockPlus.disable();
        }
      }
    }
  }

  @override
  void dispose() {
    // Release wakelock when screen is disposed
    WakelockPlus.disable();
    _betterPlayerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.epishodeName),
          bottom: PreferredSize(
              preferredSize: Size(double.minPositive, 15),
              child: Column(
                children: [
                  Text(
                    EpeDate,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 10,
                  )
                ],
              )),
        ),
        body: SafeArea(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: BetterPlayer(
                  key: _betterPlayerKey,
                  controller: _betterPlayerController,
                ),
              ),
            ],
          ),
        ));
  }
}
