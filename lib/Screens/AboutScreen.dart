import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:serial_stream/Background.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/app_theme.dart';
import 'package:serial_stream/pushNotify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
    final c = AppColors.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: c.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                appName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 2),
                        ),
                        child: const CircleAvatar(
                          radius: 40,
                          backgroundImage: AssetImage('asserts/logo.png'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Version $version',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCardItem(
                    context, c,
                    icon: Icons.language,
                    title: 'Visit Website',
                    subtitle: 'somnathdashs.github.io/serial_stream/',
                    onTap: () => _launchURL('https://somnathdashs.github.io/serial_stream/'),
                  ),
                  _buildCardItem(
                    context, c,
                    icon: Icons.update_rounded,
                    title: 'Check for Updates',
                    subtitle: 'Stay always up-to-date',
                    onTap: () async {
                      checkAppUpdateWithQuery(context, notify: true);
                    },
                  ),
                  _buildCardItem(
                    context, c,
                    icon: Icons.cached_rounded,
                    title: 'Clear cache',
                    subtitle: 'Clear cache to free up memory.',
                    onTap: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: c.card,
                          title: Text('Clear Cache', style: TextStyle(color: c.textPrimary)),
                          content: Text(
                            'This will free up storage, but images and videos may take longer to load next time. Do you want to proceed?',
                            style: TextStyle(color: c.textMuted),
                          ),
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
                          const SnackBar(content: Text('Cache cleared successfully.')),
                        );
                      }
                    },
                  ),
                  _buildCardItem(
                    context, c,
                    icon: Icons.cached_rounded,
                    title: 'Clear Server key',
                    subtitle: 'Clear server key, and regenerate another.',
                    onTap: () async {
                      Localstorage.clearData(Localstorage.LastVerifyDate);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Server key cleared successfully.')),
                      );
                    },
                  ),
                  _buildCardItem(
                    context, c,
                    icon: Icons.email,
                    title: 'Contact Support',
                    subtitle: 'somnath.dash.2007@gmail.com',
                    onTap: () => _launchURL('mailto:somnath.dash.2007@gmail.com'),
                  ),
                  const SizedBox(height: 24),
                  // Buy Me a Coffee button
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          focusColor: c.primary.withValues(alpha: 0.25),
                          hoverColor: c.primary.withValues(alpha: 0.15),
                          onTap: () => launchUrlString('https://buymeacoffee.com/somnathdash/'),
                          child: Card(
                            elevation: 4,
                            color: c.card,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.asset(
                                'asserts/buymeacoffee.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Made with ❤️ by @somnathdashs',
                    style: theme.textTheme.bodyLarge?.copyWith(color: c.textMuted),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, AppColors c, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      color: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      child: ListTile(
        leading: Icon(icon, color: c.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
        subtitle: subtitle != null
            ? Text(subtitle, style: TextStyle(color: c.textMuted))
            : null,
        trailing: Icon(Icons.chevron_right, color: c.textMuted),
        onTap: onTap,
      ),
    );
  }
}
