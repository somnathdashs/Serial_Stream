// import 'dart:async';
// import 'dart:convert';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:serial_stream/Backend.dart';
// import 'package:serial_stream/LocalStorage.dart';
// import 'package:serial_stream/Screens/NoInternetScreen.dart';
// import 'package:serial_stream/Screens/VideoPlayer/Player.dart';
// import 'package:serial_stream/Variable.dart';
// import 'package:webview_flutter/webview_flutter.dart';

// class WebPlayer extends StatefulWidget {
//   final String epishodeUrl;
//   final String epishodeName;
//   final String showImageUrl;
//   final String channel;
//   final List epishodesQueue;

//   WebPlayer({
//     required this.epishodeUrl,
//     required this.epishodeName,
//     required this.showImageUrl,
//     required this.epishodesQueue,
//     required this.channel,
//   });
//   @override
//   State<WebPlayer> createState() => _PlayerState();
// }

// class _PlayerState extends State<WebPlayer> {
//   bool isloadiing = true;
//   String Video_Element = '';
//   List VideoPageUrls = [];
//   var hearder = Backend.Get_a_Header();
//   int videoindex = 0, counter = 0;
//   String iframeSrc = '';
//   String Date = "";

//   WebViewController controller = WebViewController()
//     ..setJavaScriptMode(JavaScriptMode.unrestricted);

//   void LoadVideo() async {
//     counter = 0;
//     List<dynamic> value = [];
//     var showsUrls =
//         await Localstorage.getData(Localstorage.ShowsCacheMemo) ?? "{}";
//     showsUrls = jsonDecode(showsUrls);
//     if (showsUrls.keys.contains(widget.epishodeUrl)) {
//       value = showsUrls[widget.epishodeUrl];
//     } else {
//       Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//               builder: (context) => Player(
//                     epishodeUrl: widget.epishodeUrl,
//                     epishodeName: widget.epishodeName,
//                     showImageUrl: widget.showImageUrl,
//                     epishodesQueue: widget.epishodesQueue,
//                     channel: widget.channel,
//                   )));
//       return;
//     }
//     VideoPageUrls = value;
//     await controller.loadRequest(
//         headers: hearder, Uri.parse(VideoPageUrls[videoindex]));
//     controller.setNavigationDelegate(
//       NavigationDelegate(
//         onNavigationRequest: (NavigationRequest request) {
//           setState(() => counter++);

//           if (counter < 2) {
//             return NavigationDecision.navigate;
//           }
//           return NavigationDecision.prevent;
//         },
//         onProgress: (url) async {
//           final extractediframe = await controller.runJavaScriptReturningResult(
//             """
//               (function() {
//                 document.getElementById('header')?.remove();
//                 var iframe = document.querySelector('td iframe');
//                 if (iframe) {
//                   iframe.style.position = "fixed";
//                   iframe.style.top = "0";
//                   iframe.style.left = "0";
//                   iframe.style.width = "100vw";
//                   iframe.style.height = "100vh";
//                   iframe.style.border = "none"; // Optional: remove borders
//                   iframe.style.zIndex = "9999";
//                   iframe.click()
//                 }

//                 return iframe;
//               })();
//               """,
//           );
//           if (extractediframe.toString().isNotEmpty) {
//             setState(() {
//               iframeSrc = extractediframe.toString();
//             });
//           }
//         },
//       ),
//     );
//   }

//   late final Connectivity _connectivity;
//   late StreamSubscription _subscription;

//   @override
//   void dispose() {
//     _subscription.cancel();
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
//         overlays: SystemUiOverlay.values); // to re-show bars
//     super.dispose();
//   }

//   @override
//   void initState() {
//     // TODO: implement initState
//     super.initState();
//     _connectivity = Connectivity();
//     _subscription = _connectivity.onConnectivityChanged.listen(
//       updateConnectionStatus,
//     );
//     if (widget.epishodeName.isNotEmpty) {
//       // Extract date from the title
//       final dateRegex = RegExp(
//           r'\b(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4}|\d{4}[-/]\d{1,2}[-/]\d{1,2})\b',
//           caseSensitive: false);
//       final match = dateRegex.firstMatch(widget.epishodeName);
//       if (match != null) {
//         final dateString = match
//             .group(0)!
//             .replaceAll(RegExp(r'(st|nd|rd|th)', caseSensitive: false), '')
//             .trim();
//         Date = dateString;
//       }
//     }

