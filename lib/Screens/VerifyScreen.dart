import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/main.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> checkVerify() async {
  // bool isAdmin = await Localstorage.getData(Localstorage.isAdmin) ?? false;
  // print("isAdmin: $isAdmin");
  if (isAdmin) {
    return true;
  }

  String? lastVerifyDate =
      await Localstorage.getData(Localstorage.LastVerifyDate);
  print("lastVerifyDate: $lastVerifyDate");
  if (lastVerifyDate == null || lastVerifyDate.isEmpty) {
    return false;
  }
  final lastVerifyDate_ = DateTime.parse(lastVerifyDate);
  final now = DateTime.now();
  // Is deffer by 7 days
  final diff = now.difference(lastVerifyDate_);
  return diff.inDays < 7;
}

Future<void> set_verify() async {
  await Localstorage.setData(
      Localstorage.LastVerifyDate, DateTime.now().toString());
}

class VerifyScreen extends StatefulWidget {
  @override
  _VerifyScreenState createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  List<String> servers = [];
  bool loading = true;
  bool tryagain = false;

  Future<bool> getLinks() async {
    final versionsCollection =
        FirebaseFirestore.instance.collection('inAppLinks');
    final snapshot = await versionsCollection.get();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final link = data['url'] as String?;
      if (link != null) {
        try {
          setState(() {
            servers.add(link);
            loading = false;
          });
        } catch (e) {
          print(e);
        }
      }
    }
    if (servers.isEmpty) {
      Navigator.pushReplacementNamed(
          navigatorKey.currentContext!, HomeScreenRoute);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    getLinks().then((value) {
      setState(() {
        tryagain = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.fromARGB(255, 39, 117, 196), Color(0xFFF8D3A7)],
          ),
        ),
        child: (loading)
            ? Center(child: CircularProgressIndicator())
            : (tryagain)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("No links found",
                            style:
                                TextStyle(fontSize: 18, color: Colors.white)),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              loading = true;
                              tryagain = false;
                            });
                            getLinks().then((value) {
                              setState(() {
                                loading = false;
                                tryagain = value;
                              });
                            });
                          },
                          icon: Icon(Icons.refresh),
                          label: Text("Fetch Servers list"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Server Verification \n(Generate server key)',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 16),
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade100,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.vpn_key_rounded,
                                          color: Colors.indigo.shade700,
                                          size: 28,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Generate Server Key',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.indigo.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              'Select a server to connect\nNOTE: Key only validate for 7 days',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),
                                InkWell(
                                  onTap: () {
                                    launchUrl(
                                        Uri.parse(
                                            "https://youtube.com/shorts/3-8oqbTw1Tk"),
                                        mode: LaunchMode.externalApplication);
                                  },
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: Color(0xFFF08231), width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.play_circle_fill_rounded,
                                          color: Color(0xFFF08231),
                                          size: 24,
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Watch Tutorial: How to Generate Server Key',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                Expanded(
                                  child: ListView.builder(
                                    physics: BouncingScrollPhysics(),
                                    itemCount: servers.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.indigo.shade50,
                                              Colors.white
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ],
                                          border: Border.all(
                                            color: Colors.indigo.shade100,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            launchUrl(Uri.parse(servers[index]),
                                                mode: LaunchMode.inAppBrowserView);
                                          },
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.indigo.shade100,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.dns_rounded,
                                                      color: Colors
                                                          .indigo.shade700,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Server ${index + 1}',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors
                                                              .indigo.shade800,
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        'Tap to connect to this server',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 22,
                                                  color: Colors.indigo.shade400,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final uri = Uri.parse("https://t.me/serial_stream");
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode.externalApplication,
                                            );
                                          }
                                        },
                                        icon: Icon(Icons.telegram),
                                        label: Text('Telegram'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 2,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final uri = Uri.parse("https://www.facebook.com/profile.php?id=61573995827396");
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode.externalApplication,
                                            );
                                          }
                                        },
                                        icon: Icon(Icons.facebook),
                                        label: Text('Facebook'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.indigo.shade700,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
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

}
