import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:serial_stream/Screens/VideoPlayer/ModernWebPlayer.dart';

class M3U8UrlInfo {
  final String url;
  final String source;
  final DateTime timestamp;
  final Map<String, String> headers;
  final String? referer;
  final String? userAgent;
  final String? cookies;
  final String? authToken;
  final Map<String, dynamic> metadata;

  M3U8UrlInfo({
    required this.url,
    required this.source,
    required this.timestamp,
    this.headers = const {},
    this.referer,
    this.userAgent,
    this.cookies,
    this.authToken,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'source': source,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'headers': headers,
      'referer': referer,
      'userAgent': userAgent,
      'cookies': cookies,
      'authToken': authToken,
      'metadata': metadata,
    };
  }

  String get formattedUrl {
    if (headers.isEmpty && authToken == null) return url;

    String result = url;
    if (authToken != null) {
      final separator = url.contains('?') ? '&' : '?';
      result += '${separator}token=$authToken';
    }
    return result;
  }
}

class M3U8WebViewScanner extends StatefulWidget {
  final String initialUrl;
  final String epishodeName;
  final String showImageUrl;
  final String channel;
  final List epishodesQueue;

  const M3U8WebViewScanner({
    Key? key,
    required this.initialUrl,
    required this.epishodeName,
    required this.showImageUrl,
    required this.channel,
    required this.epishodesQueue,
  }) : super(key: key);

  @override
  _M3U8WebViewScannerState createState() => _M3U8WebViewScannerState();
}

