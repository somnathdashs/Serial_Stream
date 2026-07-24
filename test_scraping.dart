import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final url = "https://www.desi-serials.to/star-plus-hdepisodes/";
  final headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
  };

  try {
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final doc = parser.parse(response.body);
      final entryContent = doc.querySelector("div.entry-content") ??
          doc.querySelector("div.page-content") ??
          doc.querySelector("div#content");

      if (entryContent != null) {
        // Look for all show containers, e.g., porto-sicon-wrapper or similar
        final containers = entryContent.querySelectorAll("div.porto-sicon-wrapper");
        print("Found ${containers.length} porto-sicon-wrapper elements");

        for (var i = 0; i < containers.length; i++) {
          final container = containers[i];
          final img = container.querySelector("img");
          final imgUrl = img?.attributes['src'];
          
          // Find any link inside
          final links = container.querySelectorAll("a");
          String? showTitle;
          String? showUrl;
          
          for (var link in links) {
            final title = link.text.trim();
            final href = link.attributes['href'];
            if (title.isNotEmpty) {
              showTitle = title;
            }
            if (href != null && href.contains('/watch-online/')) {
              showUrl = href;
            }
          }
          
          print("Show $i: Title='$showTitle' | URL='$showUrl' | Image='$imgUrl'");
        }
      }
    }
  } catch (e) {
    print("Error: $e");
  }
}
