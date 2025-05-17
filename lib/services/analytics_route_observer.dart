import 'package:flutter/material.dart';
import 'package:serial_stream/services/analytics_service.dart';

class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      _sendScreenView(route);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      _sendScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute && route is PageRoute) {
      _sendScreenView(previousRoute);
    }
  }

  Future<void> _sendScreenView(PageRoute<dynamic> route) async {
    final String screenName = route.settings.name ?? 'Unknown';
    final String? screenClass = route.runtimeType.toString();
    
    _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );
    
    _analytics.logEvent(
      name: 'navigation_event',
      parameters: {
        'screen_name': screenName,
        'route_args': route.settings.arguments?.toString() ?? 'none',
      },
    );
  }
} 