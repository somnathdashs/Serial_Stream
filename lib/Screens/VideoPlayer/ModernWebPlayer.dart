import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:keep_screen_on/keep_screen_on.dart';
import 'package:floating/floating.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Variable.dart';
import 'package:serial_stream/Backend.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:serial_stream/UrlExtracterFromVKPrime.dart';
import 'package:serial_stream/Screens/VideoPlayer/VideoScanner.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

class EnhancedVideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final Map<String, String>? headers;
  final String? cookies;
  final String? authToken;
  final String? referer;
  final String? userAgent;
  final String? title;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final List? epishodesQueue;
  final String? showImageUrl;
  final String? channel;
  final String? epishodeUrl;
  final String? parentShowTitle;
  final String? showMainUrl;
  final String? localVideoPath;

  const EnhancedVideoPlayerScreen({
    Key? key,
    this.videoUrl,
    this.headers,
    this.cookies,
    this.authToken,
    this.referer,
    this.userAgent,
    this.title,
    this.onNext,
    this.onPrevious,
    this.epishodesQueue,
    this.showImageUrl,
    this.channel,
    this.epishodeUrl,
    this.parentShowTitle,
    this.showMainUrl,
    this.localVideoPath,
  }) : super(key: key);

  @override
  _EnhancedVideoPlayerScreenState createState() =>
      _EnhancedVideoPlayerScreenState();
}

