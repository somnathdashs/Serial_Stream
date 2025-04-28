import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serial_stream/Background.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/pushNotify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:workmanager/workmanager.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String appName = "Serial Stream";
  String version = "0.0.0";
  String buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appName = info.appName;
      version = info.version;
      buildNumber = info.buildNumber;
    });
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Stylish app header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(appName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6D9EFF), Color(0xFF91C9FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            AssetImage('asserts/logo.png'), // Add your app icon
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Version $version',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Info list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCardItem(
                    context,
                    icon: Icons.language,
                    title: 'Visit Website',
                    subtitle: 'somnathdashs.github.io',
                    onTap: () =>
                        _launchURL('https://somnathdashs.github.io/apps/'),
                  ),
                  _buildCardItem(
                    context,
                    icon: Icons.update_rounded,
                    title: 'Check for Updates',
                    subtitle: 'Stay always up-to-date',
                    onTap: () async {
                      checkAppUpdateWithQuery(context, notify: true);
                    },
                  ),
                  _buildCardItem(
                    context,
                    icon: Icons.cached_rounded,
                    title: 'Clear cache',
                    subtitle: 'Clear catch to free up memory.',
                    onTap: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear Cache'),
                          content: const Text(
                              'This will free up storage, but images and videos may take longer to load next time. Do you want to proceed?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        Localstorage.clearData(Localstorage.ImagesUrls);
                        Localstorage.clearData(Localstorage.ShowsCacheMemo);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Cache cleared successfully.')),
                        );
                      }
                    },
                  ),
                  _buildCardItem(
                    context,
                    icon: Icons.email,
                    title: 'Contact Support',
                    subtitle: 'somnath.dash.2007@gmail.com',
                    onTap: () =>
                        _launchURL('mailto:somnath.dash.2007@gmail.com'),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      // Handle the tap event
                      launchUrlString("https://buymeacoffee.com/somnathdash/");
                    },
                    child: Card(
                      elevation: 7,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'asserts/buymeacoffee.png', // Replace with your image path
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Made with ❤️ by @somnathdashs',
                    style:
                        theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardItem(BuildContext context,
      {required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
