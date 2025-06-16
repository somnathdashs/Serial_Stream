import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final Map<String, String>? headers;
  final String? cookies;
  final String? authToken;
  final String? referer;
  final String? userAgent;
  final String? title;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    this.headers,
    this.cookies,
    this.authToken,
    this.referer,
    this.userAgent,
    this.title,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasError = false;
  final FocusNode _focusNode = FocusNode();
  bool showcontorl = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _toggleContoller({show = null}) {
    if (show == null) {
      showcontorl = !showcontorl;
    } else {
      showcontorl = show;
    }
    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControls: showcontorl,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.lightGreen,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          ),
        ),
        autoInitialize: true,
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error,
                    color: Colors.red,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Playback Error',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retryInitialization,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      );
      _isLoading = false;
    });
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Prepare the URL with token if needed
      String finalUrl = _prepareUrlWithToken(widget.videoUrl, widget.authToken);

      // Prepare headers
      Map<String, String> finalHeaders = _prepareHeaders();

      print('🎬 Initializing video player...');
      print('URL: $finalUrl');
      print('Headers: $finalHeaders');

      // Create video player controller with headers
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(finalUrl),
        httpHeaders: finalHeaders,
      );

      // Add error listener
      _videoPlayerController.addListener(_videoPlayerListener);

      // Initialize the controller
      await _videoPlayerController.initialize();

      if (_videoPlayerController.value.hasError) {
        throw Exception(_videoPlayerController.value.errorDescription ??
            'Unknown video error');
      }
      _toggleContoller();
      // Show notification to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Long press "OK" button to enter full screen.'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      print('✅ Video player initialized successfully');
    } catch (e) {
      print('❌ Video player initialization failed: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _prepareUrlWithToken(String baseUrl, String? token) {
    if (token == null || token.isEmpty) return baseUrl;

    // If URL already contains the token, return as is
    if (baseUrl.contains('token=') || baseUrl.contains('auth=')) {
      return baseUrl;
    }

    // Add token as query parameter
    final separator = baseUrl.contains('?') ? '&' : '?';
    return '$baseUrl${separator}token=$token';
  }

  Map<String, String> _prepareHeaders() {
    Map<String, String> finalHeaders = {};

    // Add default headers
    finalHeaders['Accept'] = '*/*';
    finalHeaders['Accept-Encoding'] = 'gzip, deflate, br';
    finalHeaders['Connection'] = 'keep-alive';

    // Add custom headers if provided
    if (widget.headers != null) {
      finalHeaders.addAll(widget.headers!);
    }

    // Add User-Agent
    if (widget.userAgent != null && widget.userAgent!.isNotEmpty) {
      finalHeaders['User-Agent'] = widget.userAgent!;
    } else {
      finalHeaders['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
    }

    // Add Referer
    if (widget.referer != null && widget.referer!.isNotEmpty) {
      finalHeaders['Referer'] = widget.referer!;
    }

    // Add cookies
    if (widget.cookies != null && widget.cookies!.isNotEmpty) {
      finalHeaders['Cookie'] = widget.cookies!;
    }

    // Add Authorization header if token is provided
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      // Check if it's already in headers
      if (!finalHeaders.containsKey('Authorization')) {
        // Try to determine token type
        if (widget.authToken!.startsWith('eyJ')) {
          // Looks like JWT
          finalHeaders['Authorization'] = 'Bearer ${widget.authToken!}';
        } else if (widget.authToken!.toLowerCase().startsWith('bearer ')) {
          // Already has Bearer prefix
          finalHeaders['Authorization'] = widget.authToken!;
        } else if (widget.authToken!.toLowerCase().startsWith('basic ')) {
          // Basic auth
          finalHeaders['Authorization'] = widget.authToken!;
        } else {
          // Default to Bearer
          finalHeaders['Authorization'] = 'Bearer ${widget.authToken!}';
        }
      }
    }

    // Add origin if referer is available
    if (widget.referer != null) {
      try {
        final uri = Uri.parse(widget.referer!);
        finalHeaders['Origin'] = '${uri.scheme}://${uri.host}';
      } catch (e) {
        print('Failed to parse referer for Origin header: $e');
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

  void _retryInitialization() {
    _videoPlayerController.removeListener(_videoPlayerListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    _initializePlayer();
  }

  void _showVideoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('URL', widget.videoUrl),
              if (widget.authToken != null)
                _buildInfoRow('Token', '${widget.authToken!}'),
              if (widget.referer != null)
                _buildInfoRow('Referer', widget.referer!),
              if (widget.userAgent != null)
                _buildInfoRow('User Agent', widget.userAgent!),
              if (widget.cookies != null)
                _buildInfoRow('Cookies', widget.cookies!),
              if (widget.headers != null && widget.headers!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Headers:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...widget.headers!.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Text('${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              if (_videoPlayerController.value.isInitialized) ...[
                const SizedBox(height: 8),
                _buildInfoRow('Duration',
                    _formatDuration(_videoPlayerController.value.duration)),
                _buildInfoRow('Size',
                    '${_videoPlayerController.value.size.width.toInt()}x${_videoPlayerController.value.size.height.toInt()}'),
                _buildInfoRow(
                    'Aspect Ratio',
                    _videoPlayerController.value.aspectRatio
                        .toStringAsFixed(2)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
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
    _videoPlayerController.removeListener(_videoPlayerListener);
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _handleTVRemoteKey(KeyEvent event) {
    Timer? _longPressTimer;
    if (event is KeyEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.space) {
        if (event is KeyDownEvent) {
          // Start long press timer
          _longPressTimer = Timer(const Duration(seconds: 1), () {
            _chewieController!.enterFullScreen();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Long press "Back" button to exit full screen.'),
                duration: Duration(seconds: 2),
              ),
            );
          });
        } else if (event is KeyUpEvent) {
          _longPressTimer!.cancel();
          if (_videoPlayerController.value.isPlaying) {
            _videoPlayerController.pause();
          } else {
            _videoPlayerController.play();
          }
        }
      }

      if (key == LogicalKeyboardKey.arrowRight) {
        _toggleContoller(show: true);
        _videoPlayerController.seekTo(
          _videoPlayerController.value.position + const Duration(seconds: 10),
        );
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _toggleContoller(show: true);
        _videoPlayerController.seekTo(
          _videoPlayerController.value.position - const Duration(seconds: 10),
        );
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _toggleContoller(show: true);
        double currentVolume = _videoPlayerController.value.volume;
        double newVolume = currentVolume + 0.1;
        if (newVolume > 1.0) newVolume = 1.0;
        _videoPlayerController.setVolume(newVolume);
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _toggleContoller(show: true);
        double currentVolume = _videoPlayerController.value.volume;
        double newVolume = currentVolume - 0.1;
        if (newVolume < 0.0) newVolume = 0.0;
        _videoPlayerController.setVolume(newVolume);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: _handleTVRemoteKey,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(widget.title ?? 'M3U8 Video Player'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            actions: [
              // IconButton(
              //   icon: const Icon(Icons.info_outline),
              //   onPressed: _showVideoInfo,
              // ),
              if (_hasError)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _retryInitialization,
                ),
            ],
          ),
          body: Center(
            child: _buildVideoWidget(),
          ),
        ));
  }

  Widget _buildVideoWidget() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _retryInitialization,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _showVideoInfo,
                  icon: const Icon(Icons.info),
                  label: const Text('Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_chewieController != null &&
        _chewieController!.videoPlayerController.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _videoPlayerController.value.aspectRatio ?? 16 / 9,
        child: Chewie(
          controller: _chewieController!,
        ),
      );
    }

    return const Text(
      'Video not available',
      style: TextStyle(color: Colors.white),
    );
  }
}