class _EnhancedVideoPlayerScreenState extends State<EnhancedVideoPlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _rawVideoPlayerController;
  VideoPlayerController get _videoPlayerController =>
      _rawVideoPlayerController!;
  set _videoPlayerController(VideoPlayerController controller) {
    _rawVideoPlayerController = controller;
  }

  bool get _isPlayerInitialized => _rawVideoPlayerController != null;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isFullScreen = false;
  String? _errorMessage;
  bool _hasError = false;

  int _currentPage = 0;
  static const int _itemsPerPage = 10;
  bool _showEpisodesOverlay = false;
  static bool wasFullScreen = false;

  bool _isLoadingEpisodes = false;
  List _fetchedEpisodes = [];
  List _fetchedPagination = [];

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late AnimationController _volumeAnimationController;
  late AnimationController _brightnessAnimationController;
  late AnimationController _fadeAnimationController;
  late AnimationController _scaleAnimationController;
  late Animation<double> _controlsAnimation;
  late Animation<double> _volumeAnimation;
  late Animation<double> _brightnessAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Control states
  Timer? _hideControlsTimer;
  Timer? _longPressTimer;
  bool _isDragging = false;
  double? _dragValue;
  Offset? _panLastPosition;
  bool? _wasLandscape;
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isCurrentEpisodeDownloaded = false;
  String? _downloadedLocalPath;
  int _lastSavedProgressMs = 0;
  bool _showResumeOverlayWidget = false;
  int _resumePositionMs = 0;
  final FocusNode _startOverFocusNode = FocusNode();

  // TV Remote focus
  final FocusNode _mainFocusNode = FocusNode();
  final FocusNode _playPauseFocusNode = FocusNode();
  final FocusNode _skipForwardFocusNode = FocusNode();
  final FocusNode _skipBackwardFocusNode = FocusNode();
  final FocusNode _nextFocusNode = FocusNode();
  final FocusNode _previousFocusNode = FocusNode();
  final FocusNode _downloadFocusNode = FocusNode();
  final FocusNode _pipFocusNode = FocusNode();
  final FocusNode _settingsFocusNode = FocusNode();
  final FocusNode _serversFocusNode = FocusNode();
  final FocusNode _fullscreenFocusNode = FocusNode();

  int _selectedControlIndex = 5;
  final List<FocusNode> _controlFocusNodes = [];

  // Aspect Ratio selection
  double? _customAspectRatio = 16 / 9;

  final Floating _floating = Floating();

  int _lastDoubleTapDirection = 0;
  Timer? _doubleTapFeedbackTimer;

  Offset? _panStartPosition;

  CancelToken? _downloadCancelToken;

  bool _isBluetoothConnected = false;
  String? _bluetoothDeviceName;
  Timer? _bluetoothCheckTimer;

  bool get isAndroidTV =>
      Platform.isAndroid && _isTablet && _screenWidth > 1000;

  late double _screenWidth;
  late double _screenHeight;
  late bool _isLandscape;
  late bool _isTablet;

  bool _isAutoNextEnabled = true;
  String? _currentShowMainUrl;

  // Background resolving & custom speed overlays
  String? _currentEpisodeUrl;
  String? _currentEpisodeTitle;
  List? _currentEpisodesQueue;
  String? _currentVideoUrl;
  Map<String, String>? _currentHeaders;
  String? _currentCookies;
  String? _currentAuthToken;
  String? _currentReferer;
  String? _currentUserAgent;
  List<String> _serversList = [];
  int _currentServerIndex = 0;
  String _statusText = "";
  double? _playbackSpeed;
  Timer? _speedTimer;
  HeadlessInAppWebView? _headlessWebView;
  Timer? _scanTimeoutTimer;
  String? _localVideoPath;

  @override
  void initState() {
    super.initState();
    _isFullScreen = wasFullScreen;
    _currentShowMainUrl = widget.showMainUrl;
    _customAspectRatio = _isFullScreen ? null : 16 / 9;
    SystemChrome.setEnabledSystemUIMode(
      _isFullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    _initializeAnimations();

    _currentEpisodeUrl = widget.epishodeUrl;
    _currentEpisodeTitle = widget.title;
    _currentEpisodesQueue = widget.epishodesQueue;
    _currentVideoUrl = widget.videoUrl;
    _currentHeaders = widget.headers;
    _currentCookies = widget.cookies;
    _currentAuthToken = widget.authToken;
    _currentReferer = widget.referer;
    _currentUserAgent = widget.userAgent;
    _localVideoPath = widget.localVideoPath;

    _initializePlayer();
    _initializeVolume();
    _initializeBrightness();
    _setupControlFocusNodes();
    _initializeBluetooth();
    KeepScreenOn.turnOn();

    if (widget.showMainUrl != null && widget.showMainUrl!.isNotEmpty) {
      _loadShowEpisodes(widget.showMainUrl!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainFocusNode.requestFocus();
      SystemChrome.setEnabledSystemUIMode(
        _isFullScreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    });
  }

  Future<void> _loadShowEpisodes(String url) async {
    if (!mounted) return;
    setState(() {
      _isLoadingEpisodes = true;
      _currentShowMainUrl = url;
    });
    try {
      final value = await Backend.fetchEpisodes(url);
      if (mounted) {
        setState(() {
          _fetchedEpisodes = value[0];
          _fetchedPagination = value[1];
          _isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingEpisodes = false;
        });
      }
    }
  }

  void _setupControlFocusNodes() {
    _controlFocusNodes.addAll([
      _playPauseFocusNode,
      _skipBackwardFocusNode,
      _skipForwardFocusNode,
      _previousFocusNode,
      _nextFocusNode,
      _downloadFocusNode,
      _pipFocusNode,
      _settingsFocusNode,
      _fullscreenFocusNode,
    ]);
  }

  void _initializeAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _volumeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _brightnessAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controlsAnimationController, curve: Curves.easeOutCubic),
    );
    _volumeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _volumeAnimationController, curve: Curves.easeOutCubic),
    );
    _brightnessAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _brightnessAnimationController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _fadeAnimationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
          parent: _scaleAnimationController, curve: Curves.elasticOut),
    );

    _controlsAnimationController.forward();
    _fadeAnimationController.forward();
    _scaleAnimationController.forward();
  }

  Future<void> _initializeVolume() async {
    try {
      // Set initial volume to 0.5 (or any default)
      _currentVolume = 0.5;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Failed to initialize volume: $e');
    }
  }

  Future<void> _initializeBrightness() async {
    try {
      _currentBrightness = await ScreenBrightness().current;
    } catch (e) {
      print('Failed to initialize brightness: $e');
    }
  }

  Future<void> _initializeBluetooth() async {
    try {
      // Simulate Bluetooth connection check
      _bluetoothCheckTimer =
          Timer.periodic(const Duration(seconds: 5), (timer) {
        // Check for Bluetooth devices periodically
        _checkBluetoothConnection();
      });
    } catch (e) {
      print('Failed to initialize Bluetooth: $e');
    }
  }

  void _checkBluetoothConnection() {
    // Simulate Bluetooth connection status
    // In a real implementation, you would check actual Bluetooth devices
    setState(() {
      _isBluetoothConnected = false; // Set to true when actually connected
      _bluetoothDeviceName = null; // Set device name when connected
    });
  }

  void _connectBluetoothDevice() {
    // Simulate connecting to Bluetooth device
    setState(() {
      _isBluetoothConnected = true;
      _bluetoothDeviceName = 'Bluetooth Controller';
    });
    _showModernSnackBar(
        'Bluetooth controller connected', Icons.bluetooth_connected);
  }

  void _disconnectBluetoothDevice() {
    setState(() {
      _isBluetoothConnected = false;
      _bluetoothDeviceName = null;
    });
    _showModernSnackBar(
        'Bluetooth controller disconnected', Icons.bluetooth_disabled);
  }

  Future<void> _checkIfDownloaded() async {
    final path = await _getDownloadedLocalPath();
    if (mounted) {
      setState(() {
        _isCurrentEpisodeDownloaded = path != null;
        _downloadedLocalPath = path;
      });
    }
  }

  Future<String?> _getDownloadedLocalPath() async {
    try {
      final showTitle = widget.parentShowTitle ?? "Show";
      final epTitle = _currentEpisodeTitle ?? "Episode";
      final cleanShowTitle =
          showTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final cleanEpTitle = epTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
      final displayTitle = '$cleanShowTitle - $cleanEpTitle';
      final downloads = await Localstorage.getDownloads();
      for (var item in downloads) {
        try {
          final data = jsonDecode(item);
          if (data["episodeUrl"] == _currentEpisodeUrl ||
              data["title"] == displayTitle) {
            final path = data["localPath"] as String;
            if (await File(path).exists()) {
              return path;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('Error checking local downloads: $e');
    }
    return null;
  }

  Future<void> _playLocalFile(String filePath) async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
        _statusText = "Initializing local video player...";
      });
      _videoPlayerController = VideoPlayerController.file(File(filePath));
      _videoPlayerController.addListener(_videoPlayerListener);
      await _videoPlayerController.initialize();
      if (_videoPlayerController.value.hasError) {
        throw Exception(_videoPlayerController.value.errorDescription ??
            'Unknown video error');
      }
      setState(() {
        _isLoading = false;
      });
      final url = _currentEpisodeUrl ?? _currentVideoUrl ?? _localVideoPath;
      int? savedProgress;
      if (url != null && url.isNotEmpty) {
        final progressVal = await Localstorage.getData("watch_progress_$url");
        if (progressVal is int) {
          savedProgress = progressVal;
        }
      }
      if (savedProgress != null && savedProgress > 0) {
        await _videoPlayerController
            .seekTo(Duration(milliseconds: savedProgress));
        _showResumeOverlay(savedProgress);
      }
      _videoPlayerController.play();
      KeepScreenOn.turnOn();
      _startHideControlsTimer();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showResumeOverlay(int savedProgress) {
    setState(() {
      _showResumeOverlayWidget = true;
      _resumePositionMs = savedProgress;
    });
    Timer(const Duration(seconds: 6), () {
      if (mounted && _showResumeOverlayWidget) {
        setState(() {
          _showResumeOverlayWidget = false;
        });
      }
    });
    if (isAndroidTV) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _showResumeOverlayWidget) {
          _startOverFocusNode.requestFocus();
        }
      });
    }
  }

  void _handleStartOver() {
    if (_isPlayerInitialized) {
      _videoPlayerController.seekTo(Duration.zero);
       final url = _currentEpisodeUrl ?? _currentVideoUrl ?? _localVideoPath;
      if (url != null && url.isNotEmpty) {
        Localstorage.clearData("watch_progress_$url");
      }
    }
    setState(() {
      _showResumeOverlayWidget = false;
    });
  }

  Future<void> _saveWatchProgress() async {
    if (!_isPlayerInitialized || !_videoPlayerController.value.isInitialized)
      return;
    final url = _currentEpisodeUrl ?? _currentVideoUrl ?? _localVideoPath;
    if (url == null || url.isEmpty) return;
    final position = _videoPlayerController.value.position.inMilliseconds;
    final duration = _videoPlayerController.value.duration.inMilliseconds;
    if (position > 5000 && position < duration - 10000) {
      await Localstorage.setData("watch_progress_$url", position);
    } else if (position >= duration - 10000) {
      await Localstorage.clearData("watch_progress_$url");
    }
  }

  Future<void> _initializePlayer() async {
    _startLoadingEpisode();
  }

  Future<void> _startLoadingEpisode() async {
    _stopScanningServer();
    try {
      if (_isPlayerInitialized) {
        _videoPlayerController.removeListener(_videoPlayerListener);
        try {
          await _videoPlayerController.pause();
        } catch (_) {}
        await _videoPlayerController.dispose();
      }
    } catch (_) {}
    _rawVideoPlayerController = null;

    if (_currentEpisodeUrl != null && _currentEpisodeUrl!.isNotEmpty) {
      final episodeItem = jsonEncode({
        "type": "episode",
        "url": _currentEpisodeUrl,
        "title": _currentEpisodeTitle ?? "",
        "imageUrl": widget.showImageUrl ?? "",
        "channel": widget.channel ?? "",
        "parentShowTitle": widget.parentShowTitle ?? "",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "epishodesQueue": _currentEpisodesQueue,
      });
      Localstorage.addHistory(episodeItem);
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
      _statusText = "Checking stream...";
    });

    if (_localVideoPath != null && _localVideoPath!.isNotEmpty) {
      _downloadedLocalPath = _localVideoPath;
      _isCurrentEpisodeDownloaded = true;
      await _playLocalFile(_downloadedLocalPath!);
      return;
    }

    await _checkIfDownloaded();
    if (_isCurrentEpisodeDownloaded && _downloadedLocalPath != null) {
      await _playLocalFile(_downloadedLocalPath!);
      return;
    }

    if (_currentVideoUrl != null &&
        _currentVideoUrl!.isNotEmpty &&
        (_currentVideoUrl!.endsWith('.m3u8') ||
            _currentVideoUrl!.endsWith('.mp4') ||
            (!_currentVideoUrl!.contains('/watch-online/') &&
                !_currentVideoUrl!.contains('desi-serials.to')))) {
      _playDirectStream(_currentVideoUrl!);
      return;
    }

    if (_currentEpisodeUrl == null || _currentEpisodeUrl!.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = "No video or episode URL provided.";
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _statusText = "Finding server list...";
    });

    try {
      List<String> fetchedUrls = [];
      final bool isDirectServerUrl =
          !_currentEpisodeUrl!.contains('/watch-online/') &&
              !_currentEpisodeUrl!.contains('desi-serials.to');

      if (isDirectServerUrl) {
        fetchedUrls = [_currentEpisodeUrl!];
      } else {
        var showsUrls =
            await Localstorage.getData(Localstorage.ShowsCacheMemo) ?? "{}";
        showsUrls = jsonDecode(showsUrls);

        if (showsUrls.keys.contains(_currentEpisodeUrl)) {
          fetchedUrls = List<String>.from(showsUrls[_currentEpisodeUrl]);
        } else {
          fetchedUrls = await Backend.extractEntryContentUrls(
              _currentEpisodeUrl!, Backend.Get_a_Header());
          if (fetchedUrls.isNotEmpty) {
            showsUrls[_currentEpisodeUrl!] = fetchedUrls;
            Localstorage.setData(
                Localstorage.ShowsCacheMemo, jsonEncode(showsUrls));
          }
        }
      }

      if (fetchedUrls.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = "Servers Not Found!";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _serversList = fetchedUrls;
      });
      _resolveServer(0);
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = "Failed to load servers: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveServer(int index) async {
    _stopScanningServer();
    if (index >= _serversList.length) {
      setState(() {
        _hasError = true;
        _errorMessage = "No playable video found on any server.";
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _currentServerIndex = index;
    });

    final serverUrl = _serversList[index];
    if (serverUrl.contains("vkprime")) {
      setState(() {
        _statusText = "Extracting premium video...";
      });
      try {
        var IframSrc = await Backend.extractIframSRC_from_Webpage(
            serverUrl, Backend.Get_a_Header());
        if (IframSrc == null) {
          _resolveServer(index + 1);
          return;
        }

        final extractor = VKPrimeExtractor(
          url: IframSrc,
          onExtracted: (videoUrl) {
            if (videoUrl != null) {
              _playDirectStream(videoUrl);
            } else {
              _resolveServer(index + 1);
            }
          },
        );
        await extractor.start();
      } catch (e) {
        _resolveServer(index + 1);
      }
    } else {
      setState(() {
        _statusText = "Searching on Server ${index + 1}...";
      });
      _startScanningServer(serverUrl, index);
    }
  }

  void _startScanningServer(String serverUrl, int serverIndex) async {
    _scanTimeoutTimer = Timer(const Duration(seconds: 20), () {
      _stopScanningServer();
      _resolveServer(serverIndex + 1);
    });

    try {
      _headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(serverUrl)),
        initialSettings: InAppWebViewSettings(
          allowsInlineMediaPlayback: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsAirPlayForMediaPlayback: true,
          allowsPictureInPictureMediaPlayback: true,
          iframeAllowFullscreen: true,
          useShouldInterceptRequest: true,
          javaScriptEnabled: true,
          domStorageEnabled: true,
        ),
        onWebViewCreated: (controller) {
          _setupScannerJS(controller);
        },
        shouldInterceptRequest: (controller, request) async {
          final url = request.url.toString();
          if (url.toLowerCase().contains('.m3u8')) {
            final headers = request.headers ?? {};
            _onM3u8Detected(M3U8UrlInfo(
              url: url,
              source: 'Network Request',
              timestamp: DateTime.now(),
              headers: Map<String, String>.from(headers),
              referer: headers['Referer'],
              userAgent: headers['User-Agent'],
            ));
          }
          return null;
        },
        onConsoleMessage: (controller, consoleMessage) {
          final msg = consoleMessage.message;
          final m3u8Pattern = RegExp(
              r'https?://[^\s<>"]+\.m3u8(?:\?[^\s<>"]*)?',
              caseSensitive: false);
          final match = m3u8Pattern.firstMatch(msg);
          if (match != null) {
            final url = match.group(0)!;
            _onM3u8Detected(M3U8UrlInfo(
              url: url,
              source: 'Console Log',
              timestamp: DateTime.now(),
            ));
          }
        },
        onLoadResource: (controller, resource) {
          final url = resource.url.toString();
          if (url.toLowerCase().contains('.m3u8')) {
            _onM3u8Detected(M3U8UrlInfo(
              url: url,
              source: 'Resource Load',
              timestamp: DateTime.now(),
            ));
          }
        },
      );

      await _headlessWebView?.run();
    } catch (e) {
      _stopScanningServer();
      _resolveServer(serverIndex + 1);
    }
  }

  void _setupScannerJS(InAppWebViewController controller) {
    const jsCode = '''
      (function() {
        const originalXHROpen = XMLHttpRequest.prototype.open;
        const originalXHRSend = XMLHttpRequest.prototype.send;
        const originalFetch = window.fetch;
        
        XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
          this._url = url;
          return originalXHROpen.apply(this, arguments);
        };
        
        XMLHttpRequest.prototype.send = function(data) {
          const xhr = this;
          if (xhr._url && xhr._url.toLowerCase().includes('.m3u8')) {
            console.log('found_m3u8_console: ' + xhr._url);
          }
          xhr.addEventListener('load', function() {
            if (xhr._url && xhr.responseText) {
              const response = xhr.responseText;
              const m3u8Regex = /https?:\\/\\/[^\\s<>"]+\\.m3u8(?:\\?[^\\s<>"]*)?/gi;
              const matches = response.match(m3u8Regex);
              if (matches) {
                matches.forEach(url => console.log('found_m3u8_console: ' + url));
              }
            }
          });
          return originalXHRSend.apply(this, arguments);
        };
        
        window.fetch = function(...args) {
          const url = args[0];
          if (url && url.toString().toLowerCase().includes('.m3u8')) {
            console.log('found_m3u8_console: ' + url.toString());
          }
          return originalFetch.apply(this, args).then(response => {
            const clonedResponse = response.clone();
            clonedResponse.text().then(text => {
              const m3u8Regex = /https?:\\/\\/[^\\s<>"]+\\.m3u8(?:\\?[^\\s<>"]*)?/gi;
              const matches = text.match(m3u8Regex);
              if (matches) {
                matches.forEach(url => console.log('found_m3u8_console: ' + url));
              }
            }).catch(() => {});
            return response;
          });
        };
        
        function monitorVideoElements() {
          document.querySelectorAll('video').forEach(video => {
            if (video.src && video.src.toLowerCase().includes('.m3u8')) {
              console.log('found_m3u8_console: ' + video.src);
            }
            video.querySelectorAll('source').forEach(source => {
              if (source.src && source.src.toLowerCase().includes('.m3u8')) {
                console.log('found_m3u8_console: ' + source.src);
              }
            });
          });
        }
        
        setInterval(monitorVideoElements, 2000);
        monitorVideoElements();
      })();
    ''';
    Timer(const Duration(milliseconds: 1500), () {
      if (_headlessWebView?.webViewController != null) {
        controller.evaluateJavascript(source: jsCode);
      }
    });
  }

  void _onM3u8Detected(M3U8UrlInfo urlInfo) {
    _stopScanningServer();
    _currentVideoUrl = urlInfo.url;
    _currentHeaders = urlInfo.headers;
    _currentCookies = urlInfo.cookies;
    _currentAuthToken = urlInfo.authToken;
    _currentReferer = urlInfo.referer;
    _currentUserAgent = urlInfo.userAgent;
    _playDirectStream(urlInfo.url);
  }

  void _stopScanningServer() {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    try {
      _headlessWebView?.dispose();
    } catch (_) {}
    _headlessWebView = null;
  }

  void _changeSpeed(double speed) {
    if (!_isPlayerInitialized || !_videoPlayerController.value.isInitialized)
      return;
    _videoPlayerController.setPlaybackSpeed(speed);
    setState(() {
      _playbackSpeed = speed;
    });
    _speedTimer?.cancel();
    _speedTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _playbackSpeed = null;
        });
      }
    });
  }

  Widget _buildSpeedOverlay() {
    if (_playbackSpeed == null) return const SizedBox.shrink();
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Text(
            '${_playbackSpeed!.toStringAsFixed(_playbackSpeed! == _playbackSpeed!.roundToDouble() ? 0 : 2)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playDirectStream(String videoUrl) async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
        _statusText = "Initializing video player...";
      });

      String finalUrl = _prepareUrlWithToken(videoUrl, _currentAuthToken);
      Map<String, String> finalHeaders = _prepareHeaders();

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(finalUrl),
        httpHeaders: finalHeaders,
      );

      _videoPlayerController.addListener(_videoPlayerListener);
      await _videoPlayerController.initialize();

      if (_videoPlayerController.value.hasError) {
        throw Exception(_videoPlayerController.value.errorDescription ??
            'Unknown video error');
      }

      setState(() {
        _isLoading = false;
      });

      final url = _currentEpisodeUrl ?? _currentVideoUrl ?? _localVideoPath;
      int? savedProgress;
      if (url != null && url.isNotEmpty) {
        final progressVal = await Localstorage.getData("watch_progress_$url");
        if (progressVal is int) {
          savedProgress = progressVal;
        }
      }
      if (savedProgress != null && savedProgress > 0) {
        await _videoPlayerController
            .seekTo(Duration(milliseconds: savedProgress));
        _showResumeOverlay(savedProgress);
      }

      _videoPlayerController.play();
      KeepScreenOn.turnOn();
      _startHideControlsTimer();
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _prepareUrlWithToken(String baseUrl, String? token) {
    if (token == null || token.isEmpty) return baseUrl;
    if (baseUrl.contains('token=') || baseUrl.contains('auth=')) {
      return baseUrl;
    }
    final separator = baseUrl.contains('?') ? '&' : '?';
    return '$baseUrl${separator}token=$token';
  }

  Map<String, String> _prepareHeaders() {
    Map<String, String> finalHeaders = {
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'User-Agent': _currentUserAgent ??
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    };

    if (_currentHeaders != null) {
      finalHeaders.addAll(_currentHeaders!);
    }

    if (_currentReferer != null && _currentReferer!.isNotEmpty) {
      finalHeaders['Referer'] = _currentReferer!;
      try {
        final uri = Uri.parse(_currentReferer!);
        finalHeaders['Origin'] = '${uri.scheme}://${uri.host}';
      } catch (e) {
        print('Failed to parse referer: $e');
      }
    }

    if (_currentCookies != null && _currentCookies!.isNotEmpty) {
      finalHeaders['Cookie'] = _currentCookies!;
    }

    if (_currentAuthToken != null && _currentAuthToken!.isNotEmpty) {
      if (!finalHeaders.containsKey('Authorization')) {
        if (_currentAuthToken!.startsWith('eyJ')) {
          finalHeaders['Authorization'] = 'Bearer ${_currentAuthToken!}';
        } else if (_currentAuthToken!.toLowerCase().startsWith('bearer ') ||
            _currentAuthToken!.toLowerCase().startsWith('basic ')) {
          finalHeaders['Authorization'] = _currentAuthToken!;
        } else {
          finalHeaders['Authorization'] = 'Bearer ${_currentAuthToken!}';
        }
      }
    }

    return finalHeaders;
  }

  void _videoPlayerListener() {
    if (!_isPlayerInitialized) return;
    if (_videoPlayerController.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _videoPlayerController.value.errorDescription ??
            'Video playback error';
      });
    }

    if (_videoPlayerController.value.isInitialized) {
      final currentPosMs = _videoPlayerController.value.position.inMilliseconds;
      if ((currentPosMs - _lastSavedProgressMs).abs() >= 5000) {
        _lastSavedProgressMs = currentPosMs;
        _saveWatchProgress();
      }
    }

    if (_showControls && mounted) {
      setState(() {});
    }

    if (_videoPlayerController.value.isInitialized &&
        _videoPlayerController.value.duration > Duration.zero &&
        _videoPlayerController.value.position >=
            _videoPlayerController.value.duration -
                const Duration(milliseconds: 500) &&
        !_videoPlayerController.value.isPlaying) {
      if (_isAutoNextEnabled) {
        _videoPlayerController.removeListener(_videoPlayerListener);
        _triggerNext();
      }
    }
  }

  void _triggerNext() {
    if (widget.onNext != null) {
      widget.onNext!();
    } else {
      _playNextEpisode();
    }
  }

  Future<void> _playNextEpisode() async {
    final queue = _currentEpisodesQueue ?? widget.epishodesQueue;
    if (queue != null && queue.isNotEmpty) {
      final nextEpisode = queue[0];
      final remainingQueue = queue.sublist(1);

      await _saveWatchProgress();

      setState(() {
        _localVideoPath = null;
        _currentEpisodeUrl = nextEpisode["url"];
        _currentEpisodeTitle = nextEpisode["title"];
        _currentEpisodesQueue = remainingQueue;
        _currentVideoUrl = null;
        _currentHeaders = null;
        _currentCookies = null;
        _currentAuthToken = null;
        _currentReferer = null;
        _currentUserAgent = null;
        _serversList = [];
        _currentServerIndex = 0;
      });

      _startLoadingEpisode();
    }
  }

  void _togglePlayPause() {
    if (!_isPlayerInitialized) return;
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
      KeepScreenOn.turnOff(); // Release keep-on when paused
    } else {
      _videoPlayerController.play();
      KeepScreenOn.turnOn(); // Enable keep-on when playing
    }
    _showControlsTemporarily();
  }

  void _skipForward() {
    if (!_isPlayerInitialized) return;
    final position = _videoPlayerController.value.position;
    final newPosition = position + const Duration(seconds: 10);
    _videoPlayerController.seekTo(newPosition);
    _showControlsTemporarily();
  }

  void _skipBackward() {
    if (!_isPlayerInitialized) return;
    final position = _videoPlayerController.value.position;
    final newPosition = position - const Duration(seconds: 10);
    _videoPlayerController.seekTo(newPosition);
    _showControlsTemporarily();
  }

  void _showControlsTemporarily() {
    setState(() {
      _showControls = true;
    });
    _controlsAnimationController.forward();
    _startHideControlsTimer();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isDragging) {
        _hideControls();
      }
    });
  }

  void _hideControls() {
    _controlsAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _adjustVolume(double delta) {
    final newVolume = (_currentVolume + delta).clamp(0.0, 1.0);
    if (_isPlayerInitialized) {
      _videoPlayerController.setVolume(newVolume);
    }
    setState(() {
      _currentVolume = newVolume;
      _showVolumeSlider = true;
    });
    _volumeAnimationController.forward();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _volumeAnimationController.reverse().then((_) {
          setState(() {
            _showVolumeSlider = false;
          });
        });
      }
    });
  }

  void _adjustBrightness(double delta) async {
    final newBrightness = (_currentBrightness + delta).clamp(0.0, 1.0);
    try {
      await ScreenBrightness().setScreenBrightness(newBrightness);
      setState(() {
        _currentBrightness = newBrightness;
        _showBrightnessSlider = true;
      });
      _brightnessAnimationController.forward();

      Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _brightnessAnimationController.reverse().then((_) {
            setState(() {
              _showBrightnessSlider = false;
            });
          });
        }
      });
    } catch (e) {
      print('Failed to adjust brightness: $e');
    }
  }

  Future<List<Map<String, String>>> _fetchHlsResolutions(String m3u8Url) async {
    final List<Map<String, String>> resolutions = [];
    try {
      final dio = Dio();
      final response = await dio.get(
        m3u8Url,
        options: Options(headers: _prepareHeaders()),
      );
      final content = response.data.toString();
      if (content.contains('#EXT-X-STREAM-INF')) {
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.startsWith('#EXT-X-STREAM-INF')) {
            final regExp = RegExp(r'RESOLUTION=(\d+x\d+)');
            final match = regExp.firstMatch(line);
            String resName = 'Unknown Resolution';
            if (match != null) {
              final res = match.group(1)!;
              final height = res.split('x').last;
              resName = '${height}p ($res)';
            }
            if (i + 1 < lines.length) {
              final nextLine = lines[i + 1].trim();
              if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
                final resolvedUrl =
                    Uri.parse(m3u8Url).resolve(nextLine).toString();
                resolutions.add({
                  'name': resName,
                  'url': resolvedUrl,
                });
              }
            }
          }
        }
      }
    } catch (_) {}
    if (resolutions.isEmpty) {
      resolutions.add({
        'name': 'Original Quality',
        'url': m3u8Url,
      });
    }
    return resolutions;
  }

  void _showDownloadOptionsDialog() async {
    final videoUrl = _currentVideoUrl ?? widget.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      _showModernSnackBar('No active stream to download', Icons.error);
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ),
    );
    final resolutions = await _fetchHlsResolutions(videoUrl);
    if (mounted) {
      Navigator.pop(context);
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.download, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Select Resolution',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: resolutions.length,
                  itemBuilder: (context, index) {
                    final res = resolutions[index];
                    return ListTile(
                      title: Text(
                        res['name']!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _downloadVideo(res['url']!, res['name']!);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.blue)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateDownloadNotification(int id, String title, double progress,
      {bool completed = false, bool failed = false}) {
    try {
      if (completed) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: 'progress_channel',
            title: 'Download complete',
            body: '$title downloaded successfully',
            notificationLayout: NotificationLayout.Default,
          ),
        );
      } else if (failed) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: 'progress_channel',
            title: 'Download failed',
            body: 'Download for $title failed or was cancelled',
            notificationLayout: NotificationLayout.Default,
          ),
        );
      } else {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: 'progress_channel',
            title: 'Downloading $title',
            body: '${(progress * 100).toInt()}% downloaded',
            notificationLayout: NotificationLayout.ProgressBar,
            progress: (progress * 100),
            locked: true,
          ),
        );
      }
    } catch (e) {
      print('Error updating download notification: $e');
    }
  }

  void _showDeleteDownloadedConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Delete Video', style: TextStyle(color: Colors.white)),
        content: const Text('Already downloaded. Want to delete it?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_downloadedLocalPath != null) {
                try {
                  final file = File(_downloadedLocalPath!);
                  if (await file.exists()) {
                    await file.delete();
                  }
                  final parentDir = file.parent;
                  if (parentDir.path.contains('/m3u8_') &&
                      await parentDir.exists()) {
                    await parentDir.delete(recursive: true);
                  }
                  await Localstorage.removeDownload(_downloadedLocalPath!);
                  _showModernSnackBar(
                      'Video deleted successfully', Icons.delete);
                  setState(() {
                    _isCurrentEpisodeDownloaded = false;
                    _downloadedLocalPath = null;
                  });
                } catch (e) {
                  _showModernSnackBar('Error deleting video: $e', Icons.error);
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVideo(String downloadUrl, String resolutionName) async {
    if (_isDownloading) return;
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    _downloadCancelToken = CancelToken();
    final showTitle = widget.parentShowTitle ?? "Show";
    final epTitle = _currentEpisodeTitle ?? "Episode";
    final cleanShowTitle =
        showTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final cleanEpTitle = epTitle.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();
    final displayTitle = '$cleanShowTitle - $cleanEpTitle';
    int notificationId = downloadUrl.hashCode.abs() % 100000;
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${directory.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final dio = Dio();
      final headers = _prepareHeaders();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (downloadUrl.toLowerCase().contains('.m3u8')) {
        final folder = Directory('${downloadsDir.path}/m3u8_$timestamp');
        await folder.create(recursive: true);
        final playlistResp = await dio.get(
          downloadUrl,
          options: Options(headers: headers),
          cancelToken: _downloadCancelToken,
        );
        final playlistContent = playlistResp.data.toString();
        final lines = playlistContent.split('\n');
        final newLines = <String>[];
        final segmentUrls = <String>[];
        int segmentCount = 0;
        for (var line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            final resolvedSegmentUrl =
                Uri.parse(downloadUrl).resolve(trimmed).toString();
            final segmentFileName = 'segment_$segmentCount.ts';
            newLines.add(segmentFileName);
            segmentUrls.add(resolvedSegmentUrl);
            segmentCount++;
          } else {
            newLines.add(line);
          }
        }
        final playlistFile = File('${folder.path}/playlist.m3u8');
        await playlistFile.writeAsString(newLines.join('\n'));
        int downloaded = 0;
        int lastNotifiedPercent = -1;
        for (int i = 0; i < segmentUrls.length; i++) {
          if (_downloadCancelToken?.isCancelled == true) break;
          final segmentUrl = segmentUrls[i];
          final segmentResp = await dio.get<List<int>>(
            segmentUrl,
            options:
                Options(responseType: ResponseType.bytes, headers: headers),
            cancelToken: _downloadCancelToken,
          );
          final segmentFile = File('${folder.path}/segment_$i.ts');
          await segmentFile.writeAsBytes(segmentResp.data!);
          downloaded++;
          double prog = downloaded / segmentUrls.length;
          int pct = (prog * 100).toInt();
          setState(() {
            _downloadProgress = prog;
          });
          if (pct != lastNotifiedPercent) {
            lastNotifiedPercent = pct;
            _updateDownloadNotification(notificationId, displayTitle, prog);
          }
        }
        if (_downloadCancelToken?.isCancelled != true) {
          final downloadItem = jsonEncode({
            "title": displayTitle,
            "url": downloadUrl,
            "episodeUrl": _currentEpisodeUrl,
            "localPath": playlistFile.path,
            "imageUrl": widget.showImageUrl ?? "",
            "channel": widget.channel ?? "",
            "parentShowTitle": widget.parentShowTitle ?? "",
            "timestamp": timestamp,
            "resolution": resolutionName,
          });
          await Localstorage.addDownload(downloadItem);
          _showModernSnackBar(
              'Download complete: $displayTitle ($resolutionName)',
              Icons.check_circle);
          _updateDownloadNotification(notificationId, displayTitle, 1.0,
              completed: true);
          _checkIfDownloaded();
        } else {
          if (await folder.exists()) {
            await folder.delete(recursive: true);
          }
          _showModernSnackBar('Download cancelled', Icons.cancel);
          _updateDownloadNotification(notificationId, displayTitle, 0.0,
              failed: true);
        }
      } else {
        final fileExtension =
            downloadUrl.split('?').first.split('.').last.toLowerCase();
        final ext = (fileExtension == 'mp4' ||
                fileExtension == 'mkv' ||
                fileExtension == 'webm')
            ? fileExtension
            : 'mp4';
        final file = File('${downloadsDir.path}/video_$timestamp.$ext');
        int lastNotifiedPercent = -1;
        await dio.download(
          downloadUrl,
          file.path,
          onReceiveProgress: (received, total) {
            double prog = total > 0 ? received / total : 0.0;
            int pct = (prog * 100).toInt();
            setState(() {
              _downloadProgress = prog;
            });
            if (pct != lastNotifiedPercent) {
              lastNotifiedPercent = pct;
              _updateDownloadNotification(notificationId, displayTitle, prog);
            }
          },
          options: Options(headers: headers),
          cancelToken: _downloadCancelToken,
        );
        if (_downloadCancelToken?.isCancelled != true) {
          final downloadItem = jsonEncode({
            "title": displayTitle,
            "url": downloadUrl,
            "episodeUrl": _currentEpisodeUrl,
            "localPath": file.path,
            "imageUrl": widget.showImageUrl ?? "",
            "channel": widget.channel ?? "",
            "parentShowTitle": widget.parentShowTitle ?? "",
            "timestamp": timestamp,
            "resolution": resolutionName,
          });
          await Localstorage.addDownload(downloadItem);
          _showModernSnackBar(
              'Download complete: $displayTitle ($resolutionName)',
              Icons.check_circle);
          _updateDownloadNotification(notificationId, displayTitle, 1.0,
              completed: true);
          _checkIfDownloaded();
        } else {
          if (await file.exists()) {
            await file.delete();
          }
          _showModernSnackBar('Download cancelled', Icons.cancel);
          _updateDownloadNotification(notificationId, displayTitle, 0.0,
              failed: true);
        }
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        _showModernSnackBar('Download cancelled', Icons.cancel);
      } else {
        _showModernSnackBar('Download failed: $e', Icons.error);
        _updateDownloadNotification(notificationId, displayTitle, 0.0,
            failed: true);
      }
    } finally {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      _downloadCancelToken = null;
    }
  }

  void _enterPipMode() async {
    try {
      final canUsePiP = await _floating.isPipAvailable;
      if (canUsePiP) {
        await _floating.enable(ImmediatePiP());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('PiP mode is not supported on this device.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to enter PiP mode: $e')),
      );
    }
  }

  void _handleTVRemoteKey(KeyEvent event) {
    // Enhanced Android TV remote handling
    if (event is KeyDownEvent) {
      // Handle long press for fullscreen toggle
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _longPressTimer = Timer(const Duration(milliseconds: 800), () {
          _toggleFullScreen();
        });
      }

      // Enhanced key mapping for Android TV
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowRight:
          if (_showControls) {
            _navigateControls(1);
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (_showControls) {
            _navigateControls(-1);
          }
          break;
        case LogicalKeyboardKey.arrowUp:
          if (_showControls) {
            // Move to previous control row if available
            _adjustVolume(0.1);
          } else {
            _adjustVolume(0.1);
          }
          break;
        case LogicalKeyboardKey.arrowDown:
          if (_showControls) {
            // Move to next control row if available
            _adjustVolume(-0.1);
          } else {
            _adjustVolume(-0.1);
          }
          break;
        case LogicalKeyboardKey.backspace:
        case LogicalKeyboardKey.escape:
          if (_isFullScreen) {
            _toggleFullScreen();
          } else {
            Navigator.pop(context);
          }
          break;
        case LogicalKeyboardKey.mediaPlayPause:
        case LogicalKeyboardKey.play:
        case LogicalKeyboardKey.pause:
          _togglePlayPause();
          break;
        case LogicalKeyboardKey.mediaStop:
          if (_isPlayerInitialized) {
            _videoPlayerController.seekTo(Duration.zero);
            _videoPlayerController.pause();
          }
          break;
        case LogicalKeyboardKey.mediaSkipForward:
          _skipForward();
          break;
        case LogicalKeyboardKey.mediaSkipBackward:
          _skipBackward();
          break;
        case LogicalKeyboardKey.mediaRewind:
          _skipBackward();
          break;
        case LogicalKeyboardKey.mediaFastForward:
          _skipForward();
          break;
        case LogicalKeyboardKey.f1:
          _showSettingsDialog();
          break;
        case LogicalKeyboardKey.f2:
          _showGuideDialog();
          break;
        case LogicalKeyboardKey.f3:
          _enterPipMode();
          break;
        case LogicalKeyboardKey.f4:
          _toggleFullScreen();
          break;
        case LogicalKeyboardKey.f5:
          if (_isBluetoothConnected) {
            _disconnectBluetoothDevice();
          } else {
            _connectBluetoothDevice();
          }
          break;
        default:
          break;
      }
      _showControlsTemporarily();
    } else if (event is KeyUpEvent) {
      // Handle short press for control activation
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        _longPressTimer?.cancel();
        if (_showControls) {
          _executeSelectedControl();
        }
      }
    }
  }

  // Old handler for non-TV
  void _handleTVRemoteKeyOld(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.space:
          _longPressTimer = Timer(const Duration(milliseconds: 800), () {
            _toggleFullScreen();
          });
          break;
        case LogicalKeyboardKey.arrowRight:
          if (_showControls) {
            _navigateControls(1);
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (_showControls) {
            _navigateControls(-1);
          }
          break;
        case LogicalKeyboardKey.arrowUp:
          _adjustVolume(0.1);

          break;
        case LogicalKeyboardKey.arrowDown:
          _adjustVolume(-0.1);

          break;
        case LogicalKeyboardKey.backspace:
          if (_isFullScreen) {
            _toggleFullScreen();
          } else {
            Navigator.pop(context);
          }
          break;
        case LogicalKeyboardKey.mediaPlayPause:
          _togglePlayPause();
          break;
      }
      _showControlsTemporarily();
    } else if (event is KeyUpEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.select:
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.space:
          _longPressTimer?.cancel();
          if (_showControls) {
            _executeSelectedControl();
          }
          break;
      }
    }
  }

  void _navigateControls(int direction) {
    setState(() {
      _selectedControlIndex = (_selectedControlIndex + direction) % 10;
      if (_selectedControlIndex < 0) {
        _selectedControlIndex = 9;
      }
    });
  }

  void _executeSelectedControl() {
    switch (_selectedControlIndex) {
      case 0: // Back
        Navigator.pop(context);
        break;
      case 1: // Guide
        _showGuideDialog();
        break;
      case 2: // PiP
        _enterPipMode();
        break;
      case 3: // setting
        _showSettingsDialog();
        break;
      case 4: // Servers
        _showServerListDialog();
        break;
      case 5: // 10s backward
        _skipBackward();
        break;
      case 6: // Play/Pause btn
        _togglePlayPause();
        break;
      case 7: // 10s Forward
        _skipForward();
        break;
      case 8: // Fullscreen
        _toggleFullScreen();
        break;
      case 9: // Download
        if (_isCurrentEpisodeDownloaded) {
          _showDeleteDownloadedConfirmDialog();
        } else {
          _showDownloadOptionsDialog();
        }
        break;
    }
  }

  // Handles player swipe gestures.
  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _panStartPosition = details.localPosition;
    _panLastPosition = details.localPosition;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _panLastPosition = details.localPosition;
    if (_panStartPosition != null) {
      if (_panStartPosition!.dx < _screenWidth * 0.3) {
        final delta = -details.delta.dy / _screenHeight;
        _adjustBrightness(delta);
      } else if (_panStartPosition!.dx > _screenWidth * 0.7) {
        final delta = -details.delta.dy / _screenHeight;
        _adjustVolume(delta);
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _isDragging = false;
    if (_panStartPosition != null && _panLastPosition != null) {
      final double startX = _panStartPosition!.dx;
      if (startX >= _screenWidth * 0.3 && startX <= _screenWidth * 0.7) {
        final double totalDeltaY = _panLastPosition!.dy - _panStartPosition!.dy;
        if (totalDeltaY < -60.0) {
          if (!_isFullScreen) {
            _toggleFullScreen();
          }
        } else if (totalDeltaY > 60.0) {
          if (_isFullScreen) {
            _toggleFullScreen();
          } else if (_isLandscape) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            Navigator.pop(context);
          }
        }
      }
    }
    _panStartPosition = null;
    _panLastPosition = null;
    _startHideControlsTimer();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
      wasFullScreen = _isFullScreen;
      if (_isFullScreen) {
        _customAspectRatio = null;
      } else {
        _customAspectRatio = 16 / 9;
      }
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ));
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);

      Future.delayed(const Duration(seconds: 2), () {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  @override
  void dispose() {
    _saveWatchProgress();
    _startOverFocusNode.dispose();
    _stopScanningServer();
    _speedTimer?.cancel();
    if (wasFullScreen) {
      wasFullScreen = false;
    }
    _controlsAnimationController.dispose();
    _volumeAnimationController.dispose();
    _brightnessAnimationController.dispose();
    _fadeAnimationController.dispose();
    _scaleAnimationController.dispose();
    _hideControlsTimer?.cancel();
    _longPressTimer?.cancel();
    _doubleTapFeedbackTimer?.cancel();
    _bluetoothCheckTimer?.cancel();
    if (_isPlayerInitialized) {
      _videoPlayerController.removeListener(_videoPlayerListener);
      _videoPlayerController.dispose();
      _rawVideoPlayerController = null;
    }

    for (final focusNode in _controlFocusNodes) {
      focusNode.dispose();
    }
    _serversFocusNode.dispose();
    _mainFocusNode.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final isDarkTheme =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDarkTheme ? Brightness.light : Brightness.dark,
    ));

    KeepScreenOn.turnOff(); // Release keep-on on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isLandscape = _screenWidth > _screenHeight;
    _isTablet = _screenWidth > 600;

    final currentLandscape = _screenWidth > _screenHeight;
    if ((_wasLandscape == null && currentLandscape) ||
        (_wasLandscape != null && currentLandscape && !_wasLandscape!)) {
      if (!_isFullScreen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isFullScreen) {
            _toggleFullScreen();
          }
        });
      }
    }
    _wasLandscape = currentLandscape;

    return KeyboardListener(
      focusNode: _mainFocusNode,
      onKeyEvent: (event) {
        _handleTVRemoteKey(event);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _isFullScreen
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black,
                        Colors.grey[900]!,
                        Colors.black,
                      ],
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (_showControls) {
                        _hideControls();
                      } else {
                        _showControlsTemporarily();
                      }
                    },
                    onLongPressStart: (_) => _changeSpeed(2.0),
                    onLongPressEnd: (_) => _changeSpeed(1.0),
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    onPanEnd: _handlePanEnd,
                    onDoubleTapDown: (details) {
                      if (details.localPosition.dx < _screenWidth / 2) {
                        _skipBackward();
                        _showDoubleTapFeedback(-1);
                      } else {
                        _skipForward();
                        _showDoubleTapFeedback(1);
                      }
                    },
                    child: Stack(
                      children: [
                        Center(child: _buildVideoWidget()),
                        _buildVolumeSlider(),
                        _buildBrightnessSlider(),
                        _buildCustomControls(),
                        if (_isDownloading) _buildDownloadIndicator(),
                        _buildDoubleTapFeedback(),
                        _buildLoadingOverlay(),
                        _buildSpeedOverlay(),
                        if (_showEpisodesOverlay)
                          _buildEpisodesFullScreenOverlay(),
                        _buildResumeProgressOverlay(),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: MediaQuery.of(context).padding.top,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black,
                            Colors.black.withOpacity(0.85),
                          ],
                        ),
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.black,
                              Colors.grey[900]!,
                              Colors.black,
                            ],
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            if (_showControls) {
                              _hideControls();
                            } else {
                              _showControlsTemporarily();
                            }
                          },
                          onLongPressStart: (_) => _changeSpeed(2.0),
                          onLongPressEnd: (_) => _changeSpeed(1.0),
                          onPanStart: _handlePanStart,
                          onPanUpdate: _handlePanUpdate,
                          onPanEnd: _handlePanEnd,
                          onDoubleTapDown: (details) {
                            if (details.localPosition.dx < _screenWidth / 2) {
                              _skipBackward();
                              _showDoubleTapFeedback(-1);
                            } else {
                              _skipForward();
                              _showDoubleTapFeedback(1);
                            }
                          },
                          child: Stack(
                            children: [
                              Center(child: _buildVideoWidget()),
                              _buildVolumeSlider(),
                              _buildBrightnessSlider(),
                              _buildCustomControls(),
                              if (_isDownloading) _buildDownloadIndicator(),
                              _buildDoubleTapFeedback(),
                              _buildLoadingOverlay(),
                              _buildSpeedOverlay(),
                              _buildResumeProgressOverlay(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: Colors.grey[950],
                        child: SingleChildScrollView(
                          child: SafeArea(
                            top: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (widget.parentShowTitle != null)
                                        Text(
                                          widget.parentShowTitle!,
                                          style: TextStyle(
                                            color: Colors.blue[400],
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _currentEpisodeTitle ??
                                            widget.title ??
                                            'Video Player',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (widget.channel != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: Backend.getChannelLogo(widget.channel!),
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => const Icon(
                                                  Icons.tv,
                                                  color: Colors.white54,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              widget.channel!,
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Divider(color: Colors.white10, height: 1),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "More Episodes",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          const Text(
                                            "Auto Next",
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 14),
                                          ),
                                          Switch(
                                            value: _isAutoNextEnabled,
                                            onChanged: (val) {
                                              setState(() {
                                                _isAutoNextEnabled = val;
                                              });
                                            },
                                            activeColor: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if ((widget.showMainUrl == null ||
                                        widget.showMainUrl!.isEmpty) &&
                                    (widget.epishodesQueue == null ||
                                        widget.epishodesQueue!.isEmpty))
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Center(
                                      child: Text(
                                        "No more episodes in queue.",
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ),
                                  )
                                else if (_isLoadingEpisodes)
                                  const Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  Builder(
                                    builder: (context) {
                                      final useFetched =
                                          widget.showMainUrl != null &&
                                              widget.showMainUrl!.isNotEmpty;
                                      final episodesToShow = useFetched
                                          ? _fetchedEpisodes
                                          : (widget.epishodesQueue ?? []);

                                      if (episodesToShow.isEmpty) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Center(
                                            child: Text(
                                              "No episodes found.",
                                              style: TextStyle(
                                                  color: Colors.white54),
                                            ),
                                          ),
                                        );
                                      }

                                      final totalEpisodes =
                                          episodesToShow.length;
                                      final totalPages = useFetched
                                          ? 1
                                          : (totalEpisodes / _itemsPerPage)
                                              .ceil();
                                      final startIndex = useFetched
                                          ? 0
                                          : _currentPage * _itemsPerPage;
                                      final endIndex = useFetched
                                          ? totalEpisodes
                                          : (startIndex + _itemsPerPage)
                                              .clamp(0, totalEpisodes);
                                      final displayedEpisodes = episodesToShow
                                          .sublist(startIndex, endIndex);

                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            itemCount: displayedEpisodes.length,
                                            itemBuilder: (context, index) {
                                              return _buildEpisodeCard(
                                                  displayedEpisodes[index],
                                                  startIndex + index);
                                            },
                                          ),
                                          if (useFetched &&
                                              _fetchedPagination.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16.0),
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: _fetchedPagination
                                                      .map((page) {
                                                    final isCurrent =
                                                        page['current'] == true;
                                                    final hasUrl =
                                                        page['url'] != null;
                                                    return InkWell(
                                                      onTap: hasUrl
                                                          ? () {
                                                              _loadShowEpisodes(
                                                                  page['url']);
                                                            }
                                                          : null,
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 5,
                                                            vertical: 10),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 8,
                                                                horizontal: 16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isCurrent
                                                              ? Colors.blue
                                                              : Colors
                                                                  .grey[800],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Text(
                                                          page['text'] ?? '',
                                                          style: TextStyle(
                                                            color: isCurrent
                                                                ? Colors.white
                                                                : Colors
                                                                    .white70,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            )
                                          else if (!useFetched &&
                                              totalPages > 1)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 16.0),
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: List.generate(
                                                      totalPages, (i) {
                                                    final isCurrent =
                                                        i == _currentPage;
                                                    return InkWell(
                                                      onTap: () {
                                                        setState(() {
                                                          _currentPage = i;
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: const EdgeInsets
                                                            .symmetric(
                                                            horizontal: 5,
                                                            vertical: 10),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 8,
                                                                horizontal: 16),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: isCurrent
                                                              ? Colors.blue
                                                              : Colors
                                                                  .grey[800],
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(20),
                                                        ),
                                                        child: Text(
                                                          '${i + 1}',
                                                          style: TextStyle(
                                                            color: isCurrent
                                                                ? Colors.white
                                                                : Colors
                                                                    .white70,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }),
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                // Buy Me a Coffee
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 320),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          focusColor: Colors.blue.withValues(alpha: 0.3),
                                          hoverColor: Colors.blue.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () async {
                                            final uri = Uri.parse('https://buymeacoffee.com/somnathdash/');
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                                            }
                                          },
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
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEpisodesFullScreenOverlay() {
    final useFetched =
        widget.showMainUrl != null && widget.showMainUrl!.isNotEmpty;
    final episodesToShow =
        useFetched ? _fetchedEpisodes : widget.epishodesQueue ?? [];
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 320,
      child: GestureDetector(
        onTap: () {}, // Prevent tap bubble
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.9),
            border:
                const Border(left: BorderSide(color: Colors.white24, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: const Text(
                  'More Episodes',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showEpisodesOverlay = false;
                    });
                  },
                ),
              ),
              if (_isLoadingEpisodes)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: episodesToShow.length,
                    itemBuilder: (context, index) {
                      final episode = episodesToShow[index];
                      return _buildEpisodeCard(episode, index);
                    },
                  ),
                ),
                if (useFetched && _fetchedPagination.isNotEmpty)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _fetchedPagination.map((page) {
                          final isCurrent = page['current'] == true;
                          final hasUrl = page['url'] != null;
                          return InkWell(
                            onTap: hasUrl
                                ? () {
                                    _loadShowEpisodes(page['url']);
                                  }
                                : null,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 5),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              decoration: BoxDecoration(
                                color:
                                    isCurrent ? Colors.blue : Colors.grey[800],
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                page['text'] ?? '',
                                style: TextStyle(
                                  color:
                                      isCurrent ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(dynamic episode, int index) {
    final useFetched =
        widget.showMainUrl != null && widget.showMainUrl!.isNotEmpty;
    final queue = useFetched
        ? _fetchedEpisodes
        : _currentEpisodesQueue ?? widget.epishodesQueue;
    final bool isCurrentlyPlaying =
        (_currentEpisodeUrl != null && episode["url"] == _currentEpisodeUrl) ||
            (_currentEpisodeTitle != null &&
                episode["title"] == _currentEpisodeTitle);

    return InkWell(
      onTap: () async {
        final nextQueue = useFetched
            ? (queue != null && index > 0
                ? queue.sublist(0, index).reversed.toList()
                : [])
            : (queue != null && index + 1 < queue.length
                ? queue.sublist(index + 1)
                : []);

        await _saveWatchProgress();

        setState(() {
          _currentEpisodeUrl = episode["url"];
          _currentEpisodeTitle = episode["title"];
          _currentEpisodesQueue = nextQueue;
          _currentVideoUrl = null;
          _currentHeaders = null;
          _currentCookies = null;
          _currentAuthToken = null;
          _currentReferer = null;
          _currentUserAgent = null;
          _serversList = [];
          _currentServerIndex = 0;
        });

        _startLoadingEpisode();
      },
      child: Card(
        color: isCurrentlyPlaying
            ? Colors.blue.withOpacity(0.2)
            : Colors.grey[900],
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isCurrentlyPlaying
              ? const BorderSide(color: Colors.blue, width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (widget.showImageUrl != null &&
                  widget.showImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.showImageUrl!,
                    width: 70,
                    height: 45,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey[800]),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                )
              else
                Container(
                  width: 70,
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.movie, color: Colors.white54),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  episode["title"] ?? "",
                  style: TextStyle(
                    color: isCurrentlyPlaying ? Colors.blue : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                isCurrentlyPlaying ? Icons.volume_up : Icons.play_circle_fill,
                color: Colors.blue,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.red.withOpacity(0.3), width: 2),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[400]!],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh, color: Colors.white),
                label: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isPlayerInitialized && _videoPlayerController.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(_isFullScreen ? 0 : (_isTablet ? 16 : 8)),
          boxShadow: [
            if (!_isFullScreen)
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(_isFullScreen ? 0 : (_isTablet ? 16 : 8)),
          child: AspectRatio(
            aspectRatio: _customAspectRatio ??
                (_isFullScreen
                    ? (_isLandscape ? _screenWidth / _screenHeight : 16 / 9)
                    : _videoPlayerController.value.aspectRatio),
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _videoPlayerController.value.size.width > 0
                    ? _videoPlayerController.value.size.width
                    : 16.0,
                height: _videoPlayerController.value.size.height > 0
                    ? _videoPlayerController.value.size.height
                    : 9.0,
                child: VideoPlayer(_videoPlayerController),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            color: Colors.grey[600],
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Video not available',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeSlider() {
    if (!_showVolumeSlider) return const SizedBox.shrink();

    // Enhanced responsive sizing for volume slider with landscape support
    final isLargeScreen = _screenWidth > 800;

    // Responsive sizing for volume slider (landscape removed, values adjusted)
    final leftPosition =
        isLargeScreen ? (_isTablet ? 60.0 : 40.0) : (_isTablet ? 40.0 : 20.0);
    final double sliderWidth = !_isFullScreen
        ? 40.0
        : (isLargeScreen
            ? (_isTablet ? 100.0 : 80.0)
            : (_isTablet ? 80.0 : 60.0));
    final double verticalPadding = !_isFullScreen
        ? 10.0
        : (isLargeScreen
            ? (_isTablet ? 160.0 : 140.0)
            : (_isTablet ? 120.0 : 100.0));
    final double iconSize = !_isFullScreen
        ? 16.0
        : (isLargeScreen
            ? (_isTablet ? 36.0 : 32.0)
            : (_isTablet ? 28.0 : 24.0));
    final double iconPadding = !_isFullScreen
        ? 6.0
        : (isLargeScreen
            ? (_isTablet ? 16.0 : 14.0)
            : (_isTablet ? 12.0 : 10.0));
    final double borderRadius = !_isFullScreen
        ? 8.0
        : (isLargeScreen
            ? (_isTablet ? 20.0 : 18.0)
            : (_isTablet ? 16.0 : 12.0));
    final double trackHeight = !_isFullScreen
        ? 3.0
        : (isLargeScreen ? (_isTablet ? 8.0 : 8.0) : (_isTablet ? 6.0 : 4.0));
    final double thumbRadius = !_isFullScreen
        ? 5.0
        : (isLargeScreen ? (_isTablet ? 10.0 : 10.0) : (_isTablet ? 8.0 : 6.0));
    final double overlayRadius = !_isFullScreen
        ? 10.0
        : (isLargeScreen
            ? (_isTablet ? 20.0 : 20.0)
            : (_isTablet ? 16.0 : 12.0));
    final double percentageFontSize = !_isFullScreen
        ? 9.0
        : (isLargeScreen
            ? (_isTablet ? 14.0 : 14.0)
            : (_isTablet ? 12.0 : 10.0));

    return Positioned(
      left: !_isFullScreen ? 10.0 : 20.0,
      top: 0,
      bottom: 0,
      child: FadeTransition(
        opacity: _volumeAnimation,
        child: Container(
          width: sliderWidth,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Column(
            children: [
              // Enhanced volume icon container
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue[600]!.withOpacity(0.9),
                      Colors.blue[400]!.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _currentVolume > 0.5
                      ? Icons.volume_up
                      : _currentVolume > 0
                          ? Icons.volume_down
                          : Icons.volume_off,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(
                  height: !_isFullScreen ? 8.0 : (isLargeScreen ? 20 : 16)),

              // Enhanced slider container
              Expanded(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(vertical: isLargeScreen ? 12 : 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(isLargeScreen ? 24 : 20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blue[400],
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                        thumbColor: Colors.white,
                        trackHeight: trackHeight,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: thumbRadius,
                          elevation: 6,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: overlayRadius,
                        ),
                      ),
                      child: Slider(
                        value: _currentVolume,
                        onChanged: (value) {
                          _videoPlayerController.setVolume(value);
                          setState(() {
                            _currentVolume = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                  height: !_isFullScreen ? 8.0 : (isLargeScreen ? 20 : 16)),

              // Enhanced percentage display
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 12 : 8,
                    vertical: isLargeScreen ? 6 : 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${(_currentVolume * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: percentageFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrightnessSlider() {
    if (!_showBrightnessSlider) return const SizedBox.shrink();

    // Enhanced responsive sizing for brightness slider with landscape support
    final isLargeScreen = _screenWidth > 800;
    final isLandscape = _screenWidth > _screenHeight;

    // Responsive sizing for brightness slider (mirroring _buildVolumeSlider)
    final double sliderWidth = !_isFullScreen
        ? 40.0
        : (isLargeScreen
            ? (_isTablet ? 100.0 : 80.0)
            : (_isTablet ? 80.0 : 60.0));
    final double verticalPadding = !_isFullScreen
        ? 10.0
        : (isLargeScreen
            ? (_isTablet ? 160.0 : 140.0)
            : (_isTablet ? 120.0 : 100.0));
    final double iconSize = !_isFullScreen
        ? 16.0
        : (isLargeScreen
            ? (_isTablet ? 36.0 : 32.0)
            : (_isTablet ? 28.0 : 24.0));
    final double iconPadding = !_isFullScreen
        ? 6.0
        : (isLargeScreen
            ? (_isTablet ? 16.0 : 14.0)
            : (_isTablet ? 12.0 : 10.0));
    final double borderRadius = !_isFullScreen
        ? 8.0
        : (isLargeScreen
            ? (_isTablet ? 20.0 : 18.0)
            : (_isTablet ? 16.0 : 12.0));
    final double trackHeight = !_isFullScreen
        ? 3.0
        : (isLargeScreen ? (_isTablet ? 8.0 : 8.0) : (_isTablet ? 6.0 : 4.0));
    final double thumbRadius = !_isFullScreen
        ? 5.0
        : (isLargeScreen ? (_isTablet ? 10.0 : 10.0) : (_isTablet ? 8.0 : 6.0));
    final double overlayRadius = !_isFullScreen
        ? 10.0
        : (isLargeScreen
            ? (_isTablet ? 20.0 : 20.0)
            : (_isTablet ? 16.0 : 12.0));
    final double percentageFontSize = !_isFullScreen
        ? 9.0
        : (isLargeScreen
            ? (_isTablet ? 14.0 : 14.0)
            : (_isTablet ? 12.0 : 10.0));

    return Positioned(
      right: !_isFullScreen ? 10.0 : 20.0,
      top: 0,
      bottom: 0,
      child: FadeTransition(
        opacity: _brightnessAnimation,
        child: Container(
          width: sliderWidth,
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Column(
            children: [
              // Enhanced brightness icon container
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange[600]!.withOpacity(0.9),
                      Colors.orange[400]!.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _currentBrightness > 0.7
                      ? Icons.brightness_7
                      : _currentBrightness > 0.3
                          ? Icons.brightness_6
                          : Icons.brightness_4,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              SizedBox(
                  height: !_isFullScreen ? 8.0 : (isLargeScreen ? 20 : 16)),

              // Enhanced slider container
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.black.withOpacity(0.6),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(isLargeScreen ? 24 : 20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.orange[400],
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                        thumbColor: Colors.white,
                        trackHeight: trackHeight,
                        thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: thumbRadius,
                          elevation: 6,
                        ),
                        overlayShape: RoundSliderOverlayShape(
                          overlayRadius: overlayRadius,
                        ),
                      ),
                      child: Slider(
                        value: _currentBrightness,
                        onChanged: (value) async {
                          try {
                            await ScreenBrightness().setScreenBrightness(value);
                            setState(() {
                              _currentBrightness = value;
                            });
                          } catch (e) {
                            print('Failed to set brightness: $e');
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                  height: !_isFullScreen ? 8.0 : (isLargeScreen ? 20 : 16)),

              // Enhanced percentage display
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 12 : 8,
                    vertical: isLargeScreen ? 6 : 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${(_currentBrightness * 100).round()}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: percentageFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomControls() {
    if (!_showControls ||
        !_isPlayerInitialized ||
        !_videoPlayerController.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.15),
                Colors.black.withOpacity(0.9),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildTopControls(),
              const Spacer(),
              if (_isFullScreen) ...[
                _buildCenterControls(),
                const Spacer(),
              ],
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    final double topPadding = 0.0;
    return Container(
      padding: EdgeInsets.only(
        left: !_isFullScreen ? 12.0 : (_isTablet ? 24.0 : 16.0),
        right: !_isFullScreen ? 12.0 : (_isTablet ? 24.0 : 16.0),
        top: topPadding + (!_isFullScreen ? 6.0 : (_isTablet ? 16.0 : 12.0)),
        bottom: !_isFullScreen ? 6.0 : (_isTablet ? 16.0 : 12.0),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.95),
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!_isFullScreen)
            _buildModernIconButton(
              icon: Icons.arrow_back_ios_new,
              onPressed: () => Navigator.pop(context),
              highlight: _selectedControlIndex == 0,
              tooltip: 'Back',
              size: !_isFullScreen ? 24.0 : (_isTablet ? 32.0 : 28.0),
            ),
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: !_isFullScreen ? 8.0 : 16.0,
                vertical: !_isFullScreen ? 4.0 : 8.0,
              ),
              child: _isFullScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.channel != null) ...[
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: Backend.getChannelLogo(widget.channel!),
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.tv,
                                    color: Colors.white54,
                                    size: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.channel!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          _currentEpisodeTitle ??
                              widget.title ??
                              'Video Player',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _isTablet ? 24.0 : 20.0,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_videoPlayerController.value.isInitialized) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_formatDuration(_videoPlayerController.value.position)} / ${_formatDuration(_videoPlayerController.value.duration)}',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: _isTablet ? 16.0 : 14.0,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          Row(
            children: [
              _buildModernIconButton(
                icon: Icons.help_outline,
                onPressed: _showGuideDialog,
                highlight: _selectedControlIndex == 1,
                tooltip: 'Guide',
                size: !_isFullScreen ? 24.0 : (_isTablet ? 32.0 : 28.0),
              ),
              SizedBox(width: !_isFullScreen ? 4.0 : 8.0),
              _buildModernIconButton(
                icon: Icons.picture_in_picture_alt,
                onPressed: _enterPipMode,
                tooltip: 'PiP',
                highlight: _selectedControlIndex == 2,
                size: !_isFullScreen ? 24.0 : (_isTablet ? 32.0 : 28.0),
              ),
              SizedBox(width: !_isFullScreen ? 4.0 : 8.0),
              _buildModernIconButton(
                icon: Icons.settings,
                onPressed: _showSettingsDialog,
                highlight: _selectedControlIndex == 3,
                tooltip: 'Settings',
                size: !_isFullScreen ? 24.0 : (_isTablet ? 32.0 : 28.0),
              ),
              SizedBox(width: !_isFullScreen ? 4.0 : 8.0),
              _buildModernIconButton(
                icon: Icons.dns,
                onPressed: _showServerListDialog,
                highlight: _selectedControlIndex == 4,
                tooltip: 'Servers',
                size: !_isFullScreen ? 24.0 : (_isTablet ? 32.0 : 28.0),
              ),
              SizedBox(width: !_isFullScreen ? 4.0 : 8.0),
              _buildModernIconButton(
                icon: _isCurrentEpisodeDownloaded
                    ? Icons.delete_outline
                    : Icons.download,
                onPressed: () {
                  if (_isCurrentEpisodeDownloaded) {
                    _showDeleteDownloadedConfirmDialog();
                  } else {
                    _showDownloadOptionsDialog();
                  }
                },
                highlight: _selectedControlIndex == 9,
                tooltip: _isCurrentEpisodeDownloaded
                    ? 'Delete Download'
                    : 'Download',
                size: !_isFullScreen ? 24.0 : (_isTablet ? 32.0 : 28.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    bool highlight = false,
    double size = 26,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: highlight ? Colors.blue.withOpacity(0.2) : Colors.transparent,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon,
              color: highlight ? Colors.blue : Colors.white, size: size),
          tooltip: tooltip,
          onPressed: onPressed,
          splashRadius: size + 2,
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    // Responsive sizing based on screen size with landscape support
    final isLargeScreen = _screenWidth > 800;
    final isLandscape = _screenWidth > _screenHeight;

    // Adjust spacing and sizes for landscape mode
    final buttonSpacing = isLandscape
        ? (_isTablet ? 48.0 : 36.0)
        : (isLargeScreen ? 40.0 : (_isTablet ? 32.0 : 24.0));
    final largeButtonSpacing = isLandscape
        ? (_isTablet ? 72.0 : 56.0)
        : (isLargeScreen ? 60.0 : (_isTablet ? 48.0 : 32.0));
    final smallButtonSize = isLandscape
        ? (_isTablet ? 88.0 : 72.0)
        : (isLargeScreen ? 72.0 : (_isTablet ? 64.0 : 56.0));
    final largeButtonSize = isLandscape
        ? (_isTablet ? 120.0 : 100.0)
        : (isLargeScreen ? 100.0 : (_isTablet ? 88.0 : 72.0));

    return Container(
      padding: EdgeInsets.symmetric(
          vertical: isLargeScreen ? 32 : (_isTablet ? 24 : 16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.onPrevious != null)
            _buildModernControlButton(
              icon: Icons.skip_previous,
              onPressed: widget.onPrevious!,
              size: smallButtonSize,
            ),
          SizedBox(width: buttonSpacing),
          if (widget.onNext != null)
            _buildModernControlButton(
              icon: Icons.skip_next,
              onPressed: widget.onNext!,
              size: smallButtonSize,
            ),
        ],
      ),
    );
  }

  Widget _buildModernControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    bool isSelected = false,
    double size = 56,
    bool isPrimary = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isPrimary
            ? Colors.transparent
            : (isSelected
                ? Colors.blue.withOpacity(0.25)
                : Colors.black.withOpacity(0.5)),
        border: isSelected && !isPrimary
            ? Border.all(color: Colors.blue, width: 2)
            : null,
        boxShadow: [
          if (isSelected && !isPrimary)
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        icon: Icon(icon,
            color: isPrimary ? Colors.white : Colors.white, size: size * 0.6),
        iconSize: size,
        onPressed: onPressed,
        splashRadius: size * 0.7,
      ),
    );
  }

  Widget _buildBottomControls() {
    final duration = _videoPlayerController.value.duration;
    final position = (_isDragging && _dragValue != null)
        ? Duration(
            milliseconds: (_dragValue! * duration.inMilliseconds).round())
        : _videoPlayerController.value.position;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    // Fully responsive sizing using MediaQuery for all dimensions
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isLandscape = false;

    // Use fractions of screen width/height for all sizing
    double responsiveW(double fraction,
        {double min = 0, double max = double.infinity}) {
      final value = screenWidth * fraction;
      return value.clamp(min, max);
    }

    double responsiveH(double fraction,
        {double min = 0, double max = double.infinity}) {
      final value = screenHeight * fraction;
      return value.clamp(min, max);
    }

    // Padding and radius
    final double padding = !_isFullScreen
        ? 8.0
        : (isLandscape
            ? responsiveW(0.05, min: 8, max: 56)
            : responsiveW(0.035, min: 8, max: 40));
    final double verticalPadding = !_isFullScreen
        ? 6.0
        : (isLandscape
            ? responsiveH(0.04, min: 8, max: 40)
            : responsiveH(0.025, min: 8, max: 32));
    final double borderRadius = !_isFullScreen
        ? 8.0
        : (isLandscape
            ? responsiveW(0.06, min: 8, max: 48)
            : responsiveW(0.045, min: 8, max: 36));

    // Font sizes
    final double timeFontSize = !_isFullScreen
        ? 13.0
        : (isLandscape
            ? responsiveH(0.03, min: 10, max: 28)
            : responsiveH(0.022, min: 10, max: 22));
    final double volumeFontSize = !_isFullScreen
        ? 13.0
        : (isLandscape
            ? responsiveH(0.027, min: 10, max: 24)
            : responsiveH(0.018, min: 10, max: 18));

    // Icon sizes
    final double iconSize = !_isFullScreen
        ? 24.0
        : (isLandscape
            ? responsiveW(0.07, min: 20, max: 56)
            : responsiveW(0.05, min: 18, max: 40));
    final double smallIconSize = !_isFullScreen
        ? 20.0
        : (isLandscape
            ? responsiveW(0.06, min: 16, max: 44)
            : responsiveW(0.04, min: 14, max: 32));

    // Slider sizes
    final double trackHeight = !_isFullScreen
        ? 3.0
        : (isLandscape
            ? responsiveH(0.012, min: 4, max: 14)
            : responsiveH(0.008, min: 3, max: 10));
    final double thumbRadius = !_isFullScreen
        ? 5.0
        : (isLandscape
            ? responsiveH(0.018, min: 6, max: 18)
            : responsiveH(0.012, min: 5, max: 14));
    final double overlayRadius = !_isFullScreen
        ? 10.0
        : (isLandscape
            ? responsiveH(0.035, min: 10, max: 32)
            : responsiveH(0.022, min: 8, max: 24));

    // Fix: Remove all uses of undefined variable isLargeScreen and replace with a computed value.
    // We'll define isLargeScreen based on screenWidth, e.g. > 900 is large.
    final bool isLargeScreen = screenWidth > 900;

    final double largeButtonSize = !_isFullScreen
        ? 48.0
        : (isLandscape
            ? (_isTablet ? 120.0 : 100.0)
            : (isLargeScreen ? 100.0 : (_isTablet ? 88.0 : 72.0)));

    final double smallButtonSize = !_isFullScreen
        ? 36.0
        : (isLandscape
            ? (_isTablet ? 88.0 : 72.0)
            : (isLargeScreen ? 72.0 : (_isTablet ? 64.0 : 56.0)));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.85),
            Colors.black,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(borderRadius)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: isLargeScreen ? 20 : 12,
            offset: Offset(0, isLargeScreen ? -6 : -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar with enhanced styling
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: !_isFullScreen ? 6.0 : (isLargeScreen ? 12 : 8),
                    vertical: !_isFullScreen ? 3.0 : (isLargeScreen ? 6 : 4)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal:
                          !_isFullScreen ? 8.0 : (isLargeScreen ? 20 : 16)),
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.blue[400],
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      thumbColor: Colors.white,
                      trackHeight: trackHeight,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: thumbRadius,
                        elevation: 6,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: overlayRadius,
                      ),
                    ),
                    child: Focus(
                      focusNode: _controlFocusNodes.length > 6
                          ? _controlFocusNodes[6]
                          : null,
                      autofocus: _selectedControlIndex == 16,
                      canRequestFocus: _selectedControlIndex == 16,
                      onKeyEvent: (FocusNode node, KeyEvent event) {
                        if (_selectedControlIndex == 16 &&
                            event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            // Seek forward by 10 seconds
                            final currentPosition =
                                _videoPlayerController.value.position;
                            final videoDuration =
                                _videoPlayerController.value.duration;
                            final newPosition =
                                currentPosition + const Duration(seconds: 10);
                            _videoPlayerController.seekTo(
                              newPosition < videoDuration
                                  ? newPosition
                                  : videoDuration,
                            );
                            return KeyEventResult.handled;
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            // Seek backward by 10 seconds
                            final currentPosition =
                                _videoPlayerController.value.position;
                            final newPosition =
                                currentPosition - const Duration(seconds: 10);
                            _videoPlayerController.seekTo(
                              newPosition > Duration.zero
                                  ? newPosition
                                  : Duration.zero,
                            );
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (value) {
                          setState(() {
                            _dragValue = value;
                          });
                          final videoDuration =
                              _videoPlayerController.value.duration;
                          final newPosition = Duration(
                            milliseconds:
                                (value * videoDuration.inMilliseconds).round(),
                          );
                          _videoPlayerController.seekTo(newPosition);
                        },
                        onChangeStart: (value) {
                          setState(() {
                            _isDragging = true;
                            _dragValue = value;
                          });
                          _hideControlsTimer?.cancel();
                        },
                        onChangeEnd: (value) {
                          setState(() {
                            _isDragging = false;
                            _dragValue = null;
                          });
                          _startHideControlsTimer();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: !_isFullScreen ? 6.0 : (isLargeScreen ? 12 : 8),
                    vertical: !_isFullScreen ? 3.0 : (isLargeScreen ? 6 : 4)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey[700]!, Colors.grey[600]!],
                  ),
                  borderRadius: BorderRadius.circular(isLargeScreen ? 12 : 8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: !_isFullScreen ? 8.0 : (isLargeScreen ? 20 : 16)),

          // // Bottom row with enhanced controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              //           ),
              //         ],
              //       ),
              //       child: Row(
              //         mainAxisSize: MainAxisSize.min,
              //         children: [
              //           _buildModernIconButton(
              //             icon: _videoPlayerController.value.volume > 0
              //                 ? Icons.volume_up
              //                 : Icons.volume_off,
              //             onPressed: () {
              //               final newVolume =
              //                   _videoPlayerController.value.volume > 0
              //                       ? 0.0
              //                       : _currentVolume;
              //               _videoPlayerController.setVolume(newVolume);
              //               setState(() {
              //                 _currentVolume = newVolume;
              //               });
              //             },
              //             tooltip: 'Mute',
              //             size: smallIconSize,
              //           ),
              //           SizedBox(width: isLargeScreen ? 8 : 6),
              //           Text(
              //             '${(_videoPlayerController.value.volume * 100).round()}%',
              //             style: TextStyle(
              //               color: Colors.white,
              //               fontSize: volumeFontSize,
              //               fontWeight: FontWeight.w600,
              //               letterSpacing: 0.3,
              //             ),
              //           ),
              //         ],
              //       ),
              //     ),

              // Right side controls
              Row(
                children: [
                  _buildModernControlButton(
                    icon: Icons.replay_10,
                    onPressed: _skipBackward,
                    isSelected: _selectedControlIndex == 4,
                    size: smallButtonSize,
                  ),
                  SizedBox(width: isLargeScreen ? 12 : 8),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[600]!,
                          Colors.blue[400]!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: isLargeScreen ? 30 : 20,
                          spreadRadius: isLargeScreen ? 3 : 2,
                          offset: Offset(0, isLargeScreen ? 12 : 8),
                        ),
                      ],
                    ),
                    child: _buildModernControlButton(
                      icon: _videoPlayerController.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      onPressed: _togglePlayPause,
                      isSelected: _selectedControlIndex == 5,
                      size: largeButtonSize,
                      isPrimary: true,
                    ),
                  ),
                  SizedBox(width: isLargeScreen ? 12 : 8),
                  _buildModernControlButton(
                    icon: Icons.forward_10,
                    onPressed: _skipForward,
                    isSelected: _selectedControlIndex == 6,
                    size: smallButtonSize,
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isFullScreen &&
                      widget.epishodesQueue != null &&
                      widget.epishodesQueue!.isNotEmpty) ...[
                    _buildModernIconButton(
                      icon: Icons.video_library,
                      onPressed: () {
                        setState(() {
                          _showEpisodesOverlay = !_showEpisodesOverlay;
                        });
                      },
                      tooltip: 'More Episodes',
                      size: iconSize,
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _playNextEpisode,
                      icon: const Icon(Icons.skip_next, color: Colors.white),
                      label: const Text(
                        "Next Episode",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  _buildModernIconButton(
                    icon: _isFullScreen
                        ? Icons.fullscreen_exit
                        : Icons.fullscreen,
                    onPressed: _toggleFullScreen,
                    highlight: _selectedControlIndex == 7,
                    tooltip: 'Fullscreen',
                    size: iconSize,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadIndicator() {
    return Center();
  }

  void _showServerListDialog() {
    final isLargeScreen = _screenWidth > 800;
    final dialogWidth = isLargeScreen ? 400.0 : (_isTablet ? 350.0 : 300.0);
    final titleSize = isLargeScreen ? 22.0 : (_isTablet ? 20.0 : 18.0);
    final itemSize = isLargeScreen ? 18.0 : (_isTablet ? 16.0 : 14.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
        ),
        title: Text('Select Server',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            )),
        content: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: isLargeScreen ? 400.0 : (_isTablet ? 350.0 : 300.0),
          ),
          child: _serversList.isEmpty
              ? const Center(
                  child: Text(
                    'No servers available.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _serversList.length,
                  itemBuilder: (context, index) {
                    final server = _serversList[index];
                    final isVkPrimeServer = server.contains('vkprime');
                    final isCurrent = _currentServerIndex == index &&
                        _isPlayerInitialized &&
                        _videoPlayerController.value.isInitialized &&
                        !_isLoading;

                    return ListTile(
                      title: Text(
                        isVkPrimeServer
                            ? 'Premium Video (vkprime)'
                            : 'Server ${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.blue : Colors.white,
                          fontSize: itemSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      leading: isCurrent
                          ? Icon(Icons.check,
                              color: Colors.blue, size: isLargeScreen ? 28 : 24)
                          : SizedBox(width: isLargeScreen ? 28 : 24),
                      onTap: () {
                        Navigator.pop(context);
                        _resolveServer(index);
                      },
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isLargeScreen ? 16 : 12,
                        vertical: isLargeScreen ? 8 : 4,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    final isLargeScreen = _screenWidth > 800;
    final dialogWidth = isLargeScreen ? 500.0 : (_isTablet ? 400.0 : 320.0);
    final padding = isLargeScreen ? 32.0 : (_isTablet ? 24.0 : 20.0);
    final iconSize = isLargeScreen ? 32.0 : (_isTablet ? 28.0 : 24.0);
    final titleSize = isLargeScreen ? 24.0 : (_isTablet ? 20.0 : 18.0);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(isLargeScreen ? 32 : 24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: isLargeScreen ? 24 : 16,
                offset: Offset(0, isLargeScreen ? 8 : 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue, size: iconSize),
                  SizedBox(width: isLargeScreen ? 16 : 12),
                  Text('Video Settings',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: isLargeScreen ? 28 : 12),
              // Use ListView for the settings options
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return ListTile(
                          leading: Icon(Icons.speed,
                              color: Colors.white,
                              size: isLargeScreen ? 28 : 24),
                          title: Text('Playback Speed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isLargeScreen ? 18 : 16,
                                fontWeight: FontWeight.w500,
                              )),
                          subtitle: Text(
                              '${_isPlayerInitialized ? _videoPlayerController.value.playbackSpeed : 1.0}x',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isLargeScreen ? 16 : 14)),
                          onTap: () => _showSpeedDialog(),
                          tileColor: Colors.grey[850],
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 16 : 12,
                              vertical: isLargeScreen ? 8 : 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  isLargeScreen ? 20 : 16)),
                        );
                      case 1:
                        return SizedBox(height: isLargeScreen ? 12 : 8);
                      case 2:
                        return ListTile(
                          leading: Icon(Icons.info,
                              color: Colors.white,
                              size: isLargeScreen ? 28 : 24),
                          title: Text('Video Info',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isLargeScreen ? 18 : 16,
                                fontWeight: FontWeight.w500,
                              )),
                          onTap: () => _showVideoInfo(),
                          tileColor: Colors.grey[850],
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 16 : 12,
                              vertical: isLargeScreen ? 8 : 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  isLargeScreen ? 20 : 16)),
                        );
                      case 3:
                        return SizedBox(height: isLargeScreen ? 12 : 8);
                      case 4:
                        return ListTile(
                          leading: Icon(Icons.aspect_ratio,
                              color: Colors.white,
                              size: isLargeScreen ? 28 : 24),
                          title: Text('Aspect Ratio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isLargeScreen ? 18 : 16,
                                fontWeight: FontWeight.w500,
                              )),
                          subtitle: Text(
                            _customAspectRatio == null
                                ? 'Default'
                                : _customAspectRatio!.toStringAsFixed(2),
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: isLargeScreen ? 16 : 14),
                          ),
                          onTap: () => _showAspectRatioDialog(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 16 : 12,
                              vertical: isLargeScreen ? 8 : 4),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  isLargeScreen ? 20 : 16)),
                        );
                      case 5:
                        return SizedBox(height: isLargeScreen ? 28 : 20);
                      case 6:
                        return Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                              textStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isLargeScreen ? 18 : 16),
                            ),
                            child: const Text('Close'),
                          ),
                        );
                      default:
                        return SizedBox.shrink();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpeedDialog() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final isLargeScreen = _screenWidth > 800;
    final dialogWidth = isLargeScreen ? 400.0 : (_isTablet ? 350.0 : 300.0);
    final titleSize = isLargeScreen ? 22.0 : (_isTablet ? 20.0 : 18.0);
    final itemSize = isLargeScreen ? 18.0 : (_isTablet ? 16.0 : 14.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
        ),
        title: Text('Playback Speed',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            )),
        content: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            // Set a max height so the list can scroll if needed
            maxHeight: isLargeScreen ? 400.0 : (_isTablet ? 350.0 : 300.0),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: speeds.length,
            itemBuilder: (context, index) {
              final speed = speeds[index];
              return ListTile(
                title: Text('${speed}x',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: itemSize,
                      fontWeight: FontWeight.w500,
                    )),
                leading: (_isPlayerInitialized &&
                        _videoPlayerController.value.playbackSpeed == speed)
                    ? Icon(Icons.check,
                        color: Colors.blue, size: isLargeScreen ? 28 : 24)
                    : SizedBox(width: isLargeScreen ? 28 : 24),
                onTap: () {
                  if (_isPlayerInitialized) {
                    _videoPlayerController.setPlaybackSpeed(speed);
                  }
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 16 : 12,
                  vertical: isLargeScreen ? 8 : 4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showVideoInfo() {
    Navigator.pop(context); // Close settings dialog first

    final isLargeScreen = _screenWidth > 800;
    final dialogWidth = isLargeScreen ? 600.0 : (_isTablet ? 500.0 : 400.0);
    final maxHeight = isLargeScreen ? 700.0 : (_isTablet ? 600.0 : 500.0);
    final titleSize = isLargeScreen ? 22.0 : (_isTablet ? 20.0 : 18.0);
    final labelSize = isLargeScreen ? 14.0 : (_isTablet ? 12.0 : 11.0);
    final valueSize = isLargeScreen ? 14.0 : (_isTablet ? 12.0 : 11.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
        ),
        title: Text('Video Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            )),
        content: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('URL', widget.videoUrl!, labelSize, valueSize),
                if (widget.authToken != null)
                  _buildVideoInfoRow(
                      'Token',
                      widget.authToken!.length > 20
                          ? '${widget.authToken!.substring(0, 20)}...'
                          : widget.authToken!,
                      labelSize,
                      valueSize),
                if (widget.referer != null)
                  _buildVideoInfoRow(
                      'Referer', widget.referer!, labelSize, valueSize),
                if (widget.userAgent != null)
                  _buildVideoInfoRow(
                      'User Agent',
                      widget.userAgent!.length > 50
                          ? '${widget.userAgent!.substring(0, 50)}...'
                          : widget.userAgent!,
                      labelSize,
                      valueSize),
                if (widget.cookies != null)
                  _buildVideoInfoRow(
                      'Cookies',
                      widget.cookies!.length > 30
                          ? '${widget.cookies!.substring(0, 30)}...'
                          : widget.cookies!,
                      labelSize,
                      valueSize),
                if (_isPlayerInitialized &&
                    _videoPlayerController.value.isInitialized) ...[
                  SizedBox(height: isLargeScreen ? 20 : 16),
                  Text('Video Properties:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: isLargeScreen ? 18 : 16,
                      )),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  _buildVideoInfoRow(
                      'Duration',
                      _formatDuration(_videoPlayerController.value.duration),
                      labelSize,
                      valueSize),
                  _buildVideoInfoRow(
                      'Size',
                      '${_videoPlayerController.value.size.width.toInt()}x${_videoPlayerController.value.size.height.toInt()}',
                      labelSize,
                      valueSize),
                  _buildVideoInfoRow(
                      'Aspect Ratio',
                      _videoPlayerController.value.aspectRatio
                          .toStringAsFixed(2),
                      labelSize,
                      valueSize),
                  _buildVideoInfoRow(
                      'Playback Speed',
                      '${_videoPlayerController.value.playbackSpeed}x',
                      labelSize,
                      valueSize),
                  _buildVideoInfoRow(
                      'Volume',
                      '${(_videoPlayerController.value.volume * 100).round()}%',
                      labelSize,
                      valueSize),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: isLargeScreen ? 16 : 14,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfoRow(
      String label, String value, double labelSize, double valueSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: labelSize,
                  color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: valueSize, color: Colors.white),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, double labelSize, double valueSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: labelSize,
                  color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              value.length > 100 ? '${value.substring(0, 100)}...' : value,
              style: TextStyle(fontSize: valueSize, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Aspect Ratio selection
  void _showAspectRatioDialog() {
    final List<Map<String, dynamic>> options = [
      {'label': 'Fit (Default)', 'value': null},
      {
        'label': 'Fill',
        'value': MediaQuery.of(context).size.width /
            MediaQuery.of(context).size.height
      },
      {'label': '16:9', 'value': 16 / 9},
      {'label': '4:3', 'value': 4 / 3},
      if (_isPlayerInitialized)
        {
          'label': 'Original',
          'value': _videoPlayerController.value.aspectRatio
        },
    ];

    final isLargeScreen = _screenWidth > 800;
    final dialogWidth = isLargeScreen ? 400.0 : (_isTablet ? 350.0 : 300.0);
    final titleSize = isLargeScreen ? 22.0 : (_isTablet ? 20.0 : 18.0);
    final itemSize = isLargeScreen ? 18.0 : (_isTablet ? 16.0 : 14.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLargeScreen ? 20 : 16),
        ),
        title: Text('Aspect Ratio',
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.bold,
            )),
        content: Container(
          width: dialogWidth,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              return ListTile(
                title: Text(opt['label'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: itemSize,
                      fontWeight: FontWeight.w500,
                    )),
                leading: (_customAspectRatio == opt['value'])
                    ? Icon(Icons.check,
                        color: Colors.blue, size: isLargeScreen ? 28 : 24)
                    : SizedBox(width: isLargeScreen ? 28 : 24),
                onTap: () {
                  setState(() {
                    _customAspectRatio = opt['value'];
                  });
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 16 : 12,
                  vertical: isLargeScreen ? 8 : 4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showGuideDialog() {
    final isLargeScreen = _screenWidth > 800;
    final dialogWidth = isLargeScreen ? 600.0 : (_isTablet ? 500.0 : 400.0);
    final maxHeight = isLargeScreen ? 700.0 : (_isTablet ? 600.0 : 500.0);
    final padding = isLargeScreen ? 32.0 : (_isTablet ? 24.0 : 20.0);
    final iconSize = isLargeScreen ? 32.0 : (_isTablet ? 28.0 : 24.0);
    final titleSize = isLargeScreen ? 24.0 : (_isTablet ? 20.0 : 18.0);
    final textSize = isLargeScreen ? 16.0 : (_isTablet ? 14.0 : 12.0);
    final sectionTitleSize = isLargeScreen ? 20.0 : (_isTablet ? 18.0 : 16.0);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(isLargeScreen ? 32 : 24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: isLargeScreen ? 24 : 16,
                offset: Offset(0, isLargeScreen ? 8 : 4),
              ),
            ],
          ),
          padding: EdgeInsets.all(padding),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.help_outline,
                        color: Colors.blue, size: iconSize),
                    SizedBox(width: isLargeScreen ? 16 : 12),
                    Text('Controller Guide',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: isLargeScreen ? 28 : 20),
                _buildGuideText(
                    '• OK/Enter: Play/Pause (double press: show/hide controls)',
                    textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText(
                    '• Long Press: 2x speed (hold to speed up, release to return to normal)',
                    textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText('• ←/→: Skip 10s', textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText('• ↑/↓: Volume', textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText('• Back: Exit/Back', textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText(
                    '• Settings: Playback speed, aspect ratio, info', textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText(
                    '• Bluetooth: Connect/disconnect external controllers',
                    textSize),
                SizedBox(height: isLargeScreen ? 12 : 8),
                _buildGuideText(
                    '• Pan left/right: Brightness/Volume (touch only)',
                    textSize),
                SizedBox(height: isLargeScreen ? 28 : 20),
                if (isAndroidTV) ...[
                  Divider(
                      color: Colors.blueGrey, thickness: isLargeScreen ? 2 : 1),
                  SizedBox(height: isLargeScreen ? 16 : 10),
                  Text('Android TV Controls',
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: sectionTitleSize)),
                  SizedBox(height: isLargeScreen ? 16 : 10),
                  _buildGuideText(
                      '• Long OK/Enter: Toggle fullscreen (player is selected in fullscreen)',
                      textSize),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  _buildGuideText(
                      '• In fullscreen: ←/→ = Seek 10s, ↑/↓ = Volume',
                      textSize),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  _buildGuideText(
                      '• In controls mode: arrows move focus, OK/Enter activates control',
                      textSize),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  _buildGuideText(
                      '• F1: Settings, F2: Guide, F3: PiP, F4: Fullscreen, F5: Bluetooth',
                      textSize),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  _buildGuideText(
                      '• Media keys: Play/Pause, Stop, Skip Forward/Backward',
                      textSize),
                  SizedBox(height: isLargeScreen ? 12 : 8),
                  _buildGuideText(
                      '• Back: Exit fullscreen or go back', textSize),
                ],
                SizedBox(height: isLargeScreen ? 28 : 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      textStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isLargeScreen ? 18 : 16),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuideText(String text, double fontSize) {
    return Text(text,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          height: 1.4,
        ));
  }

  void _showDoubleTapFeedback(int direction) {
    setState(() {
      _lastDoubleTapDirection = direction;
    });
    _doubleTapFeedbackTimer?.cancel();
    _doubleTapFeedbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _lastDoubleTapDirection = 0;
        });
      }
    });
  }

  void _showModernSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    if (!_isLoading) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900]!.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[400]!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusText.isNotEmpty ? _statusText : 'Loading Video...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we prepare your content',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoubleTapFeedback() {
    if (_lastDoubleTapDirection == 0) return const SizedBox.shrink();

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.all(_isTablet ? 24 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue[600]!.withOpacity(0.9),
                Colors.blue[400]!.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(_isTablet ? 40 : 32),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            _lastDoubleTapDirection == -1 ? Icons.replay_10 : Icons.forward_10,
            color: Colors.white,
            size: _isTablet ? 56 : 48,
          ),
        ),
      ),
    );
  }

  Widget _buildResumeProgressOverlay() {
    if (!_showResumeOverlayWidget) return const SizedBox.shrink();
    return Positioned(
      bottom: _showControls ? 140 : 40,
      left: 20,
      right: 20,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'We resume your progress. Want to watch from starting?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Focus(
                focusNode: _startOverFocusNode,
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      _handleStartOver();
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: Builder(
                  builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasFocus ? Colors.white : Colors.blue,
                        foregroundColor: hasFocus ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      onPressed: _handleStartOver,
                      child: const Text(
                        'Start Over',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () {
                  setState(() {
                    _showResumeOverlayWidget = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