class _M3U8WebViewScannerState extends State<M3U8WebViewScanner>
    with SingleTickerProviderStateMixin {
  InAppWebViewController? webViewController;
  final List<M3U8UrlInfo> detectedUrls = [];
  final List<NetworkRequest> networkRequests = [];
  bool isScanning = false;
  bool isAutoShowEnabled = true; // Auto-show detected URLs
  String currentUrl = '';
  String currentUserAgent = '';
  Map<String, String> currentCookies = {};

  // Animation controller for smooth transitions
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Add these variables to your state class
  Timer? _scanningTimer;
  Timer? _inactivityTimer;
  int _lastDetectedCount = 0;
  final int _inactivityTimeoutSeconds =
      20; // Stop after 30 seconds of no new URLs
  final int _maxScanDurationMinutes = 5; // Maximum scan time

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _toggleScanning();
    isAutoShowEnabled = true;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopScanning();
    super.dispose();
  }

  // Auto-show detected URLs when first video is found
  void _autoShowDetectedUrls() {
    if (isAutoShowEnabled && detectedUrls.isNotEmpty) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          _showModernDetectedUrls();
        }
      });
    }
  }

  void _showModernDetectedUrls() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[50]!,
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[400]!, Colors.blue[600]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(Icons.video_library,
                          color: Colors.white, size: 24),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detected Videos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            '${detectedUrls.length} video${detectedUrls.length != 1 ? 's' : ''} found',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: detectedUrls.isEmpty
                    ? _buildEmptyState()
                    : _buildVideoList(scrollController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No Videos Found Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Navigate to a video page to start detecting',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(ScrollController scrollController) {
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: detectedUrls.length,
      itemBuilder: (context, index) {
        final urlInfo = detectedUrls[index];
        return _buildVideoCard(urlInfo, index);
      },
    );
  }

  Widget _buildVideoCard(M3U8UrlInfo urlInfo, int index) {
    final hasAuth = urlInfo.authToken != null;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with play button
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Video thumbnail placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasAuth
                          ? [Colors.green[400]!, Colors.green[600]!]
                          : [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Video ${index + 1}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          if (hasAuth) ...[
                            SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.security,
                                      size: 12, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Auth',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        urlInfo.source,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick action buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQuickAction(
                      icon: Icons.info_outline,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _showModernUrlDetails(urlInfo, index + 1);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Play button
          Container(
            width: double.infinity,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _testPlayUrl(urlInfo);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: hasAuth ? Colors.green : Colors.blue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Play Video',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  void _showModernUrlDetails(M3U8UrlInfo urlInfo, int videoNumber) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[400]!, Colors.blue[600]!],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Video $videoNumber Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('URL', urlInfo.url,
                          isSelectable: true),
                      _buildDetailSection('Source', urlInfo.source),
                      _buildDetailSection(
                          'Timestamp', urlInfo.timestamp.toString()),
                      if (urlInfo.authToken != null)
                        _buildDetailSection('Auth Token', urlInfo.authToken!,
                            isSelectable: true,
                            isHighlighted: true,
                            color: Colors.green),
                      if (urlInfo.formattedUrl != urlInfo.url)
                        _buildDetailSection(
                            'Formatted URL', urlInfo.formattedUrl,
                            isSelectable: true,
                            isHighlighted: true,
                            color: Colors.blue),
                      if (urlInfo.referer != null)
                        _buildDetailSection('Referer', urlInfo.referer!,
                            isSelectable: true),
                      if (urlInfo.userAgent != null)
                        _buildDetailSection('User Agent', urlInfo.userAgent!,
                            isSelectable: true),
                      if (urlInfo.cookies != null &&
                          urlInfo.cookies!.isNotEmpty)
                        _buildDetailSection('Cookies', urlInfo.cookies!,
                            isSelectable: true),
                      if (urlInfo.headers.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text('Headers:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        ...urlInfo.headers.entries.map((e) =>
                            _buildDetailSection(e.key, e.value,
                                isSelectable: true, isSubItem: true)),
                      ],
                      if (urlInfo.metadata.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Text('Metadata:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        ...urlInfo.metadata.entries.map((e) =>
                            _buildDetailSection(e.key, e.value.toString(),
                                isSubItem: true)),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _testPlayUrl(urlInfo);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Play Video'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    String label,
    String value, {
    bool isSelectable = false,
    bool isHighlighted = false,
    bool isSubItem = false,
    Color? color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12, left: isSubItem ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: TextStyle(
              fontSize: isSubItem ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: color ?? (isHighlighted ? Colors.blue : Colors.grey[700]),
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? Colors.grey[100])!.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: isHighlighted
                  ? Border.all(color: (color ?? Colors.blue).withOpacity(0.5))
                  : null,
            ),
            child: isSelectable
                ? SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: color ?? Colors.grey[800],
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: color ?? Colors.grey[800],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Enhanced status bar to show auto-stop info
  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: isScanning
          ? Colors.green.withOpacity(0.1)
          : Colors.grey.withOpacity(0.1),
      child: Row(
        children: [
          Text('M3U8 URLs: ${detectedUrls.length}'),
          Spacer(),
          if (isScanning) ...[
            Icon(Icons.radar, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text('Scanning...', style: TextStyle(color: Colors.green)),
            SizedBox(width: 8),
            Text('Auto-stop: ${_inactivityTimeoutSeconds}s',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ] else
            Text('Stopped', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Video Scanner',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          // Detected URLs count badge
          if (detectedUrls.isNotEmpty)
            Container(
              margin: EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: _showModernDetectedUrls,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue[400]!, Colors.blue[600]!],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.video_library, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '${detectedUrls.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _toggleScanning();
              webViewController?.reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern status bar
          _buildStatusBar(),

          // WebView
          Expanded(
            child: (!isScanning) 
              ? Center(
                  child: ElevatedButton.icon(
                    onPressed: _showModernDetectedUrls,
                    icon: Icon(Icons.play_arrow_rounded),
                    label: Text('View Videos'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              : InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
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
                    webViewController = controller;
                    _setupJavaScriptInterfaces(controller);
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      currentUrl = url?.toString() ?? '';
                    });
                    _getCurrentCookies();
                    _getCurrentUserAgent();
                  },
                  shouldInterceptRequest: (controller, request) async {
                    if (isScanning) {
                      await _interceptNetworkRequest(request);
                    }
                    return null;
                  },
                  onConsoleMessage: (controller, consoleMessage) {
                    if (isScanning) {
                      _scanConsoleMessage(consoleMessage.message);
                    }
                  },
                  onLoadResource: (controller, resource) {
                    if (isScanning) {
                      _scanResourceUrl(resource.url.toString());
                    }
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _setupJavaScriptInterfaces(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: 'networkRequestHandler',
      callback: (args) {
        if (isScanning && args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          _handleJavaScriptNetworkData(data);
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'tokenExtractor',
      callback: (args) {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          _handleExtractedTokens(data);
        }
      },
    );

    _injectAdvancedNetworkMonitoringScript(controller);
  }

  void _injectAdvancedNetworkMonitoringScript(
      InAppWebViewController controller) {
    const jsCode = '''
      (function() {
        // Store original functions
        const originalXHROpen = XMLHttpRequest.prototype.open;
        const originalXHRSend = XMLHttpRequest.prototype.send;
        const originalFetch = window.fetch;
        
        // Token extraction patterns
        const tokenPatterns = [
          /token[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /auth[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /access_token[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /bearer[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /key[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /session[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /jwt[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /apikey[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
          /authorization[=:]\\s*['"]*([^'",\\s]+)['"]*/, 
        ];
        
        // Extract tokens from text
        function extractTokens(text, source) {
          const tokens = {};
          tokenPatterns.forEach((pattern, index) => {
            const match = text.match(pattern);
            if (match && match[1]) {
              const tokenName = ['token', 'auth', 'access_token', 'bearer', 'key', 'session', 'jwt', 'apikey', 'authorization'][index];
              tokens[tokenName] = match[1];
            }
          });
          
          // Look for JWT tokens
          const jwtPattern = /eyJ[A-Za-z0-9-_]+\\.[A-Za-z0-9-_]+\\.[A-Za-z0-9-_]*/g;
          const jwtMatches = text.match(jwtPattern);
          if (jwtMatches) {
            jwtMatches.forEach((jwt, i) => {
              tokens['jwt_' + i] = jwt;
            });
          }
          
          if (Object.keys(tokens).length > 0) {
            window.flutter_inappwebview.callHandler('tokenExtractor', {
              tokens: tokens,
              source: source,
              timestamp: Date.now()
            });
          }
        }
        
        // Extract headers from request
        function extractHeaders(xhr) {
          const headers = {};
          try {
            const authHeader = xhr.getRequestHeader('Authorization');
            if (authHeader) headers['Authorization'] = authHeader;
            
            const contentType = xhr.getRequestHeader('Content-Type');
            if (contentType) headers['Content-Type'] = contentType;
            
            const referer = xhr.getRequestHeader('Referer');
            if (referer) headers['Referer'] = referer;
            
            const userAgent = xhr.getRequestHeader('User-Agent');
            if (userAgent) headers['User-Agent'] = userAgent;
          } catch (e) {}
          return headers;
        }
        
        // Intercept XMLHttpRequest
        XMLHttpRequest.prototype.open = function(method, url, async, user, password) {
          this._method = method;
          this._url = url;
          this._headers = {};
          
          return originalXHROpen.apply(this, arguments);
        };
        
        XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
          this._headers = this._headers || {};
          this._headers[header] = value;
          return XMLHttpRequest.prototype.setRequestHeader.call(this, header, value);
        };
        
        XMLHttpRequest.prototype.send = function(data) {
          const xhr = this;
          
          // Check URL for M3U8
          if (xhr._url && xhr._url.toLowerCase().includes('.m3u8')) {
            window.flutter_inappwebview.callHandler('networkRequestHandler', {
              type: 'xhr',
              method: xhr._method,
              url: xhr._url,
              headers: xhr._headers || {},
              data: data,
              timestamp: Date.now()
            });
          }
          
          // Monitor response
          xhr.addEventListener('load', function() {
            if (xhr._url && xhr.responseText) {
              const response = xhr.responseText;
              
              // Extract tokens from response
              extractTokens(response, 'XHR Response: ' + xhr._url);
              
              // Check if response contains M3U8 content
              if (response.includes('#EXTM3U') || response.includes('#EXT-X-STREAM-INF')) {
                window.flutter_inappwebview.callHandler('networkRequestHandler', {
                  type: 'xhr_response',
                  url: xhr._url,
                  content: response.substring(0, 2000),
                  headers: xhr._headers || {},
                  responseHeaders: xhr.getAllResponseHeaders(),
                  timestamp: Date.now()
                });
              }
              
              // Look for M3U8 URLs in response
              const m3u8Regex = /https?:\\/\\/[^\\s<>"]+\\.m3u8(?:\\?[^\\s<>"]*)?/gi;
              const matches = response.match(m3u8Regex);
              if (matches) {
                matches.forEach(url => {
                  window.flutter_inappwebview.callHandler('networkRequestHandler', {
                    type: 'found_m3u8',
                    url: url,
                    source: xhr._url,
                    headers: xhr._headers || {},
                    timestamp: Date.now()
                  });
                });
              }
            }
          });
          
          return originalXHRSend.apply(this, arguments);
        };
        
        // Intercept Fetch API
        window.fetch = function(...args) {
          const url = args[0];
          const options = args[1] || {};
          const headers = options.headers || {};
          
          if (url && url.toString().toLowerCase().includes('.m3u8')) {
            window.flutter_inappwebview.callHandler('networkRequestHandler', {
              type: 'fetch',
              method: options.method || 'GET',
              url: url.toString(),
              headers: headers,
              timestamp: Date.now()
            });
          }
          
          return originalFetch.apply(this, args).then(response => {
            const clonedResponse = response.clone();
            
            if (url && (
              clonedResponse.headers.get('content-type')?.includes('application/vnd.apple.mpegurl') ||
              clonedResponse.headers.get('content-type')?.includes('application/x-mpegURL')
            )) {
              clonedResponse.text().then(text => {
                extractTokens(text, 'Fetch Response: ' + url);
                
                window.flutter_inappwebview.callHandler('networkRequestHandler', {
                  type: 'fetch_response',
                  url: url.toString(),
                  content: text.substring(0, 2000),
                  headers: headers,
                  responseHeaders: Object.fromEntries(clonedResponse.headers.entries()),
                  timestamp: Date.now()
                });
              }).catch(() => {});
            }
            
            return response;
          });
        };
        
        // Monitor video elements and their network requests
        function monitorVideoElements() {
          const videos = document.querySelectorAll('video');
          videos.forEach(video => {
            if (video.src && video.src.toLowerCase().includes('.m3u8')) {
              window.flutter_inappwebview.callHandler('networkRequestHandler', {
                type: 'video_element',
                url: video.src,
                timestamp: Date.now()
              });
            }
            
            const sources = video.querySelectorAll('source');
            sources.forEach(source => {
              if (source.src && source.src.toLowerCase().includes('.m3u8')) {
                window.flutter_inappwebview.callHandler('networkRequestHandler', {
                  type: 'video_source',
                  url: source.src,
                  timestamp: Date.now()
                });
              }
            });
          });
        }
        
        // Monitor localStorage and sessionStorage for tokens
        function monitorStorage() {
          try {
            const localStorage = window.localStorage;
            const sessionStorage = window.sessionStorage;
            
            const checkStorage = (storage, type) => {
              for (let i = 0; i < storage.length; i++) {
                const key = storage.key(i);
                const value = storage.getItem(key);
                if (key && value) {
                  extractTokens(key + '=' + value, type + ' Storage');
                }
              }
            };
            
            checkStorage(localStorage, 'Local');
            checkStorage(sessionStorage, 'Session');
          } catch (e) {}
        }
        
        // Monitor cookies
        function monitorCookies() {
          try {
            extractTokens(document.cookie, 'Cookies');
          } catch (e) {}
        }
        
        // Monitor page scripts for tokens
        function monitorScripts() {
          const scripts = document.querySelectorAll('script');
          scripts.forEach(script => {
            if (script.textContent) {
              extractTokens(script.textContent, 'Script Tag');
            }
          });
        }
        
        // Monitor mutation observer for dynamic content
        const observer = new MutationObserver((mutations) => {
          mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
              if (node.nodeType === 1) {
                if (node.tagName === 'VIDEO') {
                  monitorVideoElements();
                } else if (node.tagName === 'SCRIPT' && node.textContent) {
                  extractTokens(node.textContent, 'Dynamic Script');
                } else if (node.querySelector) {
                  const videos = node.querySelectorAll('video');
                  if (videos.length > 0) {
                    monitorVideoElements();
                  }
                  const scripts = node.querySelectorAll('script');
                  scripts.forEach(script => {
                    if (script.textContent) {
                      extractTokens(script.textContent, 'Dynamic Script');
                    }
                  });
                }
              }
            });
          });
        });
        
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        // Initial scans
        setTimeout(() => {
          monitorVideoElements();
          monitorStorage();
          monitorCookies();
          monitorScripts();
        }, 1000);
        
        // Periodic monitoring
        setInterval(() => {
          monitorStorage();
          monitorCookies();
        }, 5000);
        
        console.log('Advanced M3U8 Network Monitor with Token Detection injected successfully');
      })();
    ''';

    Timer(Duration(milliseconds: 1500), () {
      controller.evaluateJavascript(source: jsCode);
    });
  }

  Future<void> _getCurrentCookies() async {
    try {
      final cookies =
          await CookieManager.instance().getCookies(url: WebUri(currentUrl));
      currentCookies.clear();
      cookies?.forEach((cookie) {
        currentCookies[cookie.name] = cookie.value;
      });
    } catch (e) {
      print('Error getting cookies: $e');
    }
  }

  Future<void> _getCurrentUserAgent() async {
    try {
      final ua = await webViewController?.evaluateJavascript(
          source: 'navigator.userAgent');
      if (ua != null) {
        currentUserAgent = ua.toString();
      }
    } catch (e) {
      print('Error getting user agent: $e');
    }
  }

  Future<void> _interceptNetworkRequest(WebResourceRequest request) async {
    final url = request.url.toString();
    final headers = request.headers ?? {};

    networkRequests.add(NetworkRequest(
      url: url,
      method: request.method ?? 'GET',
      timestamp: DateTime.now(),
      headers: headers,
    ));

    if (_isM3U8Url(url)) {
      final urlInfo = M3U8UrlInfo(
        url: url,
        source: 'Network Request',
        timestamp: DateTime.now(),
        headers: headers,
        referer: headers['Referer'],
        userAgent: headers['User-Agent'] ?? currentUserAgent,
        cookies: _formatCookies(currentCookies),
      );
      _addDetectedUrl(urlInfo);
    }
  }

  void _handleJavaScriptNetworkData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final url = data['url'] as String?;
    final headers = Map<String, String>.from(data['headers'] ?? {});
    final content = data['content'] as String?;

    if (url != null) {
      String? extractedToken = _extractTokenFromContent(content ?? '');

      final urlInfo = M3U8UrlInfo(
        url: url,
        source: 'JavaScript $type',
        timestamp: DateTime.now(),
        headers: headers,
        referer: headers['Referer'] ?? currentUrl,
        userAgent: headers['User-Agent'] ?? currentUserAgent,
        cookies: _formatCookies(currentCookies),
        authToken: extractedToken,
        metadata: {
          'type': type,
          'hasContent': content != null,
          'contentPreview': content?.substring(0, 100),
        },
      );

      switch (type) {
        case 'xhr':
        case 'fetch':
          if (_isM3U8Url(url)) {
            _addDetectedUrl(urlInfo);
          }
          break;
        case 'xhr_response':
        case 'fetch_response':
          if (content != null && _isM3U8Content(content)) {
            _addDetectedUrl(urlInfo);
          }
          break;
        case 'found_m3u8':
          _addDetectedUrl(urlInfo);
          break;
        case 'video_element':
        case 'video_source':
          _addDetectedUrl(urlInfo);
          break;
      }
    }
  }

  void _handleExtractedTokens(Map<String, dynamic> data) {
    final tokens = Map<String, String>.from(data['tokens'] ?? {});
    final source = data['source'] as String? ?? 'Unknown';

    print('🔑 Tokens extracted from $source: $tokens');

    // Update existing URLs with extracted tokens
    setState(() {
      for (int i = 0; i < detectedUrls.length; i++) {
        final existing = detectedUrls[i];
        if (existing.authToken == null && tokens.isNotEmpty) {
          // Use the first available token
          final firstToken = tokens.values.first;
          detectedUrls[i] = M3U8UrlInfo(
            url: existing.url,
            source: existing.source,
            timestamp: existing.timestamp,
            headers: existing.headers,
            referer: existing.referer,
            userAgent: existing.userAgent,
            cookies: existing.cookies,
            authToken: firstToken,
            metadata: {
              ...existing.metadata,
              'extractedTokens': tokens,
              'tokenSource': source,
            },
          );
        }
      }
    });
  }

  String? _extractTokenFromContent(String content) {
    final tokenPatterns = [
      RegExp("token[=:]\\s*[\"']?([^\"\\s,]+)[\"']?", caseSensitive: false),
      RegExp("auth[=:]\\s*[\"']?([^\"\\s,]+)[\"']?", caseSensitive: false),
      RegExp("access_token[=:]\\s*[\"']?([^\"\\s,]+)[\"']?",
          caseSensitive: false),
      RegExp("bearer[=:]\\s*[\"']?([^\"\\s,]+)[\"']?", caseSensitive: false),
      RegExp("eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]*"), // JWT
    ];

    for (final pattern in tokenPatterns) {
      final match = pattern.firstMatch(content);
      if (match != null && match.groupCount > 0) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }
    }
    return null;
  }

  String _formatCookies(Map<String, String> cookies) {
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  void _scanConsoleMessage(String message) {
    final m3u8Pattern = RegExp(r'https?://[^\s<>"]+\.m3u8(?:\?[^\s<>"]*)?',
        caseSensitive: false);
    final matches = m3u8Pattern.allMatches(message);

    for (final match in matches) {
      final url = match.group(0)!;
      final token = _extractTokenFromContent(message);

      final urlInfo = M3U8UrlInfo(
        url: url,
        source: 'Console Log',
        timestamp: DateTime.now(),
        referer: currentUrl,
        userAgent: currentUserAgent,
        cookies: _formatCookies(currentCookies),
        authToken: token,
      );
      _addDetectedUrl(urlInfo);
    }
  }

  void _scanResourceUrl(String url) {
    if (_isM3U8Url(url)) {
      final urlInfo = M3U8UrlInfo(
        url: url,
        source: 'Resource Load',
        timestamp: DateTime.now(),
        referer: currentUrl,
        userAgent: currentUserAgent,
        cookies: _formatCookies(currentCookies),
      );
      _addDetectedUrl(urlInfo);
      // if (detectedUrls.length > 1) {
      //   _toggleScanning();
      //   _autoShowDetectedUrls();
      // }
    }
  }

  bool _isM3U8Url(String url) {
    return url.toLowerCase().contains('.m3u8');
  }

  bool _isM3U8Content(String content) {
    return content.contains('#EXTM3U') ||
        content.contains('#EXT-X-STREAM-INF') ||
        content.contains('#EXT-X-VERSION');
  }

  void _addDetectedUrl(M3U8UrlInfo urlInfo) {
    if (!detectedUrls.any((item) => item.url == urlInfo.url)) {
      final isFirstVideo = detectedUrls.isEmpty;
      setState(() {
        detectedUrls.add(urlInfo);
      });

      print('🎯 M3U8 Detected: ${urlInfo.url}');
      print('   Source: ${urlInfo.source}');
      print('   Token: ${urlInfo.authToken ?? 'None'}');

      // Auto-show popup for first detected video
      if (isFirstVideo) {
        _autoShowDetectedUrls();
      }
    }
  }

  void _scanCurrentPage() {
    webViewController?.evaluateJavascript(source: '''
      (function() {
        const allElements = document.querySelectorAll('*');
        const urls = new Set();
        
        allElements.forEach(el => {
          ['src', 'href', 'data-src', 'data-href'].forEach(attr => {
            const value = el.getAttribute(attr);
            if (value && value.toLowerCase().includes('.m3u8')) {
              urls.add(value);
            }
          });
          
          if (el.textContent) {
            const m3u8Regex = /https?:\\/\\/[^\\s<>"]+\\.m3u8(?:\\?[^\\s<>"]*)?/gi;
            const matches = el.textContent.match(m3u8Regex);
            if (matches) {
              matches.forEach(url => urls.add(url));
            }
          }
        });
        
        urls.forEach(url => {
          window.flutter_inappwebview.callHandler('networkRequestHandler', {
            type: 'page_scan',
            url: url,
            timestamp: Date.now()
          });
        });
        
        return Array.from(urls);
      })();
    ''');
  }

  void _loadUrl(String url) {
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scanner Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text('Auto-extract tokens'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('Monitor storage'),
              value: true,
              onChanged: (value) {},
            ),
            SwitchListTile(
              title: Text('Deep content scan'),
              value: true,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatUrlInfoForCopy(M3U8UrlInfo urlInfo) {
    final buffer = StringBuffer();
    buffer.writeln('URL: ${urlInfo.url}');
    buffer.writeln('Source: ${urlInfo.source}');
    buffer.writeln('Timestamp: ${urlInfo.timestamp}');

    if (urlInfo.authToken != null) {
      buffer.writeln('Token: ${urlInfo.authToken}');
    }

    if (urlInfo.formattedUrl != urlInfo.url) {
      buffer.writeln('Formatted URL: ${urlInfo.formattedUrl}');
    }

    if (urlInfo.referer != null) {
      buffer.writeln('Referer: ${urlInfo.referer}');
    }

    if (urlInfo.userAgent != null) {
      buffer.writeln('User-Agent: ${urlInfo.userAgent}');
    }

    if (urlInfo.cookies != null && urlInfo.cookies!.isNotEmpty) {
      buffer.writeln('Cookies: ${urlInfo.cookies}');
    }

    if (urlInfo.headers.isNotEmpty) {
      buffer.writeln('Headers:');
      urlInfo.headers.entries.forEach((e) {
        buffer.writeln('  ${e.key}: ${e.value}');
      });
    }

    if (urlInfo.metadata.isNotEmpty) {
      buffer.writeln('Metadata:');
      urlInfo.metadata.entries.forEach((e) {
        buffer.writeln('  ${e.key}: ${e.value}');
      });
    }

    return buffer.toString();
  }

  void _testPlayUrl(M3U8UrlInfo urlInfo) {
    _openVideoPlayer(urlInfo);
  }

  void _openVideoPlayer(M3U8UrlInfo urlInfo) {
    // Create headers map for the video player
    Map<String, String> playerHeaders = {};

    // Add authentication headers
    if (urlInfo.headers.isNotEmpty) {
      playerHeaders.addAll(urlInfo.headers);
    }

    // Add referer if available
    if (urlInfo.referer != null) {
      playerHeaders['Referer'] = urlInfo.referer!;
    }

    // Add user agent if available
    if (urlInfo.userAgent != null) {
      playerHeaders['User-Agent'] = urlInfo.userAgent!;
    }

    // Add cookies if available
    if (urlInfo.cookies != null && urlInfo.cookies!.isNotEmpty) {
      playerHeaders['Cookie'] = urlInfo.cookies!;
    }

    // Add authorization token if available
    if (urlInfo.authToken != null) {
      // Try different ways to add the token
      if (!playerHeaders.containsKey('Authorization')) {
        playerHeaders['Authorization'] = 'Bearer ${urlInfo.authToken}';
      }
    }

    // Use formatted URL if token is in URL parameters
    String playUrl = urlInfo.formattedUrl;

    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            videoUrl: urlInfo.url,
            headers: urlInfo.headers, // All custom headers
            cookies: urlInfo.cookies, // Session cookies
            authToken: urlInfo.authToken, // Extracted auth token
            referer: urlInfo.referer, // Page referer
            userAgent: urlInfo.userAgent, // Browser user agent
            title: '${widget.epishodeName}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening video player: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _exportUrls() {
    final exportData = detectedUrls.map((urlInfo) => urlInfo.toJson()).toList();
    final jsonString = JsonEncoder.withIndent('  ').convert(exportData);

    Clipboard.setData(ClipboardData(text: jsonString));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('All URLs exported to clipboard as JSON')),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  // Enhanced toggle scanning with auto-stop
  void _toggleScanning() {
    setState(() {
      isScanning = !isScanning;
    });

    if (isScanning) {
      _startAdvancedScanningWithAutoStop();
    } else {
      _stopScanning();
    }
  }

// Enhanced scanning with auto-stop functionality
  void _startAdvancedScanningWithAutoStop() {
    _lastDetectedCount = detectedUrls.length;

    // Start the main scanning timer
    _scanningTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!isScanning || !mounted) {
        timer.cancel();
        return;
      }
      _scanCurrentPage();
      _checkForInactivity();
    });

    // Set maximum scan duration
    Timer(Duration(minutes: _maxScanDurationMinutes), () {
      if (isScanning && mounted) {
        _autoStopScanning('Maximum scan duration reached');
      }
    });

    // Reset inactivity timer
    _resetInactivityTimer();

    print('🔍 Started scanning with auto-stop detection');
  }

// Check if no new URLs have been detected
  void _checkForInactivity() {
    final currentCount = detectedUrls.length;

    if (currentCount > _lastDetectedCount) {
      // New URLs detected, reset inactivity timer
      _lastDetectedCount = currentCount;
      _resetInactivityTimer();
      print('📈 New M3U8 URLs detected: $currentCount total');
    }
  }

// Reset the inactivity timer
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(seconds: _inactivityTimeoutSeconds), () {
      if (isScanning && mounted) {
        _autoStopScanning(
            'No new URLs detected for $_inactivityTimeoutSeconds seconds');
      }
    });
  }

// Auto-stop scanning with reason
  void _autoStopScanning(String reason) {
    if (!isScanning) return;

    setState(() {
      isScanning = false;
    });

    _stopScanning();

    print('⏹️ Auto-stopped scanning: $reason');
    print('📊 Final count: ${detectedUrls.length} M3U8 URLs detected');

    
  }

// Clean stop scanning
  void _stopScanning() {
    _scanningTimer?.cancel();
    _inactivityTimer?.cancel();
    _scanningTimer = null;
    _inactivityTimer = null;
  }

// Enhanced add detected URL method with auto-stop check
  void _addDetectedUrlWithToken(
    String url,
    String source,
    Map<String, String> headers,
    String? token,
    String? referer,
    String? userAgent,
  ) {
    if (!detectedUrls.any((item) => item.url == url)) {
      setState(() {
        detectedUrls.add(M3U8UrlInfo(
          url: url,
          source: source,
          timestamp: DateTime.now(),
          headers: headers,
          authToken: token,
          referer: referer,
          userAgent: userAgent,
        ));
      });

      String tokenInfo =
          token != null ? ' (Token: ${token.substring(0, 20)}...)' : '';
      print('🎯 M3U8 Detected: $url (Source: $source)$tokenInfo');

      // Reset inactivity timer when new URL is found
      if (isScanning) {
        _resetInactivityTimer();
      }
    }
  }

// Quick scan completion check
  bool _isPageFullyScanned() {
    // Check if page has finished loading all resources
    if (webViewController != null) {
      // You can add more sophisticated checks here
      return detectedUrls.length > 0 &&
          DateTime.now().difference(detectedUrls.last.timestamp).inSeconds > 10;
    }
    return false;
  }

// Manual check for scan completion
  void _checkScanCompletion() async {
    if (!isScanning) return;

    try {
      final result = await webViewController?.evaluateJavascript(source: '''
      (function() {
        // Check if page is still loading
        const isLoading = document.readyState !== 'complete';
        
        // Check if there are pending network requests
        const performanceEntries = performance.getEntriesByType('navigation');
        const isNavigating = performanceEntries.length > 0 && 
                            performanceEntries[0].loadEventEnd === 0;
        
        // Check if there are active video elements still loading
        const videos = document.querySelectorAll('video');
        const videosLoading = Array.from(videos).some(v => v.readyState < 3);
        
        return {
          isLoading: isLoading,
          isNavigating: isNavigating,
          videosLoading: videosLoading,
          videoCount: videos.length,
          m3u8ElementsCount: document.querySelectorAll('[src*=".m3u8"], [href*=".m3u8"]').length
        };
      })();
    ''');

      if (result != null && result is Map) {
        final isPageBusy = result['isLoading'] == true ||
            result['isNavigating'] == true ||
            result['videosLoading'] == true;

        if (!isPageBusy && detectedUrls.isNotEmpty) {
          // Page seems stable and we have URLs, might be ready to stop
          final timeSinceLastDetection = DateTime.now()
              .difference(detectedUrls.isNotEmpty
                  ? detectedUrls.last.timestamp
                  : DateTime.now())
              .inSeconds;

          if (timeSinceLastDetection > 15) {
            _autoStopScanning('Page scan appears complete');
          }
        }
      }
    } catch (e) {
      print('Error checking scan completion: $e');
    }
  }
}

class NetworkRequest {
  final String url;
  final String method;
  final DateTime timestamp;
  final Map<String, String> headers;

  NetworkRequest({
    required this.url,
    required this.method,
    required this.timestamp,
    this.headers = const {},
  });
}
