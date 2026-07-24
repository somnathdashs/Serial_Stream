import 'dart:convert';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter_file_downloader/flutter_file_downloader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serial_stream/Background.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

GlobalKey _betterPlayerKey = GlobalKey();

class PremiumVideoScreen extends StatefulWidget {
  final String epishodeUrl;
  final String epishodeName;
  final String showImageUrl;
  final String channel;
  final List epishodesQueue;
  final String VideoUrl;
  final String? parentShowTitle;

  PremiumVideoScreen(
      {required this.VideoUrl,
      required this.epishodeUrl,
      required this.epishodeName,
      required this.showImageUrl,
      required this.channel,
      required this.epishodesQueue,
      this.parentShowTitle});
  @override
  _PremiumVideoScreenState createState() => _PremiumVideoScreenState();
}

class _PremiumVideoScreenState extends State<PremiumVideoScreen>
    with WidgetsBindingObserver {
  late BetterPlayerController _betterPlayerController;
  String EpeDate = "";
  bool AutoPlay = true;
  int _currentPage = 0;
  static const int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Keep screen awake while video is playing
    WakelockPlus.enable();

    if (widget.epishodeUrl.isNotEmpty) {
      final episodeItem = jsonEncode({
        "type": "episode",
        "url": widget.epishodeUrl,
        "title": widget.epishodeName,
        "imageUrl": widget.showImageUrl,
        "channel": widget.channel,
        "parentShowTitle": widget.parentShowTitle ?? "",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "epishodesQueue": widget.epishodesQueue,
      });
      Localstorage.addHistory(episodeItem);
    }

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
    BetterPlayerDataSource betterPlayerDataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.VideoUrl,
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: widget.epishodeName,
        author: widget.channel,
        imageUrl: widget.showImageUrl,
        activityName: "Player",
      ),
    );
    _betterPlayerController = BetterPlayerController(
        BetterPlayerConfiguration(
          eventListener: (BetterPlayerEvent event) {
            if (event.betterPlayerEventType == BetterPlayerEventType.finished &&
                AutoPlay) {
              if (widget.epishodesQueue.isEmpty) {
                return;
              }
              var NextEpe = widget.epishodesQueue[0];
              var NextEpeQue = widget.epishodesQueue.sublist(
                1,
              );
              Navigator.pushReplacementNamed(
                context,
                PlayerScreenRoute,
                arguments: [
                  NextEpe["url"],
                  NextEpe["title"],
                  widget.showImageUrl,
                  NextEpeQue,
                  widget.channel,
                  widget.parentShowTitle
                ],
              );
            }
          },
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
              BetterPlayerOverflowMenuItem(
                Icons.picture_in_picture_alt_rounded,
                "Play in PIP mode",
                () async {
                  if (await _betterPlayerController
                      .isPictureInPictureSupported()) {
                    _betterPlayerController
                        .enablePictureInPicture(_betterPlayerKey);
                  } else {
                    // await BetterPlayerController.openPictureInPictureSettings();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            "Picture-in-Picture mode is not supported on this device."),
                      ),
                    );
                  }
                },
              ),
              BetterPlayerOverflowMenuItem(
                  CupertinoIcons.play_arrow_solid, "AutoPlay", () {
                setState(() {
                  AutoPlay = !AutoPlay;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AutoPlay ? "AutoPlay Enabled" : "AutoPlay Disabled",
                    ),
                  ),
                );
              }),
              // Download video to app temp folder
              BetterPlayerOverflowMenuItem(
                  CupertinoIcons.download_circle, "Download Video", () {
                FileDownloader.downloadFile(
                  url: widget.VideoUrl,
                  name: widget.epishodeName,
                  downloadDestination: DownloadDestinations.appFiles,
                  notificationType: NotificationType.progressOnly,
                  onDownloadCompleted: (String path) {
                    // Show a snackbar to notify the user
                    NotificationService.showNotification(widget.epishodeName,
                        "Download completed", widget.showImageUrl, null);
                  },
                );
              }),
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
        body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(
                key: _betterPlayerKey,
                controller: _betterPlayerController,
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "More Episodes",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  Row(
                    children: [
                      const Text(
                        "Auto Next",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      Switch(
                        value: AutoPlay,
                        onChanged: (value) {
                          setState(() {
                            AutoPlay = value;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final totalEpisodes = widget.epishodesQueue.length;
                final totalPages = (totalEpisodes / _itemsPerPage).ceil();
                final startIndex = _currentPage * _itemsPerPage;
                final endIndex = (startIndex + _itemsPerPage).clamp(0, totalEpisodes);
                final displayedEpisodes = widget.epishodesQueue.sublist(startIndex, endIndex);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.45,
                      child: displayedEpisodes.isEmpty
                          ? const Center(
                              child: Text(
                                "No more episodes in queue.",
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: displayedEpisodes.length,
                              itemBuilder: (context, index) {
                                return _buildShowCard(displayedEpisodes[index], startIndex + index);
                              },
                            ),
                    ),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                              onPressed: _currentPage > 0
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text(
                              "Page ${_currentPage + 1} of $totalPages",
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.black),
                              onPressed: _currentPage < totalPages - 1
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ));
        }

  Widget _buildShowCard(Episode, idx) {
    return InkWell(
        focusColor: Colors.blue.shade400,
        onTap: () async {
          if (Episode["url"] != null) {
            Navigator.pushReplacementNamed(context, PlayerScreenRoute,
                arguments: [
                  Episode["url"],
                  Episode["title"],
                  widget.showImageUrl,
                  widget.epishodesQueue.sublist(idx + 1),
                  widget.channel,
                  widget.parentShowTitle,
                ]);
          }
        },
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: FutureBuilder<String>(
                      future: () async {
                        return widget.showImageUrl;
                      }(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 150,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return Container(
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey[300],
                            child: const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          );
                        } else {
                          return CachedNetworkImage(
                            imageUrl: snapshot.data!,
                            fit: BoxFit.cover,
                            height: 150,
                            width: double.infinity,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  Episode["title"],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ));
  }
}
