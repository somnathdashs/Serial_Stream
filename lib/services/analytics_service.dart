import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  static FirebaseAnalytics? _analytics;

  // Singleton pattern
  factory AnalyticsService() => _instance;

  AnalyticsService._internal();

  // Lazily get the analytics instance
  Future<FirebaseAnalytics> get analytics async {
    if (_analytics == null) {
      try {
        // Check if Firebase is initialized
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp();
        }
        _analytics = FirebaseAnalytics.instance;
      } catch (e) {
        debugPrint('Failed to initialize Firebase Analytics: $e');
        // Return a dummy implementation to avoid crashes
        _analytics = FirebaseAnalytics.instance;
      }
    }
    return _analytics!;
  }

  // Generic event logging
  Future<void> logEvent({
    required String name,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final analytics = await this.analytics;
      
      // Prefix custom events to avoid reserved names
      final eventName = name.startsWith('custom_') ? name : 'custom_$name';
      
      if (parameters != null) {
        // Convert to the expected type for Firebase Analytics
        final Map<String, Object> convertedParams = {};
        parameters.forEach((key, value) {
          if (value != null) {
            convertedParams[key] = value;
          }
        });
        await analytics.logEvent(name: eventName, parameters: convertedParams);
      } else {
        await analytics.logEvent(name: eventName);
      }
    } catch (e) {
      debugPrint('Failed to log event: $e');
    }
  }

  // App lifecycle events
  Future<void> logAppOpen() async {
    try {
      final analytics = await this.analytics;
      await analytics.logAppOpen();
    } catch (e) {
      debugPrint('Failed to log app open: $e');
    }
  }

  // User Properties
  Future<void> setUserProperties({
    required String userId,
    String? userRole,
    String? subscriptionTier,
  }) async {
    try {
      final analytics = await this.analytics;
      await analytics.setUserId(id: userId);
      
      if (userRole != null) {
        await analytics.setUserProperty(name: 'user_role', value: userRole);
      }
      
      if (subscriptionTier != null) {
        await analytics.setUserProperty(name: 'subscription_tier', value: subscriptionTier);
      }
    } catch (e) {
      debugPrint('Failed to set user properties: $e');
    }
  }

  // Screen tracking
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      final analytics = await this.analytics;
      await analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      debugPrint('Failed to log screen view: $e');
    }
  }

  // Track content views (e.g., watching a video, reading an article)
  Future<void> logContentView({
    required String contentId,
    required String contentType,
    String? contentName,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'content_id': contentId,
        'content_type': contentType,
      };
      
      if (contentName != null) {
        params['content_name'] = contentName;
      }
      
      await analytics.logEvent(
        name: 'custom_content_view',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log content view: $e');
    }
  }

  // Track search actions
  Future<void> logSearch({required String searchTerm}) async {
    try {
      final analytics = await this.analytics;
      await analytics.logSearch(searchTerm: searchTerm);
    } catch (e) {
      debugPrint('Failed to log search: $e');
    }
  }

  // Track user engagement
  Future<void> logUserEngagement({
    required String engagementType,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'engagement_type': engagementType,
      };
      
      if (parameters != null) {
        parameters.forEach((key, value) {
          if (value != null) {
            params[key] = value;
          }
        });
      }
      
      await analytics.logEvent(
        name: 'custom_user_engagement',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log user engagement: $e');
    }
  }

  // Track feature usage
  Future<void> logFeatureUse({
    required String featureName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'feature_name': featureName,
      };
      
      if (parameters != null) {
        parameters.forEach((key, value) {
          if (value != null) {
            params[key] = value;
          }
        });
      }
      
      await analytics.logEvent(
        name: 'custom_feature_use',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log feature use: $e');
    }
  }

  // Track errors within the app
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? errorDetails,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'error_type': errorType,
        'error_message': errorMessage,
      };
      
      if (errorDetails != null) {
        params['error_details'] = errorDetails;
      }
      
      await analytics.logEvent(
        name: 'custom_app_error',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log error: $e');
    }
  }

  // Track performance metrics
  Future<void> logPerformanceIssue({
    required String metricName,
    required num metricValue,
    String? metricUnit,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'metric_name': metricName,
        'metric_value': metricValue,
      };
      
      if (metricUnit != null) {
        params['metric_unit'] = metricUnit;
      }
      
      await analytics.logEvent(
        name: 'custom_performance_metric',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log performance issue: $e');
    }
  }

  // Track session data - using non-reserved names
  Future<void> logSessionStart() async {
    try {
      final analytics = await this.analytics;
      await analytics.logEvent(name: 'custom_app_session_start');
    } catch (e) {
      debugPrint('Failed to log session start: $e');
    }
  }

  Future<void> logSessionEnd({int? durationSeconds}) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object>? params = durationSeconds != null 
          ? {'duration_seconds': durationSeconds}
          : null;
          
      await analytics.logEvent(
        name: 'custom_app_session_end',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log session end: $e');
    }
  }

  // Track in-app actions specific to your app
  Future<void> logSerialDataView({
    required String serialId,
    required String dataType,
    int? dataSize,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'serial_id': serialId,
        'data_type': dataType,
      };
      
      if (dataSize != null) {
        params['data_size'] = dataSize;
      }
      
      await analytics.logEvent(
        name: 'custom_serial_data_view',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log serial data view: $e');
    }
  }

  Future<void> logSerialConnection({
    required String deviceId,
    required String connectionStatus,
    int? baudRate,
  }) async {
    try {
      final analytics = await this.analytics;
      final Map<String, Object> params = {
        'device_id': deviceId,
        'connection_status': connectionStatus,
      };
      
      if (baudRate != null) {
        params['baud_rate'] = baudRate;
      }
      
      await analytics.logEvent(
        name: 'custom_serial_connection',
        parameters: params,
      );
    } catch (e) {
      debugPrint('Failed to log serial connection: $e');
    }
  }

  // Enable or disable analytics collection
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    try {
      final analytics = await this.analytics;
      await analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      debugPrint('Failed to set analytics collection enabled: $e');
    }
  }
} 