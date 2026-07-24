import 'dart:convert';
import 'dart:ffi';
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
  static final Map<String, String> _scrapedShowImages = {};

  static final Map<String, String> channelLogos = {
    "Star Plus": "https://upload.wikimedia.org/wikipedia/en/d/d7/StarPlus_Logo.png",
    "Zee TV": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Zee_TV_2025.svg/1280px-Zee_TV_2025.svg.png",
    "Sony TV": "https://upload.wikimedia.org/wikipedia/en/d/de/Sony_TV_new.png",
    "Colors": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/19/Colors_TV_logo.svg/1280px-Colors_TV_logo.svg.png",
    "Star Bharat": "https://upload.wikimedia.org/wikipedia/en/a/a7/Star_Bharat_Logo.png",
    "Sab TV": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/SONY_SAB_SD_Logo_2022.png/1280px-SONY_SAB_SD_Logo_2022.png",
    "And TV": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/33/%26TV_2025.svg/1280px-%26TV_2025.svg.png",
  };

  static String getChannelLogo(String channelName) {
    return channelLogos[channelName] ?? "https://t4.ftcdn.net/jpg/04/70/29/97/360_F_470299797_UD0eoVMMSUbHCcNJCdv2t8B2g1GVqYgs.jpg";
  }

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

      final entryContent = document.querySelector("div.entry-content") ??
          document.querySelector("div.page-content") ??
          document.querySelector("div#content");

      if (entryContent != null) {
        final containers = entryContent.querySelectorAll("div.porto-sicon-wrapper");
        if (containers.isNotEmpty) {
          final extractedShows = <Map<String, String>>[];
          for (final container in containers) {
            final img = container.querySelector("img");
            var imgUrl = img?.attributes['src'] ?? '';
            if (imgUrl.isNotEmpty) {
              if (imgUrl.startsWith('//')) {
                imgUrl = 'https:' + imgUrl;
              } else if (imgUrl.startsWith('/')) {
                imgUrl = 'https://www.desi-serials.to' + imgUrl;
              }
            }

            final links = container.querySelectorAll("a");
            String? title;
            String? url;
            for (final link in links) {
              final text = link.text.trim();
              final href = link.attributes['href'] ?? '';
              if (text.isNotEmpty) {
                title = text;
              }
              if (href.isNotEmpty && href.contains('/watch-online/')) {
                url = href;
              }
            }

            if (title != null && title.isNotEmpty && url != null && url.isNotEmpty) {
              if (imgUrl.isNotEmpty) {
                _scrapedShowImages[title] = imgUrl;
              }
              extractedShows.add({"title": title, "url": url});
            }
          }
          if (extractedShows.isNotEmpty) return extractedShows;
        }

        final h5Links = entryContent.querySelectorAll("h5 a");
        if (h5Links.isNotEmpty) {
          final extractedShows = <Map<String, String>>[];
          for (final link in h5Links) {
            final title = link.text.trim();
            final href = link.attributes['href'] ?? '';
            if (title.isNotEmpty &&
                href.isNotEmpty &&
                !href.endsWith('#completed') &&
                !href.contains('#')) {
              extractedShows.add({"title": title, "url": href});
            }
          }
          if (extractedShows.isNotEmpty) return extractedShows;
        }

        final liLinks = entryContent.querySelectorAll("li.cat-item a");
        if (liLinks.isNotEmpty) {
          return liLinks
              .map((link) {
                return {
                  "title": link.text.trim(),
                  "url": link.attributes['href'] ?? ''
                };
              })
              .where((s) => s["title"]!.isNotEmpty && s["url"]!.isNotEmpty)
              .toList();
        }

        final allLinks = entryContent.querySelectorAll("a");
        final extractedShows = allLinks
            .map((link) {
              final title = link.text.trim();
              final href = link.attributes['href'] ?? '';
              return {"title": title, "url": href};
            })
            .where((s) =>
                s["title"]!.isNotEmpty &&
                s["url"]!.isNotEmpty &&
                !s["url"]!.contains('#') &&
                s["url"]!.contains('/watch-online/'))
            .toList();
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
    final cleaned = query
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return null;

    try {
      final url = Uri.parse("https://api.tvmaze.com/singlesearch/shows?q=${Uri.encodeComponent(cleaned)}");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final image = data['image'];
        if (image != null) {
          return image['original'] ?? image['medium'];
        }
      }
    } catch (e) {
      debugPrint("Error in ProImageExtracter: $e");
    }
    return null;
  }

  static Future<String> GoogleSearchImage(String query) async {
    for (final channelName in channelLogos.keys) {
      if (query.toLowerCase().contains(channelName.toLowerCase())) {
        return channelLogos[channelName]!;
      }
    }
    return "https://t4.ftcdn.net/jpg/04/70/29/97/360_F_470299797_UD0eoVMMSUbHCcNJCdv2t8B2g1GVqYgs.jpg";
  }

  static Future<String> scrapeHDImage(String show, String channel, {String? showUrl}) async {
    var cachceData =
        await Localstorage.getData(Localstorage.ImagesUrls) ?? "{}";
    cachceData = jsonDecode(cachceData);

    if (cachceData.keys.contains(show)) {
      final cachedUrl = cachceData[show] as String;
      if (cachedUrl.isNotEmpty &&
          !cachedUrl.contains("no-image") &&
          !cachedUrl.contains("No-Image-Found") &&
          !cachedUrl.contains("no_image") &&
          !cachedUrl.contains("placeholder") &&
          !cachedUrl.contains("no-img")) {
        return cachedUrl;
      }
    }

    if (_scrapedShowImages.containsKey(show)) {
      final url = _scrapedShowImages[show]!;
      cachceData[show] = url;
      await Localstorage.setData(Localstorage.ImagesUrls, jsonEncode(cachceData));
      return url;
    }

    // Scrape from show page (float:right div img) — first priority after cache
    if (showUrl != null && showUrl.isNotEmpty) {
      final pageImg = await scrapeShowPageThumbnail(showUrl);
      if (pageImg != null && pageImg.isNotEmpty) {
        _scrapedShowImages[show] = pageImg;
        cachceData[show] = pageImg;
        await Localstorage.setData(Localstorage.ImagesUrls, jsonEncode(cachceData));
        return pageImg;
      }
    }

    var img = await ProImageExtracter(show);
    if (img == null ||
        img.isEmpty ||
        img.contains("no-image") ||
        img.contains("No-Image-Found") ||
        img.contains("no_image") ||
        img.contains("placeholder") ||
        img.contains("no-img")) {
      img = getChannelLogo(channel);
    }

    cachceData[show] = img;
    await Localstorage.setData(Localstorage.ImagesUrls, jsonEncode(cachceData));
    return img;
  }

  /// Scrapes the WordPress show-page thumbnail from the float:right div.
  static Future<String?> scrapeShowPageThumbnail(String showUrl) async {
    try {
      final response = await fetchHTMLdata(showUrl);
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        for (final div in document.querySelectorAll('div')) {
          final style = div.attributes['style'] ?? '';
          if (style.contains('float') && style.contains('right')) {
            final img = div.querySelector('img');
            if (img != null) {
              final src = img.attributes['src'] ?? '';
              if (src.isNotEmpty) return src;
            }
          }
        }
        // Fallback: WordPress attachment-medium class
        final img = document.querySelector('img.attachment-medium');
        if (img != null) {
          final src = img.attributes['src'] ?? '';
          if (src.isNotEmpty) return src;
        }
      }
    } catch (e) {
      debugPrint('scrapeShowPageThumbnail error: $e');
    }
    return null;
  }

  /// Fetches all episodes from /latest-episodes/ and caches their thumbnails.
  static Future<List<Map<String, String>>> fetchLatestEpisodes() async {
    try {
      final response = await fetchHTMLdata('${Website}latest-episodes/');
      if (response.statusCode != 200) return [];
      final document = parser.parse(response.body);
      final results = <Map<String, String>>[];

      for (final article in document.querySelectorAll('article')) {
        // Actual selector: h3.thumb-info-inner > a
        final titleEl = article.querySelector('h3.thumb-info-inner a') ??
            article.querySelector('h2.entry-title a');
        if (titleEl == null) continue;
        final title = titleEl.text.trim();
        var url = titleEl.attributes['href'] ?? '';
        if (title.isEmpty || url.isEmpty) continue;

        if (url.isNotEmpty) {
          if (!url.startsWith('http') && url.startsWith('/')) {
            url = 'https://www.desi-serials.to$url';
          }
          if (url.contains('desi-serials.to') && !url.contains('/watch-online/')) {
            url = url.replaceFirst('desi-serials.to/', 'desi-serials.to/watch-online/');
          }
        }

        // Thumbnail: div.post-image img, src or data-oi (lazy-load)
        var thumbnail = '';
        final img = article.querySelector('div.post-image img') ??
            article.querySelector('img');
        if (img != null) {
          thumbnail = img.attributes['src'] ??
              img.attributes['data-oi'] ??
              img.attributes['data-src'] ??
              '';
          if (thumbnail.startsWith('//')) thumbnail = 'https:$thumbnail';
          else if (thumbnail.startsWith('/')) thumbnail = 'https://www.desi-serials.to$thumbnail';
        }
        if (thumbnail.isNotEmpty) _scrapedShowImages[title] = thumbnail;
        results.add({'title': title, 'url': url});
      }

      if (results.isNotEmpty) return results;

      // Fallback for alternate page layouts
      return document.querySelectorAll('h2.entry-title a').map((a) {
        var url = a.attributes['href'] ?? '';
        if (url.isNotEmpty) {
          if (!url.startsWith('http') && url.startsWith('/')) {
            url = 'https://www.desi-serials.to$url';
          }
          if (url.contains('desi-serials.to') && !url.contains('/watch-online/')) {
            url = url.replaceFirst('desi-serials.to/', 'desi-serials.to/watch-online/');
          }
        }
        return {
          'title': a.text.trim(),
          'url': url,
        };
      }).where((m) => m['title']!.isNotEmpty && m['url']!.isNotEmpty).toList();
    } catch (e) {
      debugPrint('fetchLatestEpisodes error: $e');
      return [];
    }
  }


  static Future<List> fetchEpisodes(String showurl) async {
    List<Map<String, String>> results = [];
    List<Map<String, dynamic>> pagintitation = [];

    try {
      http.Response response = await fetchHTMLdata(showurl);

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // New site: desi-serials.to uses <h2 class="entry-title"><a href="...">Title</a></h2>
        // for episode listings on show pages.
        List<dom.Element> episodeLinks =
            document.querySelectorAll('h2.entry-title a');

        // Fallback: also try article heading links
        if (episodeLinks.isEmpty) {
          episodeLinks =
              document.querySelectorAll('article h2 a, .post-title a');
        }

        // Filter out links containing "preview" or "promo" in their name
        episodeLinks.removeWhere((ep) =>
            ep.text.toLowerCase().contains('preview') ||
            ep.text.toLowerCase().contains('promo'));

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

        // Select page numbers directly or nested within list items
        var pageElements =
            document.querySelectorAll('.pagination .page-numbers');
        if (pageElements.isEmpty) {
          pageElements = document.querySelectorAll('.page-numbers');
        }

        if (pageElements.isNotEmpty) {
          for (var element in pageElements) {
            if (element.classes.contains('dots') ||
                element.querySelector('.dots') != null) {
              continue;
            }

            final isCurrent = element.classes.contains('current') ||
                element.querySelector('span.current') != null;
            if (isCurrent) {
              pages.add({
                "text": element.text.trim(),
                "url": null,
                "current": true,
              });
            } else if (element.localName == 'a') {
              final text = element.text.trim().isNotEmpty
                  ? element.text.trim()
                  : (element.classes.isNotEmpty ? element.classes.first : '');
              pages.add({
                "text": text,
                "url": element.attributes['href'],
                "current": false,
              });
            }
          }
        } else {
          final listItems = document.querySelectorAll('ul.page-numbers li');
          for (var li in listItems) {
            if (li.querySelector('.dots') != null) {
              continue;
            }

            final current = li.querySelector('span.current');
            if (current != null) {
              pages.add({
                "text": current.text.trim(),
                "url": null,
                "current": true,
              });
            } else {
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
      final iframeSrcElements = iframeElements
          .map((iframe) => iframe.attributes['src'] ?? '')
          .toList();

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

      // New site uses div.entry-content (with hyphen, not underscore)
      final entryContentDiv = document.querySelector("div.entry-content") ??
          document.querySelector("div.entry_content") ??
          document.querySelector("div.page-content") ??
          document.querySelector("div#content");

      if (entryContentDiv != null) {
        // Prefer tvarticles.org links (video wrapper links specific to this site)
        final tvarticlesUrls = entryContentDiv
            .querySelectorAll('a[href*="tvarticles.org"]')
            .map((a) => a.attributes['href'] ?? '')
            .where((href) => href.isNotEmpty)
            .toList();

        if (tvarticlesUrls.isNotEmpty) {
          return tvarticlesUrls;
        }

        // Fallback: get all links in entry content
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

        // New site (desi-serials.to): The homepage lists shows per channel
        // in custom menu widget blocks. Each channel section has a heading
        // and a <ul class="menu"> with <li><a> items.
        //
        // Strategy: find all <ul class="menu"> blocks inside the main content
        // and group their links as shows.
        final menuBlocks = document.querySelectorAll('ul.menu');

        for (var menu in menuBlocks) {
          final liItems = menu.querySelectorAll('li > a');
          if (liItems.isEmpty) continue;

          // Use parent heading as channel name if available
          String channelName = '';
          final parentWidget = menu.parent;
          if (parentWidget != null) {
            final heading =
                parentWidget.querySelector('h2, h3, h4, strong, .widget-title');
            channelName = heading?.text.trim() ?? '';
          }

          List<Map<String, String>> shows = [];
          for (var li in liItems) {
            final showName = li.text.trim();
            final showLink = li.attributes['href']?.trim() ?? '';
            if (showName.isNotEmpty &&
                showLink.isNotEmpty &&
                showLink.contains('/watch-online/')) {
              shows.add({'name': showName, 'link': showLink});
            }
          }

          if (shows.isNotEmpty) {
            channels.add({
              'channel_name': channelName,
              'channel_image': '',
              'shows': shows,
            });
          }
        }

        if (channels.isEmpty) {
          // Fallback: parse homepage h2 headings + following lists
          final sections = document.querySelectorAll('h2');
          for (var heading in sections) {
            final channelName = heading.text.trim();
            if (channelName.isEmpty) continue;

            List<Map<String, String>> shows = [];
            // Find the next sibling ul
            dom.Element? sibling = heading.nextElementSibling;
            while (sibling != null && sibling.localName != 'h2') {
              final links = sibling.querySelectorAll('a');
              for (var a in links) {
                final name = a.text.trim();
                final link = a.attributes['href'] ?? '';
                if (name.isNotEmpty &&
                    link.isNotEmpty &&
                    link.contains('/watch-online/')) {
                  shows.add({'name': name, 'link': link});
                }
              }
              sibling = sibling.nextElementSibling;
            }
            if (shows.isNotEmpty) {
              channels.add({
                'channel_name': channelName,
                'channel_image': '',
                'shows': shows
              });
            }
          }
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
      var client = createHttpClient();
      if (client == null) {
        return {"status": false, "data": []};
      }
      final ioClient = IOClient(client);
      final response = await ioClient.get(Uri.parse(Url), headers: header);
      if (response.statusCode == 200) {
        trys = 0;
        final document = parser.parse(response.body);
        // Select all <a> inside <h4> within .item_content
        // New site: desi-serials.to uses h2.entry-title a for episodes
        final episodeLinks = document.querySelectorAll('h2.entry-title a');
        // Filter out links containing "preview" or "promo" in their name
        episodeLinks.removeWhere((ep) =>
            ep.text.toLowerCase().contains('preview') ||
            ep.text.toLowerCase().contains('promo'));
        for (dom.Element ep in episodeLinks) {
          var title = ep.text.trim();
          final href = ep.attributes['href'] ?? '';
          if (title.toLowerCase().contains('preview') ||
              title.toLowerCase().contains('promo')) {
            continue;
          }
          ALLresults.add({
            'title': title,
            'url': href,
          });

          if (title.isNotEmpty && href.isNotEmpty) {
            // Extract date from the title - Fixed regex pattern
            final dateRegex = RegExp(
                r'\b(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4}|\d{4}[-/]\d{1,2}[-/]\d{1,2})\b',
                caseSensitive: false);
            final match = dateRegex.firstMatch(title);
            if (match != null) {
              var dateString = match.group(0)!;

              // Remove ordinal suffixes (st, nd, rd, th)
              dateString = dateString.replaceAll(
                  RegExp(r'(st|nd|rd|th)', caseSensitive: false), '');

              // Clean up extra spaces
              dateString = dateString.replaceAll(RegExp(r'\s+'), ' ').trim();

              DateTime? date;

              // Try parsing as yyyy-MM-dd or yyyy/MM/dd first
              if (dateString.contains('-') || dateString.contains('/')) {
                date = DateTime.tryParse(dateString.replaceAll('/', '-'));
              }

              // If not a standard format, try parsing as date with month name
              if (date == null) {
                // Split the date string to handle partial month names
                final parts = dateString.split(' ');
                if (parts.length == 3) {
                  final day = parts[0];
                  var month = parts[1];
                  final year = parts[2];

                  // Handle abbreviated month names by extending them
                  final monthMap = {
                    'jan': 'January', 'feb': 'February', 'mar': 'March',
                    'apr': 'April', 'may': 'May', 'jun': 'June',
                    'jul': 'July', 'aug': 'August', 'sep': 'September',
                    'oct': 'October', 'nov': 'November', 'dec': 'December',
                    'augu':
                        'August', // Handle the specific case from your error
                  };

                  // Check if month is abbreviated or truncated
                  final monthLower = month.toLowerCase();
                  for (String key in monthMap.keys) {
                    if (monthLower.startsWith(key) ||
                        key.startsWith(monthLower)) {
                      month = monthMap[key]!;
                      break;
                    }
                  }

                  // Reconstruct the date string
                  final reconstructed = '$day $month $year';

                  try {
                    // Try parsing with full month name
                    date = DateFormat('d MMMM yyyy').parseLoose(reconstructed);
                  } catch (e) {
                    try {
                      // Try with short month name as fallback
                      date = DateFormat('d MMM yyyy').parseLoose(reconstructed);
                    } catch (e) {
                      // Try parsing the original format in case it's valid
                      try {
                        date = DateFormat('d MMMM yyyy').parseLoose(dateString);
                      } catch (e) {
                        // If all parsing fails, skip this entry
                        print('Failed to parse date: $dateString - Error: $e');
                        continue;
                      }
                    }
                  }
                }
              }

              // Check if date is within the last 5 days
              if (date != null &&
                  date.isAfter(
                      DateTime.now().subtract(const Duration(days: 1)))) {
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
        return {"status": false, "data": response.statusCode};
      }
    } catch (e) {
      print('Error in fetchNotification: $e');
      return {"status": false, "data": e.toString()};
    }
  }

  /// Extracts date from title string using multiple parsing strategies
  static DateTime? _extractDateFromTitle(String title) {
    // Define comprehensive date patterns
    final datePatterns = [
      // Pattern 1: "25th August 2025", "1st January 2025"
      RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{4})\b',
        caseSensitive: false,
      ),
      // Pattern 2: "25 Aug 2025", "1 Jan 2025"
      RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})\b',
        caseSensitive: false,
      ),
      // Pattern 3: "2025-08-25", "2025/08/25"
      RegExp(r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b'),
      // Pattern 4: "25-08-2025", "25/08/2025"
      RegExp(r'\b(\d{1,2})[-/](\d{1,2})[-/](\d{4})\b'),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(title);
      if (match != null) {
        final parsedDate = _parseMatchedDate(match, pattern);
        if (parsedDate != null) {
          return parsedDate;
        }
      }
    }

    return null;
  }

  /// Parses matched date based on the regex pattern used
  static DateTime? _parseMatchedDate(RegExpMatch match, RegExp pattern) {
    try {
      final matchedText = match.group(0)!;

      // Remove ordinal suffixes (st, nd, rd, th)
      final cleanText = matchedText.replaceAll(
          RegExp(r'\b(\d+)(?:st|nd|rd|th)\b', caseSensitive: false), r'$1');

      // Try different date formats
      final dateFormats = [
        'dd MMMM yyyy', // 25 August 2025
        'dd MMM yyyy', // 25 Aug 2025
        'd MMMM yyyy', // 1 August 2025
        'd MMM yyyy', // 1 Aug 2025
        'yyyy-MM-dd', // 2025-08-25
        'yyyy/MM/dd', // 2025/08/25
        'dd-MM-yyyy', // 25-08-2025
        'dd/MM/yyyy', // 25/08/2025
        'MM-dd-yyyy', // 08-25-2025
        'MM/dd/yyyy', // 08/25/2025
      ];

      for (final format in dateFormats) {
        try {
          final dateFormat = DateFormat(format);
          return dateFormat.parseStrict(cleanText);
        } catch (e) {
          // Continue to next format
          continue;
        }
      }

      // If standard parsing fails, try parseLoose as fallback
      for (final format in ['dd MMMM yyyy', 'dd MMM yyyy']) {
        try {
          final dateFormat = DateFormat(format);
          return dateFormat.parseLoose(cleanText);
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      print('Date parsing error for "${match.group(0)}": $e');
    }

    return null;
  }

  /// Handles HTTP error responses with retry logic
  static Map<String, dynamic> _handleHttpError(int statusCode, String url) {
    if (trys < maxtrys) {
      trys++;
      print('HTTP Error $statusCode for $url. Retry attempt: $trys');
      // Uncomment the line below if you want automatic retries
      // return fetchNotification(url);
      return {
        "status": false,
        "data": "HTTP Error: $statusCode (Retry $trys/$maxtrys)",
        "all": <Map<String, dynamic>>[],
        "retryCount": trys,
      };
    } else {
      trys = 0;
      return {
        "status": false,
        "data": "HTTP Error: $statusCode (Max retries exceeded)",
        "all": <Map<String, dynamic>>[],
        "maxRetriesExceeded": true,
      };
    }
  }
}
