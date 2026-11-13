import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_installer.dart';
import 'app_update.dart';
import 'update_service.dart';

enum UpdateStep {
  /// Not checked yet.
  idle,
  checking,
  upToDate,
  available,
  downloading,

  /// Downloaded and checked; Android's installer is next.
  readyToInstall,

  /// Android's installer is open (the player taps Install there).
  installing,

  /// Android needs the one-time permission to install apps.
  needsPermission,
  failed,
}

/// Runs the update steps and tells the screen where they stand.
class UpdateController extends ChangeNotifier {
  UpdateController({required this.service, required this.installer});

  final UpdateService service;
  final AppInstaller installer;

  UpdateStep step = UpdateStep.idle;
  String installedName = '…';
  AppUpdate? update;
  double progress = 0;
  String? message;
  File? _file;

  bool get busy =>
      step == UpdateStep.checking || step == UpdateStep.downloading;

  /// Reads the installed version. Never throws.
  Future<void> init() async {
    try {
      installedName = (await installer.installedVersion()).versionName;
    } catch (_) {
      installedName = 'unknown';
    }
    notifyListeners();
  }

  /// Asks GitHub for the newest release. A check while one is running, or
  /// while a download is going, does nothing.
  Future<void> checkForUpdate() async {
    if (busy) return;
    _set(UpdateStep.checking);
    try {
      final latest = await service.latestRelease();
      if (latest != null && isNewerVersion(latest.version, installedName)) {
        update = latest;
        message = null;
        _set(UpdateStep.available);
      } else {
        update = null;
        message = null;
        _set(UpdateStep.upToDate);
      }
    } on UpdateException catch (e) {
      _fail(e.message);
    }
  }

  /// Downloads the update, then opens Android's installer.
  Future<void> downloadAndInstall() async {
    final u = update;
    if (u == null || busy) return;
    progress = 0;
    _set(UpdateStep.downloading);
    try {
      _file = await service.download(u, onProgress: (f) {
        progress = f;
        notifyListeners();
      });
      _set(UpdateStep.readyToInstall);
      await install();
    } on UpdateException catch (e) {
      _fail(e.message);
    }
  }

  /// Opens Android's installer for the downloaded APK. Used again after the
  /// player has allowed installs in settings.
  Future<void> install() async {
    final file = _file;
    if (file == null) return;
    try {
      final result = await installer.install(file.path);
      message = null;
      _set(result == InstallResult.needsPermission
          ? UpdateStep.needsPermission
          : UpdateStep.installing);
    } catch (_) {
      _fail(
        "Android's installer didn't open. Try again, or install the APK from the Releases page.",
      );
    }
  }

  void _set(UpdateStep next) {
    step = next;
    notifyListeners();
  }

  void _fail(String text) {
    message = text;
    _set(UpdateStep.failed);
  }

  @override
  void dispose() {
    service.close();
    super.dispose();
  }
}
