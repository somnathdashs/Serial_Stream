import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/VideoPlayer/PremiumVideoScreen.dart';
import 'package:serial_stream/Screens/VideoPlayer/WebVideoScreen.dart';
import 'package:serial_stream/UrlExtracterFromVKPrime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class Player extends StatefulWidget {
  final String epishodeUrl;
  final String epishodeName;
  final String showImageUrl;
  final String channel;
  final List epishodesQueue;

  Player({
    required this.epishodeUrl,
    required this.epishodeName,
    required this.showImageUrl,
    required this.channel,
    required this.epishodesQueue,
  });

  static void loadVideo(epishodeUrl) async {
    try {
      List<String> fetchedUrls = [];
      var showsUrls =
          await Localstorage.getData(Localstorage.ShowsCacheMemo) ?? "{}";
      showsUrls = jsonDecode(showsUrls);

      if (showsUrls.keys.contains(epishodeUrl)) {
        fetchedUrls = List<String>.from(showsUrls[epishodeUrl]);
      } else {
        fetchedUrls = await Backend.extractEntryContentUrls(
            epishodeUrl, Backend.Get_a_Header());
        if (fetchedUrls.isNotEmpty) {
          showsUrls[epishodeUrl] = fetchedUrls;
          Localstorage.setData(
              Localstorage.ShowsCacheMemo, jsonEncode(showsUrls));
        }
      }

      if (fetchedUrls.isEmpty) {
        return;
      }

      var vkprimeIndex = -1;
      var videoPageUrls;
      for (int i = 0; i < fetchedUrls.length; i++) {
        if (fetchedUrls[i].contains("vkprime")) {
          videoPageUrls = fetchedUrls.sublist(0, 3);
          videoPageUrls.add(fetchedUrls[i]);
          vkprimeIndex = videoPageUrls.length - 1;
          break;
        }
      }

      if (vkprimeIndex == -1) {
        return;
      }

      var IframSrc = await Backend.extractIframSRC_from_Webpage(
          videoPageUrls[vkprimeIndex], Backend.Get_a_Header());
      if (IframSrc == null) {
        return;
      }

      final extractor = VKPrimeExtractor(
        url: IframSrc,
        onExtracted: (videoUrl) {},
      );

      await extractor.start();
    } catch (e) {
      print("Error loading video: $e");
    }
  }

  @override
  State<Player> createState() => _PlayerState();
}

class _PlayerState extends State<Player> {
  InAppWebViewController? webViewController;
  String? extractedVideoUrl;
  bool isLoading = true;
  bool showRetry = false;
  bool showWebViewOption = false;

  List<String> videoPageUrls = [];
  int vkprimeIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  void _loadVideo() async {
    setState(() {
      isLoading = true;
      showRetry = false;
      showWebViewOption = false;
    });

    try {
      List<String> fetchedUrls = [];
      var showsUrls =
          await Localstorage.getData(Localstorage.ShowsCacheMemo) ?? "{}";
      showsUrls = jsonDecode(showsUrls);

      if (showsUrls.keys.contains(widget.epishodeUrl)) {
        fetchedUrls = List<String>.from(showsUrls[widget.epishodeUrl]);
      } else {
        fetchedUrls = await Backend.extractEntryContentUrls(
            widget.epishodeUrl, Backend.Get_a_Header());
        if (fetchedUrls.isNotEmpty) {
          showsUrls[widget.epishodeUrl] = fetchedUrls;
          Localstorage.setData(
              Localstorage.ShowsCacheMemo, jsonEncode(showsUrls));
        }
      }

      if (fetchedUrls.isEmpty) {
        setState(() {
          showWebViewOption = false;
          showRetry = true;
          isLoading = false;
        });
        return;
      }

      vkprimeIndex = -1;
      for (int i = 0; i < fetchedUrls.length; i++) {
        if (fetchedUrls[i].contains("vkprime")) {
          videoPageUrls = fetchedUrls.sublist(0, 3);
          videoPageUrls.add(fetchedUrls[i]);
          vkprimeIndex = videoPageUrls.length - 1;
          break;
        }
      }

      if (vkprimeIndex == -1) {
        videoPageUrls = fetchedUrls.sublist(0, 3);
        _navigateToFallback();
        return;
      }

      var IframSrc = await Backend.extractIframSRC_from_Webpage(
          videoPageUrls[vkprimeIndex], Backend.Get_a_Header());
      if (IframSrc == null) {
        setState(() {
          showRetry = true;
          showWebViewOption = true;
          isLoading = false;
        });
        return;
      }

      final extractor = VKPrimeExtractor(
        url: IframSrc,
        onExtracted: (videoUrl) {
          if (videoUrl != null) {
            setState(() {
              isLoading = false;
            });
            _navigateToPlayer(videoUrl);
          } else {
            setState(() {
              showRetry = true;
              showWebViewOption = true;
              isLoading = false;
            });
          }
        },
      );

      await extractor.start();
    } catch (e) {
      print("Error loading video: $e");
      setState(() {
        showRetry = true;
        showWebViewOption = true;
        isLoading = false;
      });
    }
  }

  void _navigateToFallback() {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => WebPlayer(
                epishodeUrl: widget.epishodeUrl,
                epishodeName: widget.epishodeName,
                showImageUrl: widget.showImageUrl,
                epishodesQueue: widget.epishodesQueue,
                channel: widget.channel)));
  }

  void _navigateToPlayer(String videoUrl) {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => PremiumVideoScreen(
                VideoUrl: videoUrl,
                epishodeUrl: widget.epishodeUrl,
                epishodeName: widget.epishodeName,
                showImageUrl: widget.showImageUrl,
                channel: widget.channel,
                epishodesQueue: widget.epishodesQueue)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.epishodeName),
        centerTitle: true,
      ),
      body: Center(
        child: isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Fetching premium video...",
                      style: TextStyle(fontSize: 16)),
                ],
              )
            : showRetry
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.redAccent),
                      SizedBox(height: 12),
                      Text("Failed to load premium video.",
                          style: TextStyle(fontSize: 16)),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadVideo,
                        icon: Icon(Icons.refresh, color: Colors.white),
                        label: Text(
                          "Try Again",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                      if (showWebViewOption) ...[
                        SizedBox(height: 12),
                        Text("or"),
                        SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _navigateToFallback(),
                          icon: Icon(Icons.open_in_browser),
                          label: Text("Open in WebView Player"),
                        )
                      ]
                    ],
                  )
                : Text("No video available"),
      ),
    );
  }
}
