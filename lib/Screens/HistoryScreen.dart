import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> historyItems = [];
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _connectivity = Connectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      updateConnectionStatus,
    );
    _loadHistory();
  }

  void _loadHistory() {
    Localstorage.getHistory().then((data) {
      if (mounted) {
        setState(() {
          historyItems = data;
        });
      }
    });
  }

  void _clearAllHistory() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text(
            "Are you sure you want to clear your entire watch history?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Localstorage.clearHistory();
      _loadHistory();
    }
  }

  String _formatDateKey(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final aDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (aDate == today) {
      return "Today";
    } else if (aDate == yesterday) {
      return "Yesterday";
    } else {
      final months = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
      ];
      return "${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}";
    }
  }

  String _formatTime(DateTime dateTime) {
    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? "PM" : "AM";
    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;
    return "$hour:$minute $period";
  }

  Map<DateTime, Map<String, List<WatchHistoryItem>>> _groupHistory() {
    final Map<DateTime, Map<String, List<WatchHistoryItem>>> grouped = {};

    for (final itemStr in historyItems) {
      try {
        final item = WatchHistoryItem.fromJson(itemStr);
        if (item.timestamp <= 0) continue;

        final dt = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
        final dateKey = DateTime(dt.year, dt.month, dt.day);

        grouped.putIfAbsent(dateKey, () => {});
        final showName =
            item.type == "episode" && item.parentShowTitle.isNotEmpty
                ? item.parentShowTitle
                : item.title;

        grouped[dateKey]!.putIfAbsent(showName, () => []);
        grouped[dateKey]![showName]!.add(item);
      } catch (_) {}
    }

    for (final dateKey in grouped.keys) {
      for (final showName in grouped[dateKey]!.keys) {
        grouped[dateKey]![showName]!
            .sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupHistory();
    final sortedDates = groupedData.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Watch History"),
        actions: [
          if (historyItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: "Clear History",
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: (historyItems.isEmpty)
          ? const Center(
              child: Text(
                "No watch history available.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: sortedDates.length,
              itemBuilder: (context, dateIndex) {
                final date = sortedDates[dateIndex];
                final showsMap = groupedData[date]!;
                final sortedShows = showsMap.keys.toList()
                  ..sort((a, b) => showsMap[b]!
                      .first
                      .timestamp
                      .compareTo(showsMap[a]!.first.timestamp));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      child: Text(
                        _formatDateKey(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                    ...sortedShows.map((showName) {
                      final items = showsMap[showName]!;
                      String imageUrl = "";
                      String channel = "";
                      for (final item in items) {
                        if (item.imageUrl.isNotEmpty) imageUrl = item.imageUrl;
                        if (item.channel.isNotEmpty) channel = item.channel;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ExpansionTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: imageUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorWidget: (c, u, e) =>
                                        const Icon(Icons.movie),
                                  )
                                : const Icon(Icons.movie, size: 40),
                          ),
                          title: Text(
                            showName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "$channel • ${items.length} item${items.length > 1 ? 's' : ''}",
                            style: const TextStyle(fontSize: 12),
                          ),
                          children: items.map((item) {
                            final isEpisode = item.type == "episode";
                            final timeStr = _formatTime(
                                DateTime.fromMillisecondsSinceEpoch(
                                    item.timestamp));

                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              leading: Icon(
                                isEpisode
                                    ? Icons.play_circle_fill
                                    : Icons.info_outline,
                                color: isEpisode ? Colors.blue : Colors.green,
                              ),
                              title: Text(
                                isEpisode ? item.title : "View Show Details",
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                "${isEpisode ? 'Watched' : 'Visited'} at $timeStr",
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              onTap: () async {
                                if (isEpisode) {
                                  await Navigator.pushNamed(
                                    context,
                                    PlayerScreenRoute,
                                    arguments: [
                                      item.url,
                                      item.title,
                                      item.imageUrl,
                                      item.epishodesQueue,
                                      item.channel,
                                      item.parentShowTitle,
                                    ],
                                  );
                                } else {
                                  await Navigator.pushNamed(
                                    context,
                                    EpisodesScreenRoute,
                                    arguments: [
                                      item.channel,
                                      item.url,
                                      item.title,
                                      item.imageUrl,
                                      false,
                                      true,
                                    ],
                                  );
                                }
                                _loadHistory();
                              },
                            );
                          }).toList(),
                        ),
                      );
                    }).toList(),
                  ],
                );
              },
            ),
    );
  }
}

class WatchHistoryItem {
  final String type;
  final String url;
  final String title;
  final String parentShowTitle;
  final String imageUrl;
  final String channel;
  final int timestamp;
  final List<dynamic> epishodesQueue;

  WatchHistoryItem({
    required this.type,
    required this.url,
    required this.title,
    required this.parentShowTitle,
    required this.imageUrl,
    required this.channel,
    required this.timestamp,
    required this.epishodesQueue,
  });

  factory WatchHistoryItem.fromJson(String jsonStr) {
    final Map<String, dynamic> data = jsonDecode(jsonStr);
    return WatchHistoryItem(
      type: data['type'] ?? '',
      url: data['url'] ?? '',
      title: data['title'] ?? '',
      parentShowTitle: data['parentShowTitle'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      channel: data['channel'] ?? '',
      timestamp: data['timestamp'] ?? 0,
      epishodesQueue: data['epishodesQueue'] ?? [],
    );
  }
}
