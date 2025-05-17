import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';

class MoreWSScreen extends StatefulWidget {
  const MoreWSScreen({Key? key}) : super(key: key);

  @override
  _MoreWSScreenState createState() => _MoreWSScreenState();
}

class _MoreWSScreenState extends State<MoreWSScreen>
    with SingleTickerProviderStateMixin {
  List WebSeriseData = [];
  var _tabController;
  bool isGridView = true, isloadiing = true; // Default to grid view
  String Current_Channel = "";
  String Current_Channel_Url = "";
  List Current_Channel_Shows = [];
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;

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
    Backend.extractWebSeriseData().then((data) {
      var NewData = data.sublist(
        8,
      );
      setState(() {
        isloadiing = false;
        WebSeriseData = NewData;
        Current_Channel = WebSeriseData[0]["channel_name"] ?? "";
        Current_Channel_Url = WebSeriseData[0]["channel_image"] ?? "";
        Current_Channel_Shows = WebSeriseData[0]["shows"] as List;
        _tabController = TabController(length: NewData.length, vsync: this);
      });
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() {
            isloadiing = false;
            Current_Channel =
                WebSeriseData[_tabController.index]["channel_name"] ?? "";
            Current_Channel_Url =
                WebSeriseData[_tabController.index]["channel_image"] ?? "";
            Current_Channel_Shows =
                WebSeriseData[_tabController.index]["shows"] as List;
          });
        }
      });
    }).catchError((error) {
      // Error fetching data
    });
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
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
        appBar: AppBar(
          title: const Text('More Contents'),
        ),
        body: isloadiing
            ? Center(
                child: CircularProgressIndicator(),
              )
            : (WebSeriseData.isEmpty)
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
                            Navigator.pushReplacementNamed(
                                context, MoreWSScreenRoute);
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
                : Column(children: [
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabs: List.generate(WebSeriseData.length, (index) {
                        return _buildTab(
                            WebSeriseData[index]["channel_name"] ?? "", index);
                      }),
                      indicatorColor:
                          Colors.transparent, // Remove default underline
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                            constraints: BoxConstraints(maxWidth: 600),
                            child: Column(children: [
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
                                    : (Current_Channel_Shows.isEmpty)
                                        ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                    Backend.fetchShows(Channels[
                                                                    _tabController
                                                                        .index]
                                                                ["url"] ??
                                                            "")
                                                        .then((value) {
                                                      Current_Channel_Shows =
                                                          value;
                                                      setState(() {
                                                        isloadiing = false;
                                                      });
                                                    }).catchError((error) {
                                                      setState(() {
                                                        isloadiing = false;
                                                      });
                                                    });
                                                  },
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 24,
                                                        vertical: 12),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                    ),
                                                  ),
                                                  child: const Text(
                                                    "Try Again",
                                                    style:
                                                        TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : isGridView
                                            ? GridView.builder(
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount:
                                                      (screenWidth >= 500)
                                                          ? 3
                                                          : 2,
                                                  crossAxisSpacing: 8,
                                                  mainAxisSpacing: 8,
                                                  childAspectRatio: 0.8,
                                                ),
                                                itemCount: Current_Channel_Shows
                                                    .length,
                                                itemBuilder: (context, index) {
                                                  return _buildShowCard(
                                                      Current_Channel_Shows[
                                                          index]);
                                                },
                                              )
                                            : ListView.builder(
                                                itemCount: Current_Channel_Shows
                                                    .length,
                                                itemBuilder: (context, index) {
                                                  return _buildShowCard(
                                                      Current_Channel_Shows[
                                                          index]);
                                                },
                                              ),
                              ),
                            ])),
                      ),
                    )
                  ]));
  }

  Widget _buildShowCard(show) {
    bool isCompleted = show["url"]?.contains("complete") ?? false;

    return GestureDetector(
        onTap: () async {
          Navigator.pushNamed(
            context,
            EpisodesScreenRoute,
            arguments: [
              Current_Channel,
              show["link"],
              show["name"],
              await Backend.scrapeHDImage(show["name"],
                  Current_Channel ),
              isCompleted,
              false
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
                        show["name"],
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
                                imageUrl: 
                            snapshot.data!,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<String>(
                      future: Backend.GoogleSearchImage(
                              "${Current_Channel} TV CHANNEL Latest Logo")
                          .then((value) => value ?? ""),
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
                                imageUrl: 
                                snapshot.data!,
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
                        show["name"],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: (isGridView) ? 1 : 2,
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: Localstorage.isWatchLater(jsonEncode({
                        "url": show["link"],
                        "title": show["name"],
                        "channel": Current_Channel,
                      })),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const IconButton(
                            icon: Icon(Icons.watch_later_rounded),
                            onPressed: null,
                          );
                        }
                        bool isFavorite = snapshot.data!;
                        return IconButton(
                          icon: Icon(
                            isFavorite
                                ? Icons.watch_later_rounded
                                : Icons.watch_later_rounded,
                            color: isFavorite
                                ? const Color.fromARGB(255, 54, 149, 244)
                                : null,
                          ),
                          tooltip: isFavorite
                              ? "Remove from Whatch Later"
                              : "Add to Watch Later",
                          onPressed: () {
                            setState(() {
                              if (isFavorite) {
                                Localstorage.removeWatchLater(jsonEncode({
                                  "url": show["link"],
                                  "title": show["name"],
                                  "channel": Current_Channel,
                                }));
                              } else {
                                Localstorage.addWatchLater(jsonEncode({
                                  "url": show["link"],
                                  "title": show["name"],
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
