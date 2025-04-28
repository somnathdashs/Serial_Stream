# Serial Stream

A Flutter application for streaming TV series and movies.

## Description
Serial Stream is a mobile application built with Flutter that allows users to watch TV series and movies. The app fetches content by web scraping from [DesiTellyBox](http://desitellybox.to/), providing access to a wide range of TV shows, movies, and web series. The app provides a user-friendly interface for browsing and streaming content.
[GET KNOW MORE ABOUT SERIAL STREAM](https://somnathdashs.github.io/apps/serial_stream/)

Note: Since the app relies on web scraping, there might be occasional failures in content fetching due to:
- Changes in the source website's structure
- Network connectivity issues
- Source website maintenance or downtime
- Rate limiting or access restrictions

## Features
- Browse TV series and movies
- Stream content directly in the app
- User-friendly interface
- Cross-platform support ( Android, Windows)

## Software Requirements
- Flutter SDK: ^3.5.3
- Dart SDK: ^3.5.3
- Android Studio / VS Code with Flutter extensions
- Windows 11 (Version 10.0.26100)

## Dependencies
The project uses the following main libraries:
- `http` - For making HTTP requests
- `html` ^0.15.0 - For HTML parsing
- `webview_flutter` ^4.10.0 - For web content display
- `feedback` ^3.1.0 - For user feedback
- `firebase_core` ^3.13.0 - For Firebase integration
- `firebase_messaging` ^15.2.5 - For push notifications
- `cloud_firestore` ^5.6.6 - For cloud database
- `video_player` - For video playback
- `better_player_plus` - For enhanced video playback
- `cached_network_image` ^3.4.1 - For image caching
- `shared_preferences` ^2.5.3 - For local storage
- `connectivity_plus` ^6.1.3 - For network status
- `url_launcher` ^6.3.1 - For opening URLs
- `share_plus` ^10.1.4 - For sharing content

For a complete list of dependencies, check the [pubspec.yaml](https://github.com/somnathdashs/Serial_Stream/blob/main/pubspec.yaml) file.

## Getting Started
To get started with Serial Stream development:

1. Set up your development environment:
   - Install Flutter SDK from [flutter.dev](https://flutter.dev/docs/get-started/install)
   - Set up your preferred IDE (Android Studio or VS Code)
   - Configure Flutter and Dart plugins in your IDE 
   - The release version have intregated firebase project to make user up-to-date and track them. But obviously, the google-servise.config file is not included. If you want to fork it then you can add your own one.


### Prerequisites
- Flutter SDK (latest version)
- Dart SDK (latest version)
- Android Studio / VS Code with Flutter extensions

### Installation
1. Clone the repository:
```bash
git clone https://github.com/yourusername/serial_stream.git
```

2. Navigate to the project directory:
```bash
cd serial_stream
```

3. Install dependencies:
```bash
flutter pub get
```

4. Run the app:
```bash
flutter run
```

## Project Structure
- `lib/` - Main application code
- `assets/` - Images, and other static files
- `test/` - Test files
- Platform-specific directories (android/, ios/, web/, etc.)

## Contributing
Feel free to submit issues and enhancement requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Learn More
- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)
- [Firebase Documentation](https://firebase.google.com/docs)
