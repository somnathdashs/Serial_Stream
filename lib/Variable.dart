const String AppUrl = "https://somnathdashs.github.io/apps/serial_stream/";
const String Website = "https://www.desitellybox.to/";
// Image search
const String TVSearchebsite = "https://www.themoviedb.org/search/tv?query=";
const String ImageNormalSearchWebsite =
    "https://www.themoviedb.org/search?query=";
const String HDIMAGEURL = "https://image.tmdb.org/t/p/w1280/";

const List<Map<String, String>> Channels = [
  {"name": "And TV", "url": "${Website}and-tv/"},
  {"name": "Colors", "url": "${Website}colors-tv/"},
  {"name": "MTV", "url": "${Website}mtv-channel/"},
  {"name": "Sab TV", "url": "${Website}sab-tv/"},
  {"name": "Sony TV", "url": "${Website}sony-tv/"},
  {"name": "Star Bharat", "url": "${Website}star-bharat/"},
  {"name": "Star Plus", "url": "${Website}star-plus/"},
  {"name": "Zee TV", "url": "${Website}zee-tv/"},
  {"name": "MORE", "url": ""},
];
final List<String> blockedDomains = [
  "ads.google.com",
  "doubleclick.net",
  "ads.pubmatic.com",
  "ce.lijit.com",
  "ssbsync.smartadserver.com"
];

// Route Showscreen
const String HomeScreenRoute = "/home";
const String EpisodesScreenRoute = "/EpisodesScreen";
const String PlayerScreenRoute = "/PlayerScreen";
const String FavScreenRoute = "/FavScreen";
const String MoreWSScreenRoute = "/MoreWSScreen";
const String helpScreenRoute = "/HelpScreen";
const String AboutScreenRoute = "/AboutScreen";
