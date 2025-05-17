import 'package:flutter/material.dart';
import 'package:serial_stream/Screens/AboutScreen.dart';
import 'package:serial_stream/Screens/DownloadedVideoScreen.dart';
import 'package:serial_stream/Screens/FavroitesScreen.dart';
import 'package:serial_stream/Screens/HelpScreen.dart';
import 'package:serial_stream/Screens/Home.dart';
import 'package:serial_stream/Screens/MoreWS_SCREEN.dart';
import 'package:serial_stream/Screens/VerifyScreen.dart';
import 'package:serial_stream/Screens/VideoPlayer/Player.dart';
import 'package:serial_stream/Screens/ShowScreen.dart';
import 'package:serial_stream/Variable.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case VerifyScreenRoute:
        return MaterialPageRoute(builder: (_) => VerifyScreen());
      case HomeScreenRoute:
        return MaterialPageRoute(builder: (_) => MyHomePage());
      case EpisodesScreenRoute:
        if (settings.arguments is List) {
          List arguments = settings.arguments as List;
          if (arguments.length > 1) {
            String channelName = arguments[0] as String;
            String showurl = arguments[1] as String;
            String showtitle = arguments[2] as String;
            String imageurl = arguments[3] as String;
            bool isCompleted = arguments[4] as bool;
            bool isSubscriable = arguments[5] ?? true;
            return MaterialPageRoute(
                builder: (_) => Showscreen(
                    channelName: channelName,
                    showurl: showurl,
                    showtitle: showtitle,
                    showimageurl: imageurl,
                    showcompleted: isCompleted,
                    isSubscriable: isSubscriable));
          }
        }
      case PlayerScreenRoute:
        if (settings.arguments is List) {
          List arguments = settings.arguments as List;
          if (arguments.length > 1) {
            String showurl = arguments[0] as String;
            String showtitle = arguments[1] as String;
            String imageurl = arguments[2] as String;
            List epeQueau = arguments[3] as List;
            String channelName = arguments[4] as String;
            return MaterialPageRoute(
                builder: (_) => Player(
                      epishodeUrl: showurl,
                      epishodeName: showtitle,
                      showImageUrl: imageurl,
                      epishodesQueue: epeQueau,
                      channel:  channelName,
                    ));
          }
        }
      case FavScreenRoute:
        String? mode = settings.arguments as String?;
        return MaterialPageRoute(
            builder: (context) => FavoritesScreen(
                  mode: mode ?? "Favorites",
                ));
      case MoreWSScreenRoute:
        return MaterialPageRoute(builder: (context) => MoreWSScreen());
      case helpScreenRoute:
        return MaterialPageRoute(builder: (context) => HelpScreen());
      case AboutScreenRoute:
        return MaterialPageRoute(builder: (context) => AboutPage());
      case DownloadedVideoScreenRoute:
        return MaterialPageRoute(builder: (context) => DownloadedVideoScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
    throw Exception('Unexpected route: ${settings.name}');
  }
}
