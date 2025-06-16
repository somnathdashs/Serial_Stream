import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/VideoPlayer/VideoScanner.dart';
import 'package:serial_stream/Screens/VideoPlayer/Player.dart';

class ServersList extends StatefulWidget {
  final String epishodeUrl;
  final String epishodeName;
  final String showImageUrl;
  final String channel;
  final List epishodesQueue;
  const ServersList({
    required this.epishodeUrl,
    required this.epishodeName,
    required this.showImageUrl,
    required this.channel,
    required this.epishodesQueue,
  });

  @override
  State<ServersList> createState() => _ServersListState();
}

class _ServersListState extends State<ServersList> {
  List<String> ServersList = [];
  bool _loading = true;
  bool isVkPrime = false;
  String? VKprimeServerLink;
  String? error;

  Future<void> LoadServers() async {
    try {
      setState(() { 
        error = null;
        _loading = true;
      });
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
          error = "Servers Not Found!";
          _loading = false;
        });
        return;
      }
      ServersList = fetchedUrls;
      for (int i = 0; i < fetchedUrls.length; i++) {
        if (fetchedUrls[i].contains("vkprime")) {
          isVkPrime = true;
          VKprimeServerLink = fetchedUrls[i];
          break;
        }
      }
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        _loading = false;
      });
      return;
    }
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    LoadServers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Servers List'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: LoadServers,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : ServersList.isEmpty
                  ? const Center(
                      child: Text(
                        'No servers available.',
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: ServersList.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                              padding: EdgeInsets.all(25),
                              child: Center(
                                child: Text(
                                  "${widget.epishodeName}",
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ));
                        }
                        final server = ServersList[index - 1];
                        final isVkPrimeServer = server.contains('vkprime');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          child: ListTile(
                            leading: Icon(
                              isVkPrimeServer
                                  ? Icons.star
                                  : Icons.play_circle_outline,
                              color: isVkPrimeServer ? Colors.amber : null,
                            ),
                            title: Text(
                              isVkPrimeServer
                                  ? 'Play Premium Video'
                                  : 'Server ${index}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              isVkPrimeServer
                                  ? "Warning: The premium video might redirect to different content. This occurs because of ad interference."
                                  : server,
                              maxLines: isVkPrimeServer ? 4 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              if (isVkPrimeServer) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Player(
                                          epishodeUrl: widget.epishodeUrl,
                                          epishodeName: widget.epishodeName,
                                          showImageUrl: widget.showImageUrl,
                                          channel: widget.channel,
                                          epishodesQueue:
                                              widget.epishodesQueue),
                                    ));
                                return;
                              }

                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => M3U8WebViewScanner(
                                        initialUrl: server,
                                        epishodeName: widget.epishodeName,
                                        showImageUrl: widget.showImageUrl,
                                        epishodesQueue: widget.epishodesQueue,
                                        channel: widget.channel
                                        ),
                                  ));
                              // Handle server selection
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
