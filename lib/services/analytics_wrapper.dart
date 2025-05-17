import 'package:flutter/material.dart';
import 'package:serial_stream/services/analytics_service.dart';

class AnalyticsWrapper extends StatefulWidget {
  final Widget child;
  final String screenName;
  final String? screenClass;
  final Map<String, dynamic>? screenParams;

  const AnalyticsWrapper({
    Key? key,
    required this.child,
    required this.screenName,
    this.screenClass,
    this.screenParams,
  }) : super(key: key);

  @override
  State<AnalyticsWrapper> createState() => _AnalyticsWrapperState();
}

class _AnalyticsWrapperState extends State<AnalyticsWrapper> with RouteAware {
  final DateTime _entryTime = DateTime.now();
  final AnalyticsService _analytics = AnalyticsService();
  
  @override
  void initState() {
    super.initState();
    _logScreenView();
  }

  @override
  void dispose() {
    // Log screen time on exit
    final timeSpentSeconds = DateTime.now().difference(_entryTime).inSeconds;
    _analytics.logUserEngagement(
      engagementType: 'screen_time',
      parameters: {
        'screen_name': widget.screenName,
        'time_spent_seconds': timeSpentSeconds,
      },
    );
    super.dispose();
  }

  Future<void> _logScreenView() async {
    _analytics.logScreenView(
      screenName: widget.screenName,
      screenClass: widget.screenClass,
    );
    
    if (widget.screenParams != null) {
      // Create a safe copy of the parameters
      final Map<String, dynamic> safeParams = {
        'screen_name': widget.screenName,
      };
      
      // Add the screen parameters, filtering out null values
      widget.screenParams!.forEach((key, value) {
        if (value != null) {
          safeParams[key] = value;
        }
      });
      
      _analytics.logEvent(
        name: 'screen_view_details',
        parameters: safeParams,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 