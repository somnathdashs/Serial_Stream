import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/Variable.dart';
import 'package:video_player/video_player.dart';

GlobalKey _betterPlayerKey = GlobalKey();

class PremiumVideoScreen extends StatefulWidget {
  final String epishodeUrl;
  final String epishodeName;
  final String showImageUrl;
  final String channel;
  final List epishodesQueue;
  final String VideoUrl;

  PremiumVideoScreen(
      {required this.VideoUrl,
      required this.epishodeUrl,
      required this.epishodeName,
      required this.showImageUrl,
      required this.channel,
      required this.epishodesQueue});
  @override
  _PremiumVideoScreenState createState() => _PremiumVideoScreenState();
}

class _PremiumVideoScreenState extends State<PremiumVideoScreen> {
  late BetterPlayerController _betterPlayerController;
  String EpeDate = "";
  bool AutoPlay = true;

  @override
  void initState() {
    super.initState();
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
                  widget.channel
                ],
              );
            }
          },
          autoPlay: true,
          autoDetectFullscreenDeviceOrientation: true,
          controlsConfiguration: BetterPlayerControlsConfiguration(
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
              })
            ],
          ),
        ),
        betterPlayerDataSource: betterPlayerDataSource);
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
        body: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: BetterPlayer(
                key: _betterPlayerKey,
                controller: _betterPlayerController,
              ),
            ),
            const SizedBox(
              height: 70,
            ),
            const Text("Episodes Queues",
                textAlign: TextAlign.start,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(
              height: 30,
            ),
            Expanded(
              child: ListView.builder(
                  itemCount: widget.epishodesQueue.length,
                  itemBuilder: (context, index) {
                    return _buildShowCard(widget.epishodesQueue[index], index);
                  }),
            )
          ],
        ));
  }

  Widget _buildShowCard(Episode, idx) {
    return GestureDetector(
        onTap: () async {
          if (Episode["url"] != null) {
            Navigator.pushReplacementNamed(context, PlayerScreenRoute,
                arguments: [
                  Episode["url"],
                  Episode["title"],
                  widget.showImageUrl,
                  widget.epishodesQueue.sublist(idx + 1),
                  widget.channel,
                ]);
          } else {
            print("No URL found for this episode.");
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
