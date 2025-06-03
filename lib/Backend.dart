import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:developer' as d;
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:serial_stream/LocalStorage.dart';
import 'package:serial_stream/Screens/NoInternetScreen.dart';
import 'package:serial_stream/Screens/ServerError.dart';
import 'package:serial_stream/Variable.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http/http.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:serial_stream/main.dart';
import 'package:share_plus/share_plus.dart';

class Backend {
  static int trys = 0;
  static int maxtrys = 5;
  static HttpClient? createHttpClient() {
    try {
      final client = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
      return client;
    } catch (e) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (context) => const NoInternetScreen()),
      );
    }
  }

  static initialized() {
    // Backend.webScraper = WebScraper(Website);
  }

  static Map<String, String> Get_a_Header() {
    List<String> user_agents = [
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
      "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:55.0) Gecko/20100101 Firefox/55.0",
      "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:54.0) Gecko/20100101 Firefox/54.0",
      "Mozilla/5.0 (Windows NT 6.1; WOW64; Trident/7.0; AS; rv:11.0) like Gecko",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x86) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3",
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3 Edge/16.16299",
      "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 9; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 11; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 12; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 13; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 14; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 15; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 16; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPad; CPU OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPad; CPU OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 11_0_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 12_0_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_0_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
      "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0",
      "Mozilla/5.0 (X11; Fedora; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0",
      "Mozilla/5.0 (X11; Debian; Linux x86_64; rv:89.0) Gecko/20100101 Firefox/89.0",
      "Mozilla/5.0 (Linux; Android 9; Pixel 3 XL) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 12; Pixel 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 12_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPad; CPU OS 13_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPad; CPU OS 12_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Mobile/15E148 Safari/604.1",
      "Mozilla/5.0 (iPad; CPU OS 11_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.0 Mobile/15E148 Safari/604.1",
    ];
    user_agents.shuffle();
    return {"User-Agent": user_agents[0]};
  }

  static Future<Response> fetchHTMLdata(String Url, {Header}) async {
    final url = Uri.parse(Url);
    var header;
    if (Header != null) {
      header = Header;
    } else {
      header = Get_a_Header();
    }
    if (createHttpClient() == null) {
      return http.Response("", 150);
    }
    final ioClient = IOClient(createHttpClient());

    try {
      http.Response res;
      if (header["u"] == false) {
        res = await ioClient.get(url);
      } else {
        res = await ioClient.get(url, headers: header);
      }
      if (res.statusCode >= 500) {
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => ServerProblemScreen(),
          ),
        );
      }
      return res;
    } catch (e) {
      return http.Response("", 404);
    }
  }

  static Future<List> fetchShows(String Channel_url) async {
    final response = await fetchHTMLdata(Channel_url);
    if (response.statusCode == 200) {
      trys = 0;
      dom.Document document = parser.parse(response.body);
      final entryContent = document.querySelector("div.entry_content");

      if (entryContent != null) {
        final links = entryContent.querySelectorAll("a");
        final extractedShows = links.map((link) {
          final title = link.text.trim();
          final href = link.attributes['href'] ?? '';
          return {"title": title, "url": href};
        }).toList();
        extractedShows.removeAt(0);
        return extractedShows;
      }
      return [];
    } else {
      if (trys < maxtrys) {
        trys++;
        return fetchShows(Channel_url);
      }
      return [];
    }
  }

  static Future<String?> ProImageExtracter(String query) async {
    String? imageUrl;
    Future<String?> GetImageUrl(String html) async {
      final document = parser.parse(html);

      // Find the first card
      final firstCard = document.querySelector('div.card.v4.tight');

      if (firstCard != null) {
        // Find the image tag inside the first card
        final imgTag = firstCard.querySelector('img.poster.w-full');

        // Extract the 'src' attribute
        final imageUrl = imgTag?.attributes['src'];

        if (imageUrl != null) {
          var imagefile = imageUrl.split('/').last;
          return HDIMAGEURL + imagefile;
        }
        return null;
      }
    }

    try {
      var result = await fetchHTMLdata(TVSearchebsite + query);
      var TVSearchRes = await GetImageUrl(result.body);
      if (TVSearchRes == null) {
        var result = await fetchHTMLdata(TVSearchebsite + query);
        var NSearchRes = await GetImageUrl(result.body);
        imageUrl = TVSearchRes;
      } else {
        imageUrl = TVSearchRes;
      }
    } catch (e) {
      // Error extracting image URL
    }

    return imageUrl;
  }

  static Future<String> GoogleSearchImage(String query) async {
    String? imageUrl;
    var cachceData =
        await Localstorage.getData(Localstorage.ImagesUrls) ?? "{}";

    cachceData = jsonDecode(cachceData);
    if (cachceData.keys.contains(query)) {
      return cachceData[query];
    }
    try {
      final searchQuery = Uri.encodeComponent('$query FULL HD image');
      final url =
          Uri.parse('https://www.google.com/search?q=$searchQuery&tbm=isch');

      final headers = Get_a_Header();
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Extract image tags
        final images = document.querySelectorAll('img');

        for (var img in images.skip(1)) {
          final src = img.attributes['src'];

          if (src != null && src.startsWith('http')) {
            if (src.contains("social") || src.contains("icon")) {
              d.log(img.outerHtml.toString());
            }
            if (!src.contains("social")|| !src.contains("icon")) {
              cachceData[query] = src;
              Localstorage.setData(
                  Localstorage.ImagesUrls, jsonEncode(cachceData));
              return src;
            }
          }
        }
      } else {
        // Failed to load image search
      }
    } catch (e) {
      navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute(builder: (context) => const NoInternetScreen()),
      );
    }
    return "https://parinamlaw.com/wp-content/themes/lawcounsel/images/no-image/No-Image-Found-400x264.png";
  }

  static Future<String> scrapeHDImage(String show, String channel) async {
    String? ImageUrl;
    var cachceData =
        await Localstorage.getData(Localstorage.ImagesUrls) ?? "{}";
    cachceData = jsonDecode(cachceData);
    
    if (cachceData.keys.contains(show)) {
      return cachceData[show];
    }
    var Img1 = await ProImageExtracter(show);
    if (Img1 == null) {
      var Img2 = await GoogleSearchImage(show + " show in " + channel);
      ImageUrl = Img2;
    } else {
      ImageUrl = Img1;
    }
    cachceData[show] = ImageUrl;
    Localstorage.setData(Localstorage.ImagesUrls, jsonEncode(cachceData));

    return ImageUrl;
  }

  static Future<List> fetchEpisodes(String showurl) async {
    List<Map<String, String>> results = [];
    List<Map<String, dynamic>> pagintitation = [];

    try {
      http.Response response = await fetchHTMLdata(showurl);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Select all <a> inside <h4> within .item_content
        final episodeLinks = document.querySelectorAll('div.item_content h4 a');

        // Filter out links containing "preview" in their name
        episodeLinks
            .removeWhere((ep) => ep.text.toLowerCase().contains('preview'));

        for (dom.Element ep in episodeLinks) {
          final title = ep.text.trim();
          final href = ep.attributes['href'] ?? '';

          if (title.isNotEmpty && href.isNotEmpty) {
            results.add({
              'title': title,
              'url': href,
            });
          }
        }
        pagintitation = await fetchPaginationPages(showurl, res: response);
        return [results, pagintitation];
      } else {
        if (trys < maxtrys) {
          trys++;
          return fetchEpisodes(showurl);
        }
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchPaginationPages(String showurl,
      {http.Response? res}) async {
    List<Map<String, dynamic>> pages = [];

    try {
      http.Response response =
          (res!.body.isNotEmpty) ? res : await fetchHTMLdata(showurl);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Iterate over all <li> inside <ul class="page-numbers">
        final listItems = document.querySelectorAll('ul.page-numbers li');

        for (var li in listItems) {
          // Skip if it contains a class with dots
          if (li.querySelector('.dots') != null) {
            continue;
          }

          // If it's the current page (e.g. <span class="current">1</span>)
          final current = li.querySelector('span.current');
          if (current != null) {
            pages.add({
              "text": current.text.trim(),
              "url": null,
              "current": true,
            });
          } else {
            // Otherwise, get <a> link
            final a = li.querySelector('a');
            if (a != null) {
              final text = a.text.trim().isNotEmpty
                  ? a.text.trim()
                  : (a.classes.isNotEmpty ? a.classes.first : '');
              pages.add({
                "text": text,
                "url": a.attributes['href'],
                "current": false,
              });
            }
          }
        }
      } else {
        // Error fetching page
      }
    } catch (e) {
      // Error during parsing
    }

    return pages;
  }

    static Future<String?> extractIframSRC_from_Webpage(
        String pageUrl, hEader) async {
      try {
        http.Response response = await fetchHTMLdata(pageUrl, Header: hEader);
        if (response.statusCode != 200) {
        return null;
        }
        final document = parser.parse(response.body);

        // Find all <iframe> elements
        final iframeElements = document.querySelectorAll('iframe');

        // Extract the 'src' attribute of each <iframe> element
        final iframeSrcElements =
          iframeElements.map((iframe) => iframe.attributes['src'] ?? '').toList();

        return iframeSrcElements[0];
      } catch (e) {
        // Error extracting iframe HTML elements
      }

      return null;
    }

    static Future<List<String>> extractEntryContentUrls(
        String WatchPageUrl, hEader) async {
      try {
        http.Response response =
            await fetchHTMLdata(WatchPageUrl, Header: hEader);
        if (response.statusCode != 200) {
          return [];
        }
        final document = parser.parse(response.body);
        final entryContentDiv = document.querySelector("div.entry_content");

        if (entryContentDiv != null) {
          final urls = entryContentDiv
              .querySelectorAll('a[href]')
              .map((a) => a.attributes['href'] ?? '')
              .where((href) => href.isNotEmpty)
              .toList();

          if (urls.length > 5) {
            urls.removeLast();
          }

          return urls;
        }
      } catch (e) {
        // Error extracting entry content URLs
      }

      return [];
    }

// Web series
  static Future<List<Map<String, dynamic>>> extractWebSeriseData() async {
    List<Map<String, dynamic>> channels = [];

    try {
      final response = await fetchHTMLdata(Website);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        // Find all sections with class 'colm'
        final sections = document.querySelectorAll('div.colm');
        for (var section in sections) {
          // Extract channel name
          final channelNameElement = section.querySelector('strong');
          final channelName = channelNameElement?.text.trim() ?? '';

          // Extract channel image
          final imgTag = section.querySelector('img');
          final channelImage = imgTag?.attributes['src']?.trim() ?? '';

          // Extract shows and links
          List<Map<String, String>> shows = [];
          final showList = section.querySelectorAll('li.cat-item');
          for (var item in showList) {
            final showNameElement = item.querySelector('a');
            final showName = showNameElement?.text.trim() ?? '';
            final showLink = showNameElement?.attributes['href']?.trim() ?? '';

            if (showName.isNotEmpty && showLink.isNotEmpty) {
              shows.add({'name': showName, 'link': showLink});
            }
          }

          channels.add({
            'channel_name': channelName,
            'channel_image': Website + channelImage,
            'shows': shows,
          });
        }
        return channels;
      } else {
        if (trys < maxtrys) {
          trys++;
          return extractWebSeriseData();
        }
        trys = 0;
        return [];
      }
    } catch (e) {
      return [];
    }
  }

