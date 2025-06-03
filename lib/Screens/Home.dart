import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feedback/feedback.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/Background.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/main.dart';
import 'package:serial_stream/pushNotify.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
  });

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isloadiing = true;
  List shows = [];
  bool isGridView = false;
  String Current_Channel = "";
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _connectivity = Connectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      updateConnectionStatus,
    );
    print("isAdmin: $isAdmin");
    checkAppUpdateWithQuery(context);

    _tabController = TabController(length: Channels.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (Channels[_tabController.index]["name"] == "MORE") {
          Navigator.pushNamed(context, MoreWSScreenRoute);
          _tabController.index = _tabController.previousIndex;
          return;
        }
        setState(() {
          Current_Channel = Channels[_tabController.index]["name"] ?? "";
          isloadiing = true; // Set loading to true when tab changes
        });
        Backend.fetchShows(Channels[_tabController.index]["url"] ?? "")
            .then((value) {
          shows = value;
          setState(() {
            isloadiing = false; // Set loading to false when data is fetched
          });
        }).catchError((error) {
          setState(() {
            isloadiing = false; // Set loading to false even on error
          });
        });
      }
    });

    // Trigger initial tab's data fetch
    Current_Channel = Channels[0]["name"] ?? "";
    Backend.fetchShows(Channels[0]["url"] ?? "").then((value) {
      shows = value;
      setState(() {
        isloadiing = false; // Set loading to false when data is fetched
      });
    }).catchError((error) {
      setState(() {
        isloadiing = false; // Set loading to false even on error
      });
    });
    _tabController.addListener(() {
      setState(() {
        Current_Channel = Channels[_tabController.index]["name"] ?? "";
        isloadiing = true; // Set loading to true when tab changes
      });
      Backend.fetchShows(Channels[_tabController.index]["url"] ?? "")
          .then((value) {
        shows = value;
        setState(() {
          isloadiing = false; // Set loading to false when data is fetched
        });
      }).catchError((error) {
        setState(() {
          isloadiing = false; // Set loading to false even on error
        });
      });
    });
  }

  Future<String> writeImageToStorage(Uint8List feedbackScreenshot) async {
    final Directory output = await getTemporaryDirectory();
    final String screenshotFilePath = '${output.path}/feedback.png';
    final File screenshotFile = File(screenshotFilePath);
    await screenshotFile.writeAsBytes(feedbackScreenshot);
    return screenshotFilePath;
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final bool isActive = _tabController.index == index;
    return Tab(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print("isAdmin: $isAdmin");
    // checkAppUpdateWithQuery(context);
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: Text("SERIAL STREAM"),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.help_outline),
              onPressed: () {
                Navigator.pushNamed(context, helpScreenRoute);
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  color: Colors.blue,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                          radius: 50.0,
                          backgroundColor: Colors.transparent,
                          child: Image.asset(
                            'asserts/logo.png',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          )),
                    ),
                    SizedBox(height: 2),
                    const Center(
                      child: Text(
                        "SERIAL STREAM",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.download_rounded),
                title: Text("Downloaded Videos"),
                onTap: () {
                  Navigator.pushNamed(context, DownloadedVideoScreenRoute);
                },
              ),
              ListTile(
                leading: Icon(Icons.favorite),
                title: Text("Favorites"),
                onTap: () {
                  Navigator.pushNamed(context, FavScreenRoute);
                },
              ),
              ListTile(
                leading: Icon(Icons.watch_later_rounded),
                title: Text("Watch Later"),
                onTap: () {
                  Navigator.pushNamed(context, FavScreenRoute,
                      arguments: "Watch Later");
                },
              ),
              ListTile(
                leading: Icon(Icons.feedback),
                title: Text("Feedback"),
                onTap: () {
                  BetterFeedback.of(context).show((feedback) async {
                    // draft an email and send to developer
                    final screenshotFilePath =
                        await writeImageToStorage(feedback.screenshot);
                    final Email email = Email(
                      body: feedback.text,
                      subject: 'Serial Stream App Feedback',
                      recipients: ['somnath.dash.2007@gmail.com'],
                      attachmentPaths: [screenshotFilePath],
                      isHTML: false,
                    );
                    await FlutterEmailSender.send(email);
                  });
                  // Handle Feedback tap
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text("Share with friend"),
                onTap: () {
                  Share.share(
                    'Check out the Serial Stream app! Enjoy the latest serials and web series for free. Download it now and start watching for free! ' +
                        AppUrl,
                    subject: 'Serial Stream App',
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info),
                title: Text("About"),
                onTap: () {
                  Navigator.pushNamed(context, AboutScreenRoute);
                  // Handle About tap
                },
              ),
              SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8.0),
                height: 80,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSocialButton(
                        icon: Icons.telegram,
                        label: 'Telegram',
                        color: Colors.blue,
                        onPressed: () {
                          launchUrl(
                            Uri.parse("https://t.me/serial_stream"),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildSocialButton(
                        icon: Icons.facebook,
                        label: 'Facebook',
                        color: Colors.indigo.shade700,
                        onPressed: () {
                          launchUrl(
                            Uri.parse(
                                "https://www.facebook.com/profile.php?id=61573995827396"),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
            ],
          ),
        ),
        body: Column(
          children: [
            // TabBar at the top
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: List.generate(
                Channels.length,
                (index) => _buildTab(Channels[index]["name"] ?? "", index),
              ),
              indicatorColor: Colors.transparent, // Remove default underline
            ),
            // Toggle button for list/grid view
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.grid_view),
                    onPressed: () {
                      setState(() {
                        isGridView = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.list),
                    onPressed: () {
                      setState(() {
                        isGridView = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            // Content area
            Expanded(
              child: isloadiing
                  ? Center(
                      child: CircularProgressIndicator(),
                    )
                  : (shows.isEmpty)
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                "No shows available.",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isloadiing = true;
                                  });
                                  Backend.fetchShows(
                                          Channels[_tabController.index]
                                                  ["url"] ??
                                              "")
                                      .then((value) {
                                    shows = value;
                                    setState(() {
                                      isloadiing = false;
                                    });
                                  }).catchError((error) {
                                    setState(() {
                                      isloadiing = false;
                                    });
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Try Again",
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        )
                      : isGridView
                          ? GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: (screenWidth >600)? 3:2,
                                crossAxisSpacing:  10,
                                mainAxisSpacing: 10,
                                childAspectRatio: (screenWidth >600)? 1:0.8,
                              ),
                              itemCount: shows.length,
                              itemBuilder: (context, index) {
                                return _buildShowCard(shows[index]);
                              },
                            )
                          : ListView.builder(
                              itemCount: shows.length,
                              itemBuilder: (context, index) {
                                return _buildShowCard(shows[index]);
                              },
                            ),
            ),
          ],
        ));
  }

  Widget _buildShowCard(show) {
    bool isCompleted = show["url"]?.contains("complete") ?? false;

    return InkWell(
      focusColor: Colors.blue.shade400,
      onTap: () async {
        Navigator.pushNamed(
            context,
            EpisodesScreenRoute,
            arguments: [
              Current_Channel,
              show["url"],
              show["title"],
              await Backend.scrapeHDImage(
                show["title"],
                Current_Channel,
              ),
              isCompleted,
              true,
            ],
          );
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
                      future: Backend.scrapeHDImage(
                        show["title"],
                        Current_Channel,
                      ),
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
                            height: 150,
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
                  if (isCompleted)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Completed",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<String>(
                      future: Backend.GoogleSearchImage(
                              Current_Channel + " TV CHANNEL Logo ")
                          .then((onValue) => onValue ?? ""),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[300],
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          );
                        } else if (snapshot.hasError) {
                          return CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[300],
                            child: Icon(
                              Icons.error,
                              color: Colors.red,
                              size: 16,
                            ),
                          );
                        } else {
                          return ClipRRect(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(30),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: snapshot.data!,
                                fit: BoxFit.fill,
                                height: 32,
                                width: 32,
                              ));
                        }
                      },
                    ),
                    SizedBox(
                      width: 15,
                    ),
                    Expanded(
                      child: Text(
                        show["title"],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: (isGridView) ? 1 : 2,
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: Localstorage.isFavorite(jsonEncode({
                        "url": show["url"],
                        "title": show["title"],
                        "channel": Current_Channel,
                      })),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return IconButton(
                            icon: Icon(Icons.favorite_border),
                            onPressed: null,
                          );
                        }
                        bool isFavorite = snapshot.data!;
                        return IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : null,
                          ),
                          onPressed: () {
                            setState(() {
                              if (isFavorite) {
                                Localstorage.removeFavorite(jsonEncode({
                                  "url": show["url"],
                                  "title": show["title"],
                                  "channel": Current_Channel,
                                }));
                              } else {
                                Localstorage.addFavorite(jsonEncode({
                                  "url": show["url"],
                                  "title": show["title"],
                                  "channel": Current_Channel,
                                }));
                              }
                              isFavorite = !isFavorite;
                            });
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
