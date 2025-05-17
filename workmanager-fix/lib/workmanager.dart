import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

// Fixed version to address Kotlin compatibility issues

// Signature for the background fetch function
typedef BackgroundTaskHandler = Future<bool> Function(String taskName, Map<String, dynamic>? inputData);

/// Used for the [Workmanager] dispatch.
enum ExistingWorkPolicy { append, keep, replace }

/// Used for deciding when the task should run.
enum NetworkType { connected, metered, not_required, not_roaming, unmetered }

/// Used for requiring certain device constraints for tasks to execute.
class Constraints {
  const Constraints({
    this.networkType = NetworkType.not_required,
    this.requiresBatteryNotLow = false,
    this.requiresCharging = false,
    this.requiresDeviceIdle = false,
    this.requiresStorageNotLow = false,
  });

  final NetworkType networkType;
  final bool requiresBatteryNotLow;
  final bool requiresCharging;
  final bool requiresDeviceIdle;
  final bool requiresStorageNotLow;
}

class Workmanager {
  static final Workmanager _instance = Workmanager._();

  factory Workmanager() => _instance;

  Workmanager._();

  BackgroundTaskHandler? _backgroundTaskHandler;

  /// Communication channel between dart and native.
  final MethodChannel _backgroundChannel = const MethodChannel(
      'be.tramckrijte.workmanager/background_channel');

  /// Method channel to respond to background messages.
  final MethodChannel _foregroundChannel = const MethodChannel(
      'be.tramckrijte.workmanager/foreground_channel');

  /// Must be called in order to initialize workmanager.
  /// This must be called in main.dart.
  /// [isInDebugMode] true will post debug notifications with information about when tasks ran.
  Future<void> initialize(
    BackgroundTaskHandler backgroundTask, {
    bool isInDebugMode = false,
  }) async {
    _backgroundTaskHandler = backgroundTask;
    _foregroundChannel.setMethodCallHandler(_callHandler);
    await _foregroundChannel.invokeMethod<void>(
      'initialize',
      isInDebugMode,
    );
  }

  Future<dynamic> _callHandler(MethodCall call) async {
    if (_backgroundTaskHandler == null) {
      return null;
    }

    switch (call.method) {
      case 'backgroundHandler':
        final args = call.arguments as List<dynamic>;
        final taskName = args[0] as String;
        final inputData = args[1] as Map<String, dynamic>?;
        final result = await _backgroundTaskHandler!(taskName, inputData);
        return result;
      default:
        return null;
    }
  }

