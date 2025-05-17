import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class VKPrimeExtractor {
  final String url;
  final void Function(String? videoUrl) onExtracted;
  late HeadlessInAppWebView headlessWebView;
  int retryCount = 0;

  VKPrimeExtractor({
    required this.url,
    required this.onExtracted,
  });

  Future<void> start() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedUrl = prefs.getString(url);

    if (cachedUrl != null && await _isValidUrl(cachedUrl)) {
      onExtracted(cachedUrl);
      return;
    }

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialOptions: InAppWebViewGroupOptions(
        crossPlatform: InAppWebViewOptions(
          javaScriptEnabled: true,
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          clearCache: true,
        ),
      ),
      onWebViewCreated: (controller) {
        // nothing needed here for now
      },
      onLoadStop: (controller, url) async {
        await _extractVideoUrl(controller);
      },
      onLoadError: (controller, url, code, message) {
        _handleFailure();
      },
      onLoadHttpError: (controller, url, code, message) {
        _handleFailure();
      },
    );

    await headlessWebView.run();
  }

  Future<bool> _isValidUrl(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _extractVideoUrl(InAppWebViewController controller) async {
    try {
      await controller.evaluateJavascript(source: '''
        (async function() {
          const sleep = ms => new Promise(r => setTimeout(r, ms));
          let video = null;
          while (!video) {
            video = document.querySelector("video");
            if (!video) await sleep(300);
          }
          video.volume = 0;
          video.play();
          while (video.paused || video.readyState < 2) {
            await sleep(300);
          }
          video.pause();
          return video.src;
        })();
      ''');

      // Small delay to ensure JavaScript finishes
      await Future.delayed(Duration(seconds: 5));

      var videoUrl = await controller.evaluateJavascript(
          source: "document.querySelector('video')?.src;");

      if (videoUrl != null && videoUrl.toString().startsWith('http')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(url, videoUrl.toString());
        await headlessWebView.dispose();
        onExtracted(videoUrl.toString());
      } else {
        _handleFailure();
      }
    } catch (e) {
      _handleFailure();
    }
  }

  void _handleFailure() async {
    retryCount++;
    if (retryCount < 5) {
      await Future.delayed(Duration(seconds: 1));
      await headlessWebView.webViewController?.reload();
    } else {
      await headlessWebView.dispose();
      onExtracted(null);
    }
  }
}
