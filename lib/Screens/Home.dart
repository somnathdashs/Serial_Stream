import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/Background.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/app_theme.dart';
import 'package:serial_stream/main.dart';
import 'package:serial_stream/pushNotify.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _primaryColor = Color(0xFF4338CA);
const _accentColor = Color(0xFF22C55E);

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isloadiing = true;
  List shows = [];
  bool isGridView = true;
  String Current_Channel = "";
  late final Connectivity _connectivity;
  late StreamSubscription _subscription;

  // Cache channel logo futures to avoid recreating on every rebuild
  final Map<String, Future<String?>> _logoFutures = {};

  @override
  void dispose() {
    _subscription.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Localstorage.getData('is_grid_view').then((value) {
      if (value is bool && mounted) {
        setState(() {
          isGridView = value;
        });
      }
    });
    Localstorage.getData(Localstorage.isOpened).then((bools) async {
      final isFirstOpen = bools == null;
      if (isFirstOpen) {
        Navigator.pushNamed(context, EditDnsScreenRoute);
        await Localstorage.updateData(Localstorage.isOpened, "opened");
        await Localstorage.setData(Localstorage.isOpened, "opened");
      }
    });
    _connectivity = Connectivity();
    _subscription =
        _connectivity.onConnectivityChanged.listen(updateConnectionStatus);
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
          isloadiing = true;
        });
        _fetchForTab(_tabController.index).then((value) {
          shows = value;
          setState(() => isloadiing = false);
        }).catchError((Object _) {
          setState(() => isloadiing = false);
        });
      }
    });

    Current_Channel = Channels[0]["name"] ?? "";
    _fetchForTab(0).then((value) {
      shows = value;
      setState(() => isloadiing = false);
    }).catchError((Object _) {
      setState(() => isloadiing = false);
    });

    _tabController.addListener(() {
      setState(() {
        Current_Channel = Channels[_tabController.index]["name"] ?? "";
        isloadiing = true;
      });
      _fetchForTab(_tabController.index).then((value) {
        shows = value;
        setState(() => isloadiing = false);
      }).catchError((Object _) {
        setState(() => isloadiing = false);
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

  Future<List> _fetchForTab(int index) {
    if (Channels[index]["name"] == "Latest") {
      return Backend.fetchLatestEpisodes();
    }
    return Backend.fetchShows(Channels[index]["url"] ?? "");
  }

  /// Returns a cached Future for the channel logo URL.
  Future<String?> _channelLogoFuture(String channel) {
    if (!_logoFutures.containsKey(channel)) {
      _logoFutures[channel] =
          Backend.GoogleSearchImage("$channel TV CHANNEL Logo");
    }
    return _logoFutures[channel]!;
  }

  void _toggleTheme() {
    final isDark = themeNotifier.value == ThemeMode.dark;
    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
    Localstorage.setData('theme_mode', isDark ? 'light' : 'dark');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: _buildAppBar(c),
      drawer: _buildDrawer(c),
      body: Column(
        children: [
          _buildTabBar(c),
          _buildViewToggle(c),
          Expanded(child: _buildContent(screenWidth, c)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppColors c) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 360;
    final isTablet = screenWidth > 600;

    return AppBar(
      backgroundColor: c.surface,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: c.textMuted, size: isTablet ? 26 : 22),
      toolbarHeight: isTablet ? 64 : 56,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'asserts/logo.png',
              width: isTablet ? 30 : (isCompact ? 22 : 26),
              height: isTablet ? 30 : (isCompact ? 22 : 26),
              fit: BoxFit.contain,
            ),
            SizedBox(width: isCompact ? 6 : 8),
            Text(
              "SERIAL STREAM",
              style: TextStyle(
                color: c.textPrimary,
                fontSize: isTablet ? 20 : (isCompact ? 15 : 17),
                fontWeight: FontWeight.w800,
                letterSpacing: isCompact ? 1.0 : 1.5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Theme toggle
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, mode, __) => IconButton(
            iconSize: isTablet ? 24 : 20,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 6),
            constraints: isCompact ? const BoxConstraints(minWidth: 32) : null,
            icon: Icon(
              mode == ThemeMode.dark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: c.textMuted,
            ),
            onPressed: _toggleTheme,
            tooltip: mode == ThemeMode.dark ? "Light mode" : "Dark mode",
          ),
        ),
        IconButton(
          iconSize: isTablet ? 24 : 20,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 6),
          constraints: isCompact ? const BoxConstraints(minWidth: 32) : null,
          icon: Icon(Icons.history_rounded, color: c.textMuted),
          onPressed: () => Navigator.pushNamed(context, HistoryScreenRoute),
          tooltip: "History",
        ),
        IconButton(
          iconSize: isTablet ? 24 : 20,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 6),
          constraints: isCompact ? const BoxConstraints(minWidth: 32) : null,
          icon: Icon(Icons.help_outline_rounded, color: c.textMuted),
          onPressed: () => Navigator.pushNamed(context, helpScreenRoute),
          tooltip: "Help",
        ),
        SizedBox(width: isCompact ? 2 : 6),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: c.border),
      ),
    );
  }

  Widget _buildDrawer(AppColors c) {
    return Drawer(
      backgroundColor: c.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(c),
          const SizedBox(height: 6),
          _buildDrawerTile(Icons.download_rounded, "Downloaded Videos", c, () {
            Navigator.pushNamed(context, DownloadedVideoScreenRoute);
          }),
          _buildDrawerTile(Icons.favorite_rounded, "Favorites", c, () {
            Navigator.pushNamed(context, FavScreenRoute);
          }),
          _buildDrawerTile(Icons.watch_later_rounded, "Watch Later", c, () {
            Navigator.pushNamed(context, FavScreenRoute,
                arguments: "Watch Later");
          }),
          _buildDrawerTile(Icons.history_rounded, "Watch History", c, () {
            Navigator.pushNamed(context, HistoryScreenRoute);
          }),
          _buildDrawerTile(Icons.dns_rounded, "How To Change DNS", c, () {
            Navigator.pushNamed(context, EditDnsScreenRoute);
          }),
          _buildDrawerTile(Icons.feedback_rounded, "Feedback", c, () {
            BetterFeedback.of(context).show((feedback) async {
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
          }),
          _buildDrawerTile(Icons.share_rounded, "Share with Friend", c, () {
            SharePlus.instance.share(ShareParams(
              text:
                  'Check out the Serial Stream app! Watch the latest serials free. $AppUrl',
              subject: 'Serial Stream App',
            ));
          }),
          _buildDrawerTile(Icons.info_rounded, "About", c, () {
            Navigator.pushNamed(context, AboutScreenRoute);
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Divider(color: c.border, height: 1),
          ),
          // Theme switch tile
          _buildThemeSwitchTile(c),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: _buildSocialButton(
                        Icons.telegram, 'Telegram', const Color(0xFF0088CC),
                        () {
                  launchUrl(Uri.parse("https://t.me/serial_stream"),
                      mode: LaunchMode.externalApplication);
                })),
                const SizedBox(width: 10),
                Expanded(
                    child: _buildSocialButton(Icons.facebook_rounded,
                        'Facebook', const Color(0xFF1877F2), () {
                  launchUrl(
                      Uri.parse(
                          "https://www.facebook.com/profile.php?id=61573995827396"),
                      mode: LaunchMode.externalApplication);
                })),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    focusColor: c.primary.withValues(alpha: 0.25),
                    hoverColor: c.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => launchUrl(
                      Uri.parse('https://buymeacoffee.com/somnathdash/'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(AppColors c) {
    // Use MediaQuery for status bar height instead of SafeArea to avoid overflow
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPad + 16, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accentColor, width: 2),
            ),
            child: CircleAvatar(
              radius: 34,
              backgroundColor: Colors.black,
              child: Image.asset('asserts/logo.png', width: 44, height: 44),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "SERIAL STREAM",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
            ),
            child: const Text("Watch Free",
                style: TextStyle(
                    color: _accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile(
      IconData icon, String title, AppColors c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(icon, color: _primaryColor, size: 20),
            const SizedBox(width: 14),
            Text(title,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSwitchTile(AppColors c) {
    return InkWell(
      onTap: _toggleTheme,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              c.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: _primaryColor,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                c.isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
              ),
            ),
            // Toggle switch
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: c.isDark ? _primaryColor : c.border,
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.all(3),
              child: Align(
                alignment:
                    c.isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(AppColors c) {
    return Container(
      color: c.surface,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        tabAlignment: TabAlignment.start,
        tabs: List.generate(
          Channels.length,
          (index) => _buildTab(Channels[index]["name"] ?? "", index, c),
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index, AppColors c) {
    final bool isActive = _tabController.index == index;
    return Tab(
      height: 34,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? _primaryColor : c.border,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : c.textMuted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle(AppColors c) {
    return Container(
      color: c.bg,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _toggleBtn(Icons.grid_view_rounded, true, c),
          const SizedBox(width: 4),
          _toggleBtn(Icons.view_list_rounded, false, c),
        ],
      ),
    );
  }

  Widget _toggleBtn(IconData icon, bool isGrid, AppColors c) {
    final bool active = isGridView == isGrid;
    return InkWell(
      onTap: () {
        setState(() => isGridView = isGrid);
        Localstorage.setData('is_grid_view', isGrid);
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active
              ? _primaryColor.withValues(alpha: 0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: active ? _primaryColor : Colors.transparent),
        ),
        child:
            Icon(icon, color: active ? _primaryColor : c.textMuted, size: 20),
      ),
    );
  }

  Widget _buildContent(double screenWidth, AppColors c) {
    if (isloadiing) return _buildShimmerGrid(screenWidth, c);
    if (shows.isEmpty) return _buildEmptyState(c);
    return isGridView ? _buildGrid(screenWidth, c) : _buildList(c);
  }

  Widget _buildShimmerGrid(double screenWidth, AppColors c) {
    final crossCount = (screenWidth > 600) ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.65,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _shimmerCard(c),
    );
  }

  Widget _shimmerCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Expanded(
              flex: 3,
              child: _shimmerBox(double.infinity, double.infinity, 14, 0, c)),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(double.infinity, 12, 4, 4, c),
                  const SizedBox(height: 6),
                  _shimmerBox(80, 10, 4, 4, c),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h, double tl, double br, AppColors c) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.85),
      duration: const Duration(milliseconds: 800),
      builder: (_, val, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: c.border.withValues(alpha: val),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(tl),
            topRight: Radius.circular(tl),
            bottomLeft: Radius.circular(br),
            bottomRight: Radius.circular(br),
          ),
        ),
      ),
      onEnd: () => setState(() {}),
    );
  }

  Widget _buildEmptyState(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: c.card,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(Icons.tv_off_rounded, size: 44, color: c.textMuted),
          ),
          const SizedBox(height: 18),
          Text("No shows available",
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text("Check your connection and try again",
              style: TextStyle(color: c.textMuted, fontSize: 13)),
          const SizedBox(height: 22),
          InkWell(
            onTap: () {
              setState(() => isloadiing = true);
              _fetchForTab(_tabController.index).then((value) {
                shows = value;
                setState(() => isloadiing = false);
              }).catchError((Object _) {
                setState(() => isloadiing = false);
              });
            },
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primaryColor, Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text("Try Again",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(double screenWidth, AppColors c) {
    final crossCount = (screenWidth > 600) ? 3 : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: shows.length,
      itemBuilder: (context, index) => _buildGridCard(shows[index], c),
    );
  }

  Widget _buildList(AppColors c) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: shows.length,
      itemBuilder: (context, index) => _buildListCard(shows[index], c),
    );
  }

  Widget _buildGridCard(show, AppColors c) {
    final bool isCompleted = show["url"]?.contains("complete") ?? false;
    return InkWell(
      onTap: () async {
        if (Current_Channel == "Latest") {
          print(show["url"]?.replaceAll('/watch-online/', '/'));
        }
        final imageUrl = await Backend.scrapeHDImage(
            show["title"], Current_Channel,
            showUrl: show["url"]);
        if (!mounted) return;
        if (Current_Channel == "Latest") {
          debugPrint("Latesturl: ${show["url"]?.replaceAll('/watch-online/', '/')}");
          await Navigator.pushNamed(context, PlayerScreenRoute, arguments: [
            show["url"]?.replaceAll('/watch-online/', '/'),
            show["title"],
            imageUrl,
            [],
            Current_Channel,
          ]);
        } else {
          await Navigator.pushNamed(context, EpisodesScreenRoute, arguments: [
            Current_Channel,
            show["url"],
            show["title"],
            imageUrl,
            isCompleted,
            true,
          ]);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildShowImage(show, c),
            // Bottom gradient
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 90,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
              ),
            ),
            // Title at bottom
            Positioned(
              bottom: 30,
              left: 8,
              right: 34,
              child: Text(
                show["title"] ?? "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Favorite at bottom-right
            Positioned(
              bottom: 2,
              right: 2,
              child: _buildFavoriteBtn(show, c, small: true),
            ),
            // Channel logo at bottom-left
            Positioned(
              bottom: 8,
              left: 8,
              child: _buildChannelLogoWidget(Current_Channel, small: true),
            ),
            // Completed badge
            if (isCompleted)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Text("✓ Done",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(show, AppColors c) {
    final bool isCompleted = show["url"]?.contains("complete") ?? false;
    return InkWell(
      onTap: () async {
        if (Current_Channel == "Latest") {
          print(show["url"]?.replaceAll('/watch-online/', '/'));
        }
        final imageUrl = await Backend.scrapeHDImage(
            show["title"], Current_Channel,
            showUrl: show["url"]);
        if (!mounted) return;
        if (Current_Channel == "Latest") {
          await Navigator.pushNamed(context, PlayerScreenRoute, arguments: [
            show["url"]?.replaceAll('/watch-online/', '/'),
            show["title"],
            imageUrl,
            [],
            Current_Channel,
          ]);
        } else {
          await Navigator.pushNamed(context, EpisodesScreenRoute, arguments: [
            Current_Channel,
            show["url"],
            show["title"],
            imageUrl,
            isCompleted,
            true,
          ]);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 110,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildShowImage(show, c),
                    if (isCompleted)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text("Done",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    show["title"] ?? "",
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildChannelLogoWidget(Current_Channel, small: true),
                      const SizedBox(width: 6),
                      Text(Current_Channel,
                          style: TextStyle(color: c.textMuted, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            _buildFavoriteBtn(show, c),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildShowImage(show, AppColors c) {
    return FutureBuilder<String>(
      future: Backend.scrapeHDImage(show["title"], Current_Channel,
          showUrl: show["url"]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: c.border,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _primaryColor.withValues(alpha: 0.7)),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return Container(
            color: c.card,
            child:
                Icon(Icons.broken_image_rounded, color: c.textMuted, size: 28),
          );
        }
        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: c.border),
          errorWidget: (_, __, ___) => Container(
            color: c.card,
            child: Icon(Icons.broken_image_rounded, color: c.textMuted),
          ),
        );
      },
    );
  }

  /// Uses cached future so logo only fetches once per channel.
  Widget _buildChannelLogoWidget(String channel, {bool small = false}) {
    final size = small ? 22.0 : 28.0;
    return FutureBuilder<String?>(
      future: _channelLogoFuture(channel),
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (!snapshot.hasData || url == null || url.isEmpty) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            child:
                Icon(Icons.tv_rounded, size: size * 0.5, color: Colors.white70),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: Icon(Icons.tv_rounded,
                  size: size * 0.5, color: Colors.white70),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteBtn(show, AppColors c, {bool small = false}) {
    return FutureBuilder<bool>(
      future: Localstorage.isFavorite(jsonEncode({
        "url": show["url"],
        "title": show["title"],
        "channel": Current_Channel,
      })),
      builder: (context, snapshot) {
        final isFav = snapshot.data ?? false;
        return IconButton(
          iconSize: small ? 18 : 22,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
              minWidth: small ? 28 : 38, minHeight: small ? 28 : 38),
          icon: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav
                ? Colors.redAccent
                : (small ? Colors.white70 : c.textMuted),
          ),
          onPressed: !snapshot.hasData
              ? null
              : () {
                  setState(() {
                    final encoded = jsonEncode({
                      "url": show["url"],
                      "title": show["title"],
                      "channel": Current_Channel,
                    });
                    if (isFav) {
                      Localstorage.removeFavorite(encoded);
                    } else {
                      Localstorage.addFavorite(encoded);
                    }
                  });
                },
        );
      },
    );
  }
}
