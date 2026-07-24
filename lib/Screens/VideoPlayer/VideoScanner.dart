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
  final String? parentShowTitle;
  final String? epishodePageUrl;
  final String? showMainUrl;

  const M3U8WebViewScanner({
    Key? key,
    required this.initialUrl,
    required this.epishodeName,
    required this.showImageUrl,
    required this.channel,
    required this.epishodesQueue,
    this.parentShowTitle,
    this.epishodePageUrl,
    this.showMainUrl,
  }) : super(key: key);

  @override
  _M3U8WebViewScannerState createState() => _M3U8WebViewScannerState();
}

class _M3U8WebViewScannerState extends State<M3U8WebViewScanner>
    with SingleTickerProviderStateMixin {
  HeadlessInAppWebView? headlessWebView;
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

    headlessWebView = HeadlessInAppWebView(
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
    );

    _toggleScanning();
    headlessWebView?.run();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _stopScanning();
    headlessWebView?.dispose();
    super.dispose();
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
            Icon(Icons.play_arrow, size: 16, color: Colors.blue),
            SizedBox(width: 4),
            Text('Auto-play', style: TextStyle(fontSize: 12, color: Colors.blue)),
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
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              if (isScanning) {
                webViewController?.reload();
              } else {
                _startScanningAgain();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _startScanningAgain() {
    setState(() {
      detectedUrls.clear();
      isScanning = true;
    });
    _startAdvancedScanningWithAutoStop();
    webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(widget.initialUrl)));
  }

  Widget _buildBody() {
    if (detectedUrls.isNotEmpty) {
      return _buildDetectedVideosView();
    } else if (isScanning) {
      return _buildScanningView();
    } else {
      return _buildInitialOrEmptyView();
    }
  }

  Widget _buildScanningView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                strokeWidth: 5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Scanning for video streams...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Please wait while we analyze the page for playable videos.\nThe first video will be played automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Auto-play enabled',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectedVideosView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_circle_filled, size: 64, color: Colors.green[600]),
            ),
            SizedBox(height: 32),
            Text(
              'Video Found!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Playing the detected video automatically...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '${detectedUrls.length} video${detectedUrls.length != 1 ? 's' : ''} detected',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialOrEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off, size: 64, color: Colors.grey[500]),
            ),
            SizedBox(height: 32),
            Text(
              'No Videos Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'The scan completed, but no video streams were detected on the page.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startScanningAgain,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                textStyle:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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
      if (mounted && webViewController != null) {
        controller.evaluateJavascript(source: jsCode);
      }
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
      if (mounted) {
        setState(() {
          detectedUrls.add(urlInfo);
        });
      }

      print('🎯 M3U8 Detected: ${urlInfo.url}');
      print('   Source: ${urlInfo.source}');
      print('   Token: ${urlInfo.authToken ?? 'None'}');

      // Auto-play the first detected video
      if (detectedUrls.length == 1) {
        _autoPlayFirstVideo(urlInfo);
      }

      // Reset inactivity timer when new URL is found to give user time to select
      if (isScanning && mounted) {
        _resetInactivityTimer();
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

  void _autoPlayFirstVideo(M3U8UrlInfo urlInfo) {
    // Add a small delay to ensure the UI is updated
    Timer(Duration(milliseconds: 500), () {
      if (mounted) {
        print('🎬 Auto-playing first detected video: ${urlInfo.url}');
        _showSnackBar('🎬 Video is now playing!', Colors.green);
        _openVideoPlayer(urlInfo);
      }
    });
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EnhancedVideoPlayerScreen(
            videoUrl: urlInfo.url,
            headers: urlInfo.headers, // All custom headers
            cookies: urlInfo.cookies, // Session cookies
            authToken: urlInfo.authToken, // Extracted auth token
            referer: urlInfo.referer, // Page referer
            userAgent: urlInfo.userAgent, // Browser user agent
            title: '${widget.epishodeName}',
            epishodesQueue: widget.epishodesQueue,
            showImageUrl: widget.showImageUrl,
            channel: widget.channel,
            epishodeUrl: widget.epishodePageUrl ?? widget.initialUrl,
            parentShowTitle: widget.parentShowTitle,
            showMainUrl: widget.showMainUrl,
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

    _showSnackBar(reason, Colors.orange);
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