//     LoadVideo();
//   }

//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
//         overlays: [SystemUiOverlay.bottom]);
//     return Scaffold(
//         appBar: AppBar(
//           bottom: PreferredSize(
//               preferredSize: Size(double.minPositive, 15),
//               child: Column(
//                 children: [
//                   Text(
//                     Date,
//                     style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(
//                     height: 10,
//                   )
//                 ],
//               )),
//           title: Text(
//             widget.epishodeName,
//             style: TextStyle(fontWeight: FontWeight.bold),
//           ),
//           actions: [
//             (VideoPageUrls.isEmpty)
//                 ? Center()
//                 : Padding(
//                     padding: EdgeInsets.all(5),
//                     child: DropdownButton<int>(
//                       value: videoindex,
//                       icon: Icon(Icons.video_library),
//                       underline: SizedBox(),
//                       onChanged: (int? newIndex) {
//                         if (newIndex != null) {
//                           setState(() {
//                             videoindex = newIndex;
//                             LoadVideo();
//                           });
//                         }
//                       },
//                       items: List.generate(
//                         3,
//                         (index) => DropdownMenuItem<int>(
//                           value: index,
//                           child: Text('Server ${index + 1}'),
//                         ),
//                       ),
//                     ),
//                   )
//           ],
//         ),
//         body: Column(
//           children: [
//             Center(
//               child: SizedBox(
//                 height: 250,
//                 child: WebViewWidget(controller: controller),
//               ),
//             ),
//             const SizedBox(
//               height: 70,
//             ),
//             const Text("Episodes Queues",
//                 textAlign: TextAlign.start,
//                 style: TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black)),
//             const SizedBox(
//               height: 30,
//             ),
//             Expanded(
//               child: ListView.builder(
//                   itemCount: widget.epishodesQueue.length,
//                   itemBuilder: (context, index) {
//                     return _buildShowCard(widget.epishodesQueue[index], index);
//                   }),
//             )
//           ],
//         ));
//   }

//   Widget _buildShowCard(Episode, idx) {
//     return InkWell(
//       focusColor: Colors.blue.shade400,
//         onTap: () async {
//           if (Episode["url"] != null) {
//             Navigator.pushReplacementNamed(context, PlayerScreenRoute,
//                 arguments: [
//                   Episode["url"],
//                   Episode["title"],
//                   widget.showImageUrl,
//                   widget.epishodesQueue.sublist(idx + 1),
//                   widget.channel,
//                 ]);
//           }
//         },
//         child: Card(
//           elevation: 4,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Stack(
//                 children: [
//                   ClipRRect(
//                     borderRadius: const BorderRadius.vertical(
//                       top: Radius.circular(12),
//                     ),
//                     child: FutureBuilder<String>(
//                       future: () async {
//                         return widget.showImageUrl;
//                       }(),
//                       builder: (context, snapshot) {
//                         if (snapshot.connectionState ==
//                             ConnectionState.waiting) {
//                           return Container(
//                             height: 150,
//                             width: double.infinity,
//                             color: Colors.grey[300],
//                             child: const Center(
//                               child: CircularProgressIndicator(),
//                             ),
//                           );
//                         } else if (snapshot.hasError) {
//                           return Container(
//                             height: 120,
//                             width: double.infinity,
//                             color: Colors.grey[300],
//                             child: const Center(
//                               child: Icon(Icons.error, color: Colors.red),
//                             ),
//                           );
//                         } else {
//                           return CachedNetworkImage(
//                             imageUrl: snapshot.data!,
//                             fit: BoxFit.cover,
//                             height: 150,
//                             width: double.infinity,
//                           );
//                         }
//                       },
//                     ),
//                   ),
//                 ],
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text(
//                   Episode["title"],
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//             ],
//           ),
//         ));
//   }
// }
