import 'package:flutter/services.dart';

/// The installed app's version, as Android reports it.
class InstalledVersion {
  const InstalledVersion({required this.versionName, required this.versionCode});
  final String versionName;
  final int versionCode;
}

enum InstallResult {
  /// Android's installer has opened on the APK.
  started,

  /// Android needs the player to allow Herald to install apps. The settings
  /// page has been opened; after the player allows it, install again.
  needsPermission,
}

/// What the update code needs from Android. Kotlin does the work.
abstract class AppInstaller {
  Future<InstalledVersion> installedVersion();
  Future<bool> canInstall();
  Future<InstallResult> install(String apkPath);

  /// The app's cache folder (not cleared by the player's own actions; Android may clear it when space runs low).
  Future<String> cacheDir();
}

/// The real one, over a MethodChannel to `UpdateChannel.kt`.
class MethodChannelAppInstaller implements AppInstaller {
  MethodChannelAppInstaller([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/app_update';
  final MethodChannel _channel;

  @override
  Future<InstalledVersion> installedVersion() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('installedVersion');
    return InstalledVersion(
      versionName: map?['versionName'] as String? ?? '0.0.0',
      versionCode: map?['versionCode'] as int? ?? 0,
    );
  }

  @override
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<String> cacheDir() async =>
      await _channel.invokeMethod<String>('cacheDir') ??
      (throw StateError('No cache folder from Android'));

  @override
  Future<InstallResult> install(String apkPath) async {
    final result =
        await _channel.invokeMethod<String>('install', {'path': apkPath});
    return result == 'needs_permission'
        ? InstallResult.needsPermission
        : InstallResult.started;
  }
}