  /// Schedule a one-off background task using native APIs.
  ///
  /// [uniqueName] must be unique, if a task with the same name was already scheduled, this one will replace it.
  ///
  /// [inputData] this data will be sent to [BackgroundTaskHandler].
  /// The data needs to be primitive or a List or Map of primitives.
  ///
  /// [initialDelay] sets the initial delay for the task to be run in seconds.
  ///
  /// [existingWorkPolicy] sets the work policy when re-registering a task with the same unique name.
  ///
  /// [constraints] sets the device constraints that need to be satisfied for the task to run.
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    ExistingWorkPolicy? existingWorkPolicy,
    Duration? initialDelay,
    Constraints? constraints,
    BackgroundTaskTimeout? backoffPolicy,
    Duration? backoffPolicyDelay,
  }) =>
      _foregroundChannel.invokeMethod<void>(
        'registerOneOffTask',
        <String, dynamic>{
          'uniqueName': uniqueName,
          'taskName': taskName,
          'inputData': inputData,
          'existingWorkPolicy': existingWorkPolicy?.index,
          'initialDelaySeconds': initialDelay?.inSeconds,
          'networkType': constraints?.networkType.index,
          'requiresBatteryNotLow': constraints?.requiresBatteryNotLow ?? false,
          'requiresCharging': constraints?.requiresCharging ?? false,
          'requiresDeviceIdle': constraints?.requiresDeviceIdle ?? false,
          'requiresStorageNotLow': constraints?.requiresStorageNotLow ?? false,
          'backoffPolicyType': backoffPolicy?.index,
          'backoffDelayInMilliseconds': backoffPolicyDelay?.inMilliseconds,
        },
      );

  /// Schedule a periodic background task using native APIs.
  ///
  /// [uniqueName] must be unique, if a task with the same name was already scheduled, this one will replace it.
  ///
  /// [taskName] is the name of the task, which will be passed in to [BackgroundTaskHandler]
  ///
  /// [frequencyType] sets how frequent the task will run via an enum value.
  ///
  /// [inputData] this data will be sent to [BackgroundTaskHandler].
  /// The data needs to be primitive or a List or Map of primitives.
  ///
  /// [initialDelay] sets the initial delay for the task to be run in seconds.
  ///
  /// [existingWorkPolicy] sets the work policy when re-registering a task with the same unique name.
  ///
  /// [constraints] sets the device constraints that need to be satisfied for the task to run.
  ///
  /// [backoffPolicyType] sets the backoff strategy for when a task fails (Android only).
  ///
  /// [backoffPolicyDelayInMilliseconds] sets the delay time for the backoff strategy (Android only).
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Map<String, dynamic>? inputData,
    ExistingWorkPolicy? existingWorkPolicy,
    Duration? initialDelay,
    bool? outOfQuotaPolicy,
    Constraints? constraints,
    BackgroundTaskTimeout? backoffPolicy,
    Duration? backoffPolicyDelay,
  }) =>
      _foregroundChannel.invokeMethod<void>(
        'registerPeriodicTask',
        <String, dynamic>{
          'uniqueName': uniqueName,
          'taskName': taskName,
          'frequencyInSeconds': frequency?.inSeconds ?? 15 * 60, // Default: 15 minutes
          'inputData': inputData,
          'existingWorkPolicy': existingWorkPolicy?.index,
          'initialDelaySeconds': initialDelay?.inSeconds,
          'outOfQuotaPolicy': outOfQuotaPolicy == true ? 0 : null, // OutOfQuotaPolicy.run_as_non_expedited_work_request = 0
          'networkType': constraints?.networkType.index,
          'requiresBatteryNotLow': constraints?.requiresBatteryNotLow ?? false,
          'requiresCharging': constraints?.requiresCharging ?? false,
          'requiresDeviceIdle': constraints?.requiresDeviceIdle ?? false,
          'requiresStorageNotLow': constraints?.requiresStorageNotLow ?? false,
          'backoffPolicyType': backoffPolicy?.index,
          'backoffDelayInMilliseconds': backoffPolicyDelay?.inMilliseconds,
        },
      );

  /// Cancel background task by tag name. If there are multiple tasks with the same
  /// tag, they will all be canceled.
  Future<void> cancelByUniqueName(String uniqueName) =>
      _foregroundChannel.invokeMethod<void>(
        'cancelByUniqueName',
        <String, String>{'uniqueName': uniqueName},
      );

  /// Cancel all background task.
  Future<void> cancelAll() => _foregroundChannel.invokeMethod<void>('cancelAll');

  /// This method runs either in a flutter engine without a UI.
  /// Or is spawned by a method in this class.
  @pragma('vm:entry-point')
  static Future<bool> executeTask(String taskName, Map<String, dynamic>? inputData) async {
    final instance = Workmanager();

    if (instance._backgroundTaskHandler == null) {
      print('There is no background message handler set. Returning `false`.');
      return false;
    }

    try {
      return await instance._backgroundTaskHandler!(taskName, inputData);
    } catch (e, stacktrace) {
      print('Error: $e\n$stacktrace');
      return false;
    }
  }
}

/// Used to control when the task should be retried.
enum BackgroundTaskTimeout { exponential, linear }

/// Allow you to mock the background execution
class WorkmanagerHelper {
  static BackgroundTaskHandler? taskHandler;
  static Future<bool> executeTask(String task, Map<String, dynamic>? inputData) async {
    try {
      if (taskHandler != null) {
        return await taskHandler!(task, inputData);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
} 