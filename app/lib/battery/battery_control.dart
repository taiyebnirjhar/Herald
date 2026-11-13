import 'package:flutter/services.dart';

/// What the battery screen needs from Android (WBS 4.6). Kotlin does the work.
abstract class BatteryControl {
  /// True when Android does not stop Herald to save battery.
  Future<bool> isExempt();

  /// Opens Android's question "allow Herald to run in the background?".
  /// Returns false when this phone has no such screen.
  Future<bool> requestExemption();

  /// Opens the battery settings screen (Samsung's, then Android's, then Herald's
  /// app page). Returns false when none of them could be opened.
  Future<bool> openBatterySettings();
}

/// The real one, over a MethodChannel to `BatteryChannel.kt`.
class MethodChannelBatteryControl implements BatteryControl {
  MethodChannelBatteryControl([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/battery';
  final MethodChannel _channel;

  @override
  Future<bool> isExempt() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('status');
    return map?['exempt'] as bool? ?? false;
  }

  @override
  Future<bool> requestExemption() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('requestExemption');
    return map?['opened'] as bool? ?? false;
  }

  @override
  Future<bool> openBatterySettings() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('openBatterySettings');
    return map?['opened'] as bool? ?? false;
  }
}
