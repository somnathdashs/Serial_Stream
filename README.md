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
- Cross-platform support (Android,Android TV,Window)

## What's New in Update 2.0.0

- **New Device Support:** Now, the app can be smoothly use is any Android TV.
- **Improved UI Performance:** Faster and more responsive interface



## What's New in Update 1.2.0

- **Video Download:** Users can now download video content directly through the app
- **Improved UI Performance:** Faster and more responsive interface
- **Bug Fixes:** Resolved various stability and performance issues
- **Social Media Integration:** Added Telegram and Facebook buttons for easier sharing and community access

## Resolved Issues

### Workmanager Compatibility Issue

The app previously experienced build failures due to compatibility issues with the workmanager package (version 0.5.2) and newer Android build tools. This caused Kotlin compilation errors during the build process.

#### Resolution Steps:

1. Updated Kotlin version to 1.9.22 in the Android build.gradle file
2. Temporarily disabled the workmanager dependency to allow for successful builds
3. Modified the Android configuration in gradle.properties for improved compatibility
4. Refactored code to function without the workmanager package while maintaining core app functionality
5. Added necessary Kotlin dependencies to ensure proper compilation

These changes allowed the app to build successfully while we work on a more permanent solution for background notification functionality.

## Software Requirements
- Flutter SDK: 3.29.3 (stable channel)
- Dart SDK: 3.7.2
- Android Studio: 2022.3
- Windows 11 (Version 10.0.26100)
- JDK: OpenJDK 17.0.6

## Dependencies
The project uses the following main libraries:
- `http` ^1.2.0 - For making HTTP requests
- `html` ^0.15.0 - For HTML parsing
- `webview_flutter` ^4.10.0 - For web content display
- `feedback` ^3.1.0 - For user feedback
- `firebase_core` ^3.13.0 - For Firebase integration
- `firebase_messaging` ^15.2.5 - For push notifications
- `cloud_firestore` ^5.6.6 - For cloud database
- `video_player` ^2.8.2 - For video playback
- `better_player_plus` ^1.0.8 - For enhanced video playback
- `cached_network_image` ^3.4.1 - For image caching
- `shared_preferences` ^2.5.3 - For local storage
- `connectivity_plus` ^6.1.3 - For network status
- `url_launcher` ^6.3.1 - For opening URLs
- `share_plus` ^10.1.4 - For sharing content
- `firebase_analytics` ^11.4.5 - For app analytics
- `flutter_file_downloader` ^2.1.0 - For file downloading capabilities
- `app_links` ^6.4.0 - For deep linking functionality

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

## Build Information

- Flutter: 3.29.3 (channel stable)
- Target Android SDK: 35
- Minimum Android SDK: 23
- Kotlin version: 1.9.22
- Gradle plugin: 8.2.0
- NDK version: 28.1.13356709

## Future Development

We are working on:
- Restoring full background notification functionality
- Additional content providers
- Enhanced streaming options
- Performance optimizations for better user experience

## Contributing
Feel free to submit issues and enhancement requests.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Learn More
- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)
- [Firebase Documentation](https://firebase.google.com/docs)
