import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serial_stream/Backend.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Variable.dart';

// Design tokens
const _bgColor = Color(0xFF0F0F23);
const _surfaceColor = Color(0xFF1A1A2E);
const _primaryColor = Color(0xFF4338CA);
const _accentColor = Color(0xFF22C55E);
const _textPrimary = Color(0xFFF8FAFC);
const _textMuted = Color(0xFF94A3B8);
const _cardBorder = Color(0xFF2D2D4E);

class Showscreen extends StatefulWidget {
  final String channelName;
  final String showurl;
  final String showtitle;
  final String showimageurl;
  final bool showcompleted;
  final bool isSubscriable;

  const Showscreen({
    super.key,
    required this.channelName,
    required this.showurl,
    required this.showtitle,
    required this.showimageurl,
    required this.showcompleted,
    this.isSubscriable = true,
  });

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
    super.initState();
    _connectivity = Connectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(updateConnectionStatus);
    Current_pg_url = widget.showurl;

    Localstorage.isSubscribe(jsonEncode({
      "name": widget.showtitle,
      "url": widget.showurl,
      "channel": widget.channelName,
    })).then((_is) => setState(() => isSubscribed = _is));

    final showItem = jsonEncode({
      "type": "show",
      "url": widget.showurl,
      "title": widget.showtitle,
      "imageUrl": widget.showimageurl,
      "channel": widget.channelName,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
    });
    Localstorage.addHistory(showItem);

    Backend.fetchEpisodes(widget.showurl).then((value) {
      Episodes = value[0];
      pagintition = value[1];
      setState(() => isloading = false);
    }).catchError((Object _) {
      setState(() => isloading = false);
    });
  }

  void fetchEpisodes(String url) {
    setState(() => isloading = true);
    Backend.fetchEpisodes(url).then((value) {
      Episodes = value[0];
      pagintition = value[1];
      setState(() => isloading = false);
    }).catchError((Object _) {
      setState(() => isloading = false);
    });
  }

  void toggleSubscription() {
    setState(() => isSubscribed = !isSubscribed);
    final subData = jsonEncode({
      "name": widget.showtitle,
      "url": widget.showurl,
      "channel": widget.channelName,
    });
    if (isSubscribed) {
      Localstorage.addSubscribe(subData);
    } else {
      Localstorage.removeSubscribe(subData);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _cardBorder),
        ),
        content: Row(
          children: [
            Icon(
              isSubscribed ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              color: isSubscribed ? _accentColor : _textMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSubscribed
                    ? "Subscribed! You'll be notified of new episodes."
                    : "Unsubscribed from notifications.",
                style: const TextStyle(color: _textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double imageHeight = MediaQuery.of(context).size.width * 9 / 16;

    // Resolve image height
    Image image = Image.network(widget.showimageurl);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (!mounted) return;
        setState(() {
          imageHeight = info.image.height.toDouble().clamp(250, 525);
        });
      }),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _bgColor,
          colorScheme: const ColorScheme.dark(
            primary: _primaryColor,
            secondary: _accentColor,
            surface: _surfaceColor,
          ),
        ),
        child: Scaffold(
          backgroundColor: _bgColor,
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(imageHeight),
              _buildEpisodesHeader(),
              if (isloading)
                _buildLoadingSkeleton()
              else if (Episodes.isEmpty)
                _buildEmptyState()
              else
                _buildEpisodeList(),
              if (pagintition.isNotEmpty) _buildPagination(),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(double imageHeight) {
    return SliverAppBar(
      foregroundColor: _textPrimary,
      expandedHeight: imageHeight,
      pinned: true,
      backgroundColor: _surfaceColor,
      elevation: 0,
      actions: widget.isSubscriable
          ? [
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: isSubscribed
                      ? _subscribeButton(active: true)
                      : _subscribeButton(active: false),
                ),
              ),
            ]
          : null,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double appBarHeight = constraints.biggest.height;
          final bool isCollapsed =
              appBarHeight <= (kToolbarHeight + MediaQuery.of(context).padding.top);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Hero image
              CachedNetworkImage(
                imageUrl: widget.showimageurl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: _surfaceColor),
                errorWidget: (_, __, ___) => Container(color: _surfaceColor),
              ),
              // Gradient overlay — stronger at bottom
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // Top gradient for status bar
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                  ),
                ),
              ),
              // Title area
              Align(
                alignment: isCollapsed ? Alignment.bottomLeft : Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isCollapsed ? 56 : 16,
                    right: 16,
                    bottom: 14,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: isCollapsed
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      if (!isCollapsed) ...[
                        // Channel badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.channelName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        widget.showtitle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: isCollapsed ? 1 : 2,
                        textAlign: isCollapsed ? TextAlign.left : TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: isCollapsed ? 16 : 24,
                          letterSpacing: 0.3,
                          shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                        ),
                      ),
                      if (!isCollapsed && widget.showcompleted) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _accentColor.withOpacity(0.6)),
                          ),
                          child: const Text(
                            "✓ Completed Series",
                            style: TextStyle(
                              color: _accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _subscribeButton({required bool active}) {
    return InkWell(
      key: ValueKey(active),
      onTap: toggleSubscription,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _accentColor : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? _accentColor : Colors.white.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: active ? Colors.white : Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              active ? "Subscribed" : "Subscribe",
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Episodes",
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 10),
            if (!isloading && Episodes.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _primaryColor.withOpacity(0.4)),
                ),
                child: Text(
                  "${Episodes.length}",
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _skeletonTile(),
        childCount: 6,
      ),
    );
  }

  Widget _skeletonTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          _shimmerBox(36, 36, 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _shimmerBox(double.infinity, 14, 4),
                const SizedBox(height: 8),
                _shimmerBox(120, 10, 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _shimmerBox(36, 36, 18),
        ],
      ),
    );
  }

  Widget _shimmerBox(double w, double h, double r) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 0.8),
      duration: const Duration(milliseconds: 800),
      builder: (_, val, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: _cardBorder.withOpacity(val),
          borderRadius: BorderRadius.circular(r),
        ),
      ),
      onEnd: () => setState(() {}),
    );
  }

  Widget _buildEmptyState() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: _cardBorder),
              ),
              child: const Icon(Icons.video_library_outlined, size: 40, color: _textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              "No episodes available",
              style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              "Try again or check back later",
              style: TextStyle(color: _textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => fetchEpisodes(Current_pg_url),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final episode = Episodes[index];
          return _buildEpisodeTile(episode, index);
        },
        childCount: Episodes.length,
      ),
    );
  }

  Widget _buildEpisodeTile(episode, int index) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          PlayerScreenRoute,
          arguments: [
            episode["url"],
            episode["title"],
            widget.showimageurl,
            Episodes.sublist(0, index).reversed.toList(),
            widget.channelName,
            widget.showtitle,
            Current_pg_url,
          ],
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Episode number badge
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryColor.withOpacity(0.4)),
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: _primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode["title"] ?? "",
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.channelName,
                      style: const TextStyle(color: _textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Play button
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    return SliverToBoxAdapter(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: pagintition.map((page) {
                final bool isCurrent = page['current'] == true;
                return InkWell(
                  onTap: page['url'] != null
                      ? () {
                          Current_pg_url = page['url'] ?? Current_pg_url;
                          fetchEpisodes(page['url']);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
                    decoration: BoxDecoration(
                      color: isCurrent ? _primaryColor : _surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isCurrent ? _primaryColor : _cardBorder,
                      ),
                    ),
                    child: Text(
                      page['text'],
                      style: TextStyle(
                        color: isCurrent ? Colors.white : _textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
