import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final queries = [
    "Anupamaa",
    "Kundali Bhagya",
    "Taarak Mehta Ka Ooltah Chashmah",
    "Star Plus",
    "Sony TV"
  ];

  for (final query in queries) {
    final url = "https://api.tvmaze.com/singlesearch/shows?q=${Uri.encodeComponent(query)}";
    try {
      final response = await http.get(Uri.parse(url));
      print("Query: $query -> Status: ${response.statusCode}");
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final image = data['image'];
        print("Image data: $image");
      }
    } catch (e) {
      print("Error: $e");
    }
  }
}
