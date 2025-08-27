import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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

class EnhancedVideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final Map<String, String>? headers;
  final String? cookies;
  final String? authToken;
  final String? referer;
  final String? userAgent;
  final String? title;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const EnhancedVideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    this.headers,
    this.cookies,
    this.authToken,
    this.referer,
    this.userAgent,
    this.title,
    this.onNext,
    this.onPrevious,
  }) : super(key: key);

  @override
  _EnhancedVideoPlayerScreenState createState() =>
      _EnhancedVideoPlayerScreenState();
}

class _EnhancedVideoPlayerScreenState extends State<EnhancedVideoPlayerScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoPlayerController;
  bool _isLoading = true;
  bool _showControls = true;
  bool _isFullScreen = false;
  String? _errorMessage;
  bool _hasError = false;

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
  bool _showVolumeSlider = false;
  bool _showBrightnessSlider = false;
  double _currentVolume = 0.5;
  double _currentBrightness = 0.5;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

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
  final FocusNode _fullscreenFocusNode = FocusNode();

  int _selectedControlIndex = 5;
  final List<FocusNode> _controlFocusNodes = [];

  // Aspect Ratio selection
  double? _customAspectRatio = 16 / 9; // Default to 16:9

  final Floating _floating = Floating();

  // Add state for double-tap feedback
  int _lastDoubleTapDirection = 0; // -1 for left, 1 for right
  Timer? _doubleTapFeedbackTimer;

  // Add pan start position for gesture direction
  Offset? _panStartPosition;

  // Add a cancel token for Dio
  CancelToken? _downloadCancelToken;

  // Bluetooth control state
  bool _isBluetoothConnected = false;
  String? _bluetoothDeviceName;
  Timer? _bluetoothCheckTimer;

  // Android TV detection
  bool get isAndroidTV =>
      Platform.isAndroid && _isTablet && _screenWidth > 1000;

  // Responsive design variables
  late double _screenWidth;
  late double _screenHeight;
  late bool _isLandscape;
  late bool _isTablet;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePlayer();
    _initializeVolume();
    _initializeBrightness();
    _setupControlFocusNodes();
    _initializeBluetooth();
    KeepScreenOn.turnOn(); // Keep screen awake
    // Request focus for TV navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mainFocusNode.requestFocus();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
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

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      String finalUrl = _prepareUrlWithToken(widget.videoUrl, widget.authToken);
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

      _videoPlayerController.play();
      KeepScreenOn.turnOn(); // Enable keep-on when playing
      _startHideControlsTimer();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Use remote control for navigation. Long press OK for fullscreen.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
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
      'User-Agent': widget.userAgent ??
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    };

    if (widget.headers != null) {
      finalHeaders.addAll(widget.headers!);
    }

    if (widget.referer != null && widget.referer!.isNotEmpty) {
      finalHeaders['Referer'] = widget.referer!;
      try {
        final uri = Uri.parse(widget.referer!);
        finalHeaders['Origin'] = '${uri.scheme}://${uri.host}';
      } catch (e) {
        print('Failed to parse referer: $e');
      }
    }

    if (widget.cookies != null && widget.cookies!.isNotEmpty) {
      finalHeaders['Cookie'] = widget.cookies!;
    }

    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      if (!finalHeaders.containsKey('Authorization')) {
        if (widget.authToken!.startsWith('eyJ')) {
          finalHeaders['Authorization'] = 'Bearer ${widget.authToken!}';
        } else if (widget.authToken!.toLowerCase().startsWith('bearer ') ||
            widget.authToken!.toLowerCase().startsWith('basic ')) {
          finalHeaders['Authorization'] = widget.authToken!;
        } else {
          finalHeaders['Authorization'] = 'Bearer ${widget.authToken!}';
        }
      }
    }

    return finalHeaders;
  }

  void _videoPlayerListener() {
    if (_videoPlayerController.value.hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _videoPlayerController.value.errorDescription ??
            'Video playback error';
      });
    }
  }

  void _togglePlayPause() {
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
    final position = _videoPlayerController.value.position;
    final newPosition = position + const Duration(seconds: 10);
    _videoPlayerController.seekTo(newPosition);
    _showControlsTemporarily();
  }

  void _skipBackward() {
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
    _videoPlayerController.setVolume(newVolume);
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

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;
    if (!widget.videoUrl.endsWith('.m3u8')) {
      // Download non-m3u8 video file
      if (await Permission.storage.request().isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Storage permission required for download')),
        );
        return;
      }
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });
      try {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getApplicationDocumentsDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
        final fileName = widget.videoUrl.split('/').last.split('?').first;
        final file = File('${directory.path}/$fileName');
        final dio = Dio();
        await dio.download(
          widget.videoUrl,
          file.path,
          onReceiveProgress: (received, total) {
            setState(() {
              _downloadProgress = total > 0 ? received / total : 0.0;
            });
          },
          options: Options(headers: _prepareHeaders()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video downloaded to: ${file.path}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      } finally {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
      return;
    }
    // Request storage permission
    if (await Permission.storage.request().isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Storage permission required for download')),
      );
      return;
    }
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    _downloadCancelToken = CancelToken();
    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }
      final folder = Directory(
          '${directory.path}/m3u8_${DateTime.now().millisecondsSinceEpoch}');
      await folder.create(recursive: true);
      final dio = Dio();
      // Download m3u8 playlist
      final playlistResp = await dio.get(widget.videoUrl,
          options: Options(headers: _prepareHeaders()),
          cancelToken: _downloadCancelToken);
      final playlistContent = playlistResp.data.toString();
      final playlistFile = File('${folder.path}/playlist.m3u8');
      await playlistFile.writeAsString(playlistContent);
      // Parse and download segments
      final segmentUrls = RegExp(r'^([^#][^\n]*)', multiLine: true)
          .allMatches(playlistContent)
          .map((m) => m.group(1)!.trim())
          .where((line) =>
              line.isNotEmpty &&
              !line.startsWith('http') &&
              !line.startsWith('#'))
          .toList();
      int downloaded = 0;
      for (final segment in segmentUrls) {
        if (_downloadCancelToken?.isCancelled == true) break;
        final segmentUrl =
            Uri.parse(widget.videoUrl).resolve(segment).toString();
        final segmentResp = await dio.get<List<int>>(
          segmentUrl,
          options: Options(
              responseType: ResponseType.bytes, headers: _prepareHeaders()),
          cancelToken: _downloadCancelToken,
        );
        final segmentFile = File('${folder.path}/$segment');
        await segmentFile.writeAsBytes(segmentResp.data!);
        downloaded++;
        setState(() {
          _downloadProgress = downloaded / segmentUrls.length;
        });
      }
      if (_downloadCancelToken?.isCancelled == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download cancelled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('m3u8 video downloaded to: ${folder.path}')),
        );
      }
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download cancelled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
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
          _videoPlayerController.seekTo(Duration.zero);
          _videoPlayerController.pause();
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
      _selectedControlIndex =
          (_selectedControlIndex + direction) % _controlFocusNodes.length;
      if (_selectedControlIndex < 0) {
        _selectedControlIndex = _controlFocusNodes.length - 1;
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
      case 4: // 10s backward
        _skipBackward();
        break;
      case 5: // PLay/Pause btn
        _togglePlayPause();
        break;
      case 6: // 10s Forward
        _skipForward();
        break;
      case 7: // Fullscreen
        _toggleFullScreen();
        break;
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
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
    _controlsAnimationController.dispose();
    _volumeAnimationController.dispose();
    _brightnessAnimationController.dispose();
    _fadeAnimationController.dispose();
    _scaleAnimationController.dispose();
    _hideControlsTimer?.cancel();
    _longPressTimer?.cancel();
    _doubleTapFeedbackTimer?.cancel();
    _bluetoothCheckTimer?.cancel();
    _videoPlayerController.removeListener(_videoPlayerListener);
    _videoPlayerController.dispose();

    for (final focusNode in _controlFocusNodes) {
      focusNode.dispose();
    }
    _mainFocusNode.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    KeepScreenOn.turnOff(); // Release keep-on on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Update responsive variables
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isLandscape = _screenWidth > _screenHeight;
    _isTablet = _screenWidth > 600;

    return KeyboardListener(
      focusNode: _mainFocusNode,
      onKeyEvent: (event) {
        _handleTVRemoteKey(event);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
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
            onLongPressStart: (_) {
              _videoPlayerController.setPlaybackSpeed(2.0);
              _showModernSnackBar('Playback speed: 2x', Icons.speed);
            },
            onLongPressEnd: (_) {
              _videoPlayerController.setPlaybackSpeed(1.0);
              _showModernSnackBar('Playback speed: 1x', Icons.speed);
            },
            onPanStart: (details) {
              _isDragging = true;
              _panStartPosition = details.localPosition;
            },
            onPanUpdate: (details) {
              if (_panStartPosition != null) {
                // Only vertical pan: left=brightness, right=volume
                if (_panStartPosition!.dx < _screenWidth * 0.3) {
                  final delta = -details.delta.dy / _screenHeight;
                  _adjustBrightness(delta);
                } else if (_panStartPosition!.dx > _screenWidth * 0.7) {
                  final delta = -details.delta.dy / _screenHeight;
                  _adjustVolume(delta);
                }
              }
            },
            onPanEnd: (details) {
              _isDragging = false;
              _panStartPosition = null;
              _startHideControlsTimer();
            },
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
                // Place sliders above video but below controls so controls remain responsive
                _buildVolumeSlider(),
                _buildBrightnessSlider(),
                _buildCustomControls(),
                if (_isDownloading) _buildDownloadIndicator(),
                _buildDoubleTapFeedback(),
                _buildLoadingOverlay(),
              ],
            ),
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

    if (_videoPlayerController.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_isTablet ? 16 : 8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isTablet ? 16 : 8),
          child: AspectRatio(
            aspectRatio:
                _customAspectRatio ?? _videoPlayerController.value.aspectRatio,
            child: VideoPlayer(_videoPlayerController),
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
    final sliderWidth =
        isLargeScreen ? (_isTablet ? 100.0 : 80.0) : (_isTablet ? 80.0 : 60.0);
    final verticalPadding = isLargeScreen
        ? (_isTablet ? 160.0 : 140.0)
        : (_isTablet ? 120.0 : 100.0);
    final iconSize =
        isLargeScreen ? (_isTablet ? 36.0 : 32.0) : (_isTablet ? 28.0 : 24.0);
    final iconPadding =
        isLargeScreen ? (_isTablet ? 16.0 : 14.0) : (_isTablet ? 12.0 : 10.0);
    final borderRadius =
        isLargeScreen ? (_isTablet ? 20.0 : 18.0) : (_isTablet ? 16.0 : 12.0);
    final trackHeight =
        isLargeScreen ? (_isTablet ? 8.0 : 8.0) : (_isTablet ? 6.0 : 4.0);
    final thumbRadius =
        isLargeScreen ? (_isTablet ? 10.0 : 10.0) : (_isTablet ? 8.0 : 6.0);
    final overlayRadius =
        isLargeScreen ? (_isTablet ? 20.0 : 20.0) : (_isTablet ? 16.0 : 12.0);
    final percentageFontSize =
        isLargeScreen ? (_isTablet ? 14.0 : 14.0) : (_isTablet ? 12.0 : 10.0);

    return Positioned(
      left: 20,
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
              SizedBox(height: isLargeScreen ? 20 : 16),

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
              SizedBox(height: isLargeScreen ? 20 : 16),

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
    final sliderWidth =
        isLargeScreen ? (_isTablet ? 100.0 : 80.0) : (_isTablet ? 80.0 : 60.0);
    final verticalPadding = isLargeScreen
        ? (_isTablet ? 160.0 : 140.0)
        : (_isTablet ? 120.0 : 100.0);
    final iconSize =
        isLargeScreen ? (_isTablet ? 36.0 : 32.0) : (_isTablet ? 28.0 : 24.0);
    final iconPadding =
        isLargeScreen ? (_isTablet ? 16.0 : 14.0) : (_isTablet ? 12.0 : 10.0);
    final borderRadius =
        isLargeScreen ? (_isTablet ? 20.0 : 18.0) : (_isTablet ? 16.0 : 12.0);
    final trackHeight =
        isLargeScreen ? (_isTablet ? 8.0 : 8.0) : (_isTablet ? 6.0 : 4.0);
    final thumbRadius =
        isLargeScreen ? (_isTablet ? 10.0 : 10.0) : (_isTablet ? 8.0 : 6.0);
    final overlayRadius =
        isLargeScreen ? (_isTablet ? 20.0 : 20.0) : (_isTablet ? 16.0 : 12.0);
    final percentageFontSize =
        isLargeScreen ? (_isTablet ? 14.0 : 14.0) : (_isTablet ? 12.0 : 10.0);

    return Positioned(
      right: 20,
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
              SizedBox(height: isLargeScreen ? 20 : 16),

              // Enhanced slider container
              Expanded(
                child: Container(
                  padding:
                      EdgeInsets.symmetric(vertical: 2),
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
              SizedBox(height: isLargeScreen ? 20 : 16),

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
    if (!_showControls || !_videoPlayerController.value.isInitialized) {
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
                Colors.black.withOpacity(0.7),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: Column(
            children: [
              _buildTopControls(),
              const Spacer(),
              _buildCenterControls(),
              const Spacer(),
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isTablet ? 24 : 16,
        vertical: _isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
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
              size: _isTablet ? 32 : 28,
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title ?? 'Video Player',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _isTablet ? 24 : 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_videoPlayerController.value.isInitialized) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_formatDuration(_videoPlayerController.value.position)} / ${_formatDuration(_videoPlayerController.value.duration)}',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: _isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Row(
            children: [
              _buildModernIconButton(
                icon: Icons.help_outline,
                onPressed: _showGuideDialog,
                highlight: _selectedControlIndex == 1,
                tooltip: 'Guide',
                size: _isTablet ? 32 : 28,
              ),
              const SizedBox(width: 8),
              _buildModernIconButton(
                icon: Icons.picture_in_picture_alt,
                onPressed: _enterPipMode,
                tooltip: 'PiP',
                highlight: _selectedControlIndex == 2,
                size: _isTablet ? 32 : 28,
              ),
              const SizedBox(width: 8),
              _buildModernIconButton(
                icon: Icons.settings,
                onPressed: _showSettingsDialog,
                highlight: _selectedControlIndex == 3,
                tooltip: 'Settings',
                size: _isTablet ? 32 : 28,
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
    final position = _videoPlayerController.value.position;
    final duration = _videoPlayerController.value.duration;
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
    final padding = isLandscape
        ? responsiveW(0.05, min: 8, max: 56)
        : responsiveW(0.035, min: 8, max: 40);
    final verticalPadding = isLandscape
        ? responsiveH(0.04, min: 8, max: 40)
        : responsiveH(0.025, min: 8, max: 32);
    final borderRadius = isLandscape
        ? responsiveW(0.06, min: 8, max: 48)
        : responsiveW(0.045, min: 8, max: 36);

    // Font sizes
    final timeFontSize = isLandscape
        ? responsiveH(0.03, min: 10, max: 28)
        : responsiveH(0.022, min: 10, max: 22);
    final volumeFontSize = isLandscape
        ? responsiveH(0.027, min: 10, max: 24)
        : responsiveH(0.018, min: 10, max: 18);

    // Icon sizes
    final iconSize = isLandscape
        ? responsiveW(0.07, min: 20, max: 56)
        : responsiveW(0.05, min: 18, max: 40);
    final smallIconSize = isLandscape
        ? responsiveW(0.06, min: 16, max: 44)
        : responsiveW(0.04, min: 14, max: 32);

    // Slider sizes
    final trackHeight = isLandscape
        ? responsiveH(0.012, min: 4, max: 14)
        : responsiveH(0.008, min: 3, max: 10);
    final thumbRadius = isLandscape
        ? responsiveH(0.018, min: 6, max: 18)
        : responsiveH(0.012, min: 5, max: 14);
    final overlayRadius = isLandscape
        ? responsiveH(0.035, min: 10, max: 32)
        : responsiveH(0.022, min: 8, max: 24);

    // Fix: Remove all uses of undefined variable isLargeScreen and replace with a computed value.
    // We'll define isLargeScreen based on screenWidth, e.g. > 900 is large.
    final bool isLargeScreen = screenWidth > 900;

    final largeButtonSize = isLandscape
        ? (_isTablet ? 120.0 : 100.0)
        : (isLargeScreen ? 100.0 : (_isTablet ? 88.0 : 72.0));

        final smallButtonSize = isLandscape
        ? (_isTablet ? 88.0 : 72.0)
        : (isLargeScreen ? 72.0 : (_isTablet ? 64.0 : 56.0));

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
            Colors.black.withOpacity(0.4),
            Colors.black.withOpacity(0.7),
            Colors.black.withOpacity(0.9),
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
                    horizontal: isLargeScreen ? 12 : 8,
                    vertical: isLargeScreen ? 6 : 4),
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
                  padding:
                      EdgeInsets.symmetric(horizontal: isLargeScreen ? 20 : 16),
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
                          final videoDuration =
                              _videoPlayerController.value.duration;
                          final newPosition = Duration(
                            milliseconds:
                                (value * videoDuration.inMilliseconds).round(),
                          );
                          _videoPlayerController.seekTo(newPosition);
                        },
                        onChangeStart: (value) {
                          _isDragging = true;
                          _hideControlsTimer?.cancel();
                        },
                        onChangeEnd: (value) {
                          _isDragging = false;
                          _startHideControlsTimer();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isLargeScreen ? 12 : 8,
                    vertical: isLargeScreen ? 6 : 4),
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
          SizedBox(height: isLargeScreen ? 20 : 16),

          // // Bottom row with enhanced controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          //     // Volume control with enhanced styling
          //     Container(
          //       padding: EdgeInsets.symmetric(
          //           horizontal: isLargeScreen ? 16 : 12,
          //           vertical: isLargeScreen ? 8 : 6),
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           colors: [
          //             Colors.black.withOpacity(0.7),
          //             Colors.black.withOpacity(0.5),
          //           ],
          //         ),
          //         borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 12),
          //         border: Border.all(
          //           color: Colors.white.withOpacity(0.2),
          //           width: 1,
          //         ),
          //         boxShadow: [
          //           BoxShadow(
          //             color: Colors.black.withOpacity(0.3),
          //             blurRadius: 8,
          //             offset: const Offset(0, 2),
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
              _buildModernIconButton(
                icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                onPressed: _toggleFullScreen,
                highlight: _selectedControlIndex == 7,
                tooltip: 'Fullscreen',
                size: iconSize,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadIndicator() {
    return Positioned(
      top: 100,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 8),
            Text(
              _downloadProgress > 0
                  ? 'Downloading ${(_downloadProgress * 100).toStringAsFixed(1)}%'
                  : 'Preparing download...',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (_isDownloading)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _downloadCancelToken?.cancel();
                },
                icon: const Icon(Icons.cancel, size: 18),
                label: const Text('Cancel'),
              ),
          ],
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
                              '${_videoPlayerController.value.playbackSpeed}x',
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
                leading: _videoPlayerController.value.playbackSpeed == speed
                    ? Icon(Icons.check,
                        color: Colors.blue, size: isLargeScreen ? 28 : 24)
                    : SizedBox(width: isLargeScreen ? 28 : 24),
                onTap: () {
                  _videoPlayerController.setPlaybackSpeed(speed);
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
                _buildInfoRow('URL', widget.videoUrl, labelSize, valueSize),
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
                if (_videoPlayerController.value.isInitialized) ...[
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
      {'label': 'Original', 'value': _videoPlayerController.value.aspectRatio},
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
                  const Text(
                    'Loading Video...',
                    style: TextStyle(
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
}
