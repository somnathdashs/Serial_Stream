import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';

class FavoritesScreen extends StatefulWidget {
  final mode;
  const FavoritesScreen({Key? key, this.mode = "Favorites"}) : super(key: key);
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool isGridView = false;
  List shows = [];
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
    Localstorage.getData(widget.mode == "Favorites"
            ? Localstorage.Favorites
            : Localstorage.WatchLater)
        .then((data) {
      if (data == null) {
        setState(() {
          shows = [];
        });
        return;
      }
      setState(() {
        var _shows = data as List<dynamic>;
        shows = _shows.reversed.toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode +
            ((widget.mode == "Favorites") ? ' Shows' : " Web Serise")),
      ),
      body: (shows.isEmpty)
          ? Center(
              child: Text(
                "No shows available here",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : Column(children: [
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
                child: isGridView
                    ? GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
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
            ]),
    );
  }

  Widget _buildShowCard(_show) {
    Map<String, dynamic> show = {};
    if (_show is String) {
      try {
        // Convert the JSON string to a Map<String, dynamic>
        show = jsonDecode(_show);
      } catch (e) {
        // Error decoding JSON
      }
    } else {
      return const Center(child: Text("Error decoding JSON"));
    }
    
    bool isCompleted = show["url"]?.contains("complete") ?? false;
    String Current_Channel = show["channel"] ?? "Unknown Channel";
    return GestureDetector(
        onTap: () async {
          Navigator.pushNamed(
            context,
            EpisodesScreenRoute,
            arguments: [
              Current_Channel,
              show["url"],
              show["title"],
              await Backend.scrapeHDImage(show["title"], Current_Channel),
              isCompleted,
              widget.mode == "Favorites" ? true : false
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
                      future:
                          Backend.scrapeHDImage(show["title"], Current_Channel),
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
                          Current_Channel + " TV CHANNEL Logo ").then((onValue)=> onValue ?? ''),
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
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}
