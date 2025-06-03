import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';

class Showscreen extends StatefulWidget {
  final String channelName;
  final String showurl;
  final String showtitle;
  final String showimageurl;
  final bool showcompleted;
  final bool isSubscriable;

  const Showscreen(
      {super.key,
      required this.channelName,
      required this.showurl,
      required this.showtitle,
      required this.showimageurl,
      required this.showcompleted,
      this.isSubscriable = true});

  @override
  State<Showscreen> createState() => _ShowscreenState();
}

class _ShowscreenState extends State<Showscreen> {
  bool isloading = true;
  List Episodes = [];
  List pagintition = [];
  String Current_Channel = "";
  String Current_pg_url = "";
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;
  bool isSubscribed = false;

  @override
  void dispose() {
    _subscription.cancel();
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
    Current_pg_url = widget.showurl;
    Localstorage.isSubscribe(jsonEncode({
      "name": widget.showtitle,
      "url": widget.showurl,
      "channel": widget.channelName
    })).then((_is) {
      isSubscribed = _is;
      setState(() {});
    });

    Backend.fetchEpisodes(widget.showurl).then((value) {
      Episodes = value[0];
      pagintition = value[1];
      setState(() {
        isloading = false; // Set loading to false when data is fetched
      });
    }).catchError((error) {
      setState(() {
        isloading = false; // Set loading to false even on error
      });
    });
  }

  // Method to fetch episodes (simulate network call here)
  void fetchEpisodes(String url) {
    setState(() {
      isloading = true;
    });
    Backend.fetchEpisodes(url).then((value) {
      Episodes = value[0];
      pagintition = value[1];
      setState(() {
        isloading = false;
      });
    }).catchError((error) {
      setState(() {
        isloading = false;
      });
    });
  }

  // Method for subscription toggle logic.
  void toggleSubscription() {
    setState(() {
      isSubscribed = !isSubscribed;
    });
    String subData = jsonEncode({
      "name": widget.showtitle,
      "url": widget.showurl,
      "channel": widget.channelName
    });
    if (isSubscribed) {
      Localstorage.addSubscribe(subData);
    } else {
      Localstorage.removeSubscribe(subData);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSubscribed
            ? "Subscribed! You will be notified of new episodes."
            : "Unsubscribed! You will no longer receive notifications."),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double imageHeight = MediaQuery.of(context).size.width * 9 / 16;
    Image image = Image.network(widget.showimageurl);
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        setState(() {
          imageHeight = info.image.height.toDouble(); // Might need scaling
          if (imageHeight > 525) {
            imageHeight = 525;
          }
          else if (imageHeight < 250) {
            imageHeight = 250;
          }
        });
      }),
    );

    return Scaffold(
      // Wrap the whole UI in a CustomScrollView for slivers.
      body: CustomScrollView(
        slivers: [
          // SliverAppBar with flexible space featuring a dynamic image transition.
          SliverAppBar(
            foregroundColor: Colors.white,
            expandedHeight: imageHeight,
            pinned: true,
            // You can set elevation and backgroundColor as desired
            backgroundColor: Colors.blue,
            // Action buttons in the app bar
            actions: widget.isSubscriable
                ? [
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: isSubscribed
                          ? ElevatedButton(
                              onPressed: toggleSubscription,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                color: Color.fromARGB(255, 255, 255, 255),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: toggleSubscription,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.notifications_off,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Subscribe",
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ],
                              ),
                            ),
                    )
                  ]
                : null,
            // The flexible space contains a layout builder to adjust content based on scroll.
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double appBarHeight = constraints.biggest.height;
                final bool isCollapsed = appBarHeight <=
                    (kToolbarHeight + MediaQuery.of(context).padding.top);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Persistent background image
                    CachedNetworkImage(
                      imageUrl: widget.showimageurl,
                      fit: BoxFit.cover,
                    ),
                    // Optional dark overlay for readability
                    Container(color: Colors.black.withOpacity(0.3)),

                    // Title and optional avatar
                    Align(
                      alignment: (isCollapsed)
                          ? Alignment.bottomLeft
                          : Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCollapsed) const SizedBox(width: 40),
                            Text(
                              widget.showtitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: (isCollapsed) ? 18 : 25,
                                shadows: [
                                  const Shadow(
                                      color: Colors.black, blurRadius: 4)
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Optional: SliverToBoxAdapter for non-sliver widgets such as introductory text or banners.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Text(
                "Episodes",
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Handle loading and "no episodes" feedback using another SliverToBoxAdapter.
          if (isloading)
            const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              )),
            )
          else if (Episodes.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "No episodes available.",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => fetchEpisodes(Current_pg_url),
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
              ),
            )
          else
            // SliverList to list out the episodes.
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  final episode = Episodes[index];
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: ListTile(
                      title: Text(
                        episode["title"],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onTap: () {
                        // Navigate to PlayerScreen (pass required arguments)
                        Navigator.pushNamed(
                          context,
                          PlayerScreenRoute,
                          arguments: [
                            episode["url"],
                            episode["title"],
                            widget.showimageurl,
                            Episodes.sublist(0, index)
                                .map((ep) => ep)
                                .toList()
                                .reversed
                                .toList(),
                            widget.channelName
                          ],
                        );
                      },
                    ),
                  );
                },
                childCount: Episodes.length,
              ),
            ),
          // Optional: A SliverToBoxAdapter to display pagination or footer content.
          if (pagintition.isNotEmpty)
            SliverToBoxAdapter(
                child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: pagintition.map((page) {
                    return InkWell(
                      focusColor: Colors.blue.shade400,
                      onTap: page['url'] != null
                          ? () {
                              Current_pg_url = page['url'] ?? Current_pg_url;
                              fetchEpisodes(page['url']);
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 10),
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color:
                              page['current'] ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          page['text'],
                          style: TextStyle(
                            color:
                                page['current'] ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            )),
        ],
      ),
    );
  }
}