//  Notification
  static Future<Map> fetchNotification(String Url) async {
    try {
      var header = Get_a_Header();
      var results = [];
      var ALLresults = [];
      if (createHttpClient() == null) {
        return {"status": false, "data": []};
      }
      final ioClient = IOClient(createHttpClient());
      final response = await ioClient.get(Uri.parse(Url), headers: header);

      if (response.statusCode == 200) {
        trys = 0;
        final document = parser.parse(response.body);

        // Select all <a> inside <h4> within .item_content
        final episodeLinks = document.querySelectorAll('div.item_content h4 a');

        // Filter out links containing "preview" in their name
        episodeLinks
            .removeWhere((ep) => ep.text.toLowerCase().contains('preview'));

        for (dom.Element ep in episodeLinks) {
          var title = ep.text.trim();
          final href = ep.attributes['href'] ?? '';

          if (title.toLowerCase().contains('preview')) {
            continue;
          }
          ALLresults.add({
            'title': title,
            'url': href,
          });
          if (title.isNotEmpty && href.isNotEmpty) {
            // Extract date from the title
            final dateRegex = RegExp(
                r'\b(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4}|\d{4}[-/]\d{1,2}[-/]\d{1,2})\b',
                caseSensitive: false);
            final match = dateRegex.firstMatch(title);
            if (match != null) {
              final dateString = match
                  .group(0)!
                  .replaceAll(
                      RegExp(r'(st|nd|rd|th)', caseSensitive: false), '')
                  .trim();
              // Parse the date
              final date = DateTime.tryParse(dateString.replaceAll('/', '-')) ??
                  DateFormat('d MMMM yyyy').parse(dateString, true);
              if (date
                  .isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
                results.add({
                  'title': title,
                  'url': href,
                  // 'date': date,
                });
              }
            }
          }
        }
        return {"status": true, "data": results, "all": ALLresults};
      } else {
        if (trys < maxtrys) {
          trys++;
          // return fetchNotification(Url);
        } else {
          trys = 0;
        }
        return {"status": false, "data": {}};
      }
    } catch (e) {
      return {"status": false, "data": {}};
    }
  }
}
