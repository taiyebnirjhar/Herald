import 'package:flutter/services.dart';

import '../update/update_exception.dart';

/// Where a background download is: none, running, waiting (for Wi-Fi or the
/// network), done (with its file's path), or failed (with the reason).
class DownloadState {
  const DownloadState({
    required this.state,
    this.bytes = 0,
    this.total = 0,
    this.path,
    this.reason,
  });

  final String state;
  final int bytes;
  final int total;
  final String? path;
  final String? reason;

  double get fraction => total > 0 ? (bytes / total).clamp(0.0, 1.0) : 0.0;

  factory DownloadState.fromMap(Map<String, dynamic> map) => DownloadState(
        state: map['state'] as String? ?? 'none',
        bytes: (map['bytes'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toInt() ?? 0,
        path: map['path'] as String?,
        reason: map['reason'] as String?,
      );
}

/// Every download in the app goes through this. Android keeps the download
/// going when the app is in the background or closed, and it can be asked
/// for its state later by file name.
abstract class BackgroundDownloader {
  /// Starts [url] as [name]. Reattaches if the same file is already running or done.
  Future<DownloadState> start({
    required String url,
    required String name,
    required String title,
    bool wifiOnly = false,
  });

  /// The state of the download called [name].
  Future<DownloadState> status(String name);

  /// Waits until [name] is done (reporting progress) and returns its path.
  /// Throws [UpdateException] if it fails or never starts.
  Future<String> waitFor(
    String name, {
    void Function(DownloadState state)? onProgress,
    Duration interval = const Duration(seconds: 2),
  }) async {
    while (true) {
      final s = await status(name);
      onProgress?.call(s);
      if (s.state == 'done' && s.path != null) return s.path!;
      if (s.state == 'failed') {
        throw UpdateException(s.reason ?? "The download didn't finish. Try again.");
      }
      if (s.state == 'none') {
        throw const UpdateException("The download didn't start. Try again.");
      }
      await Future<void>.delayed(interval);
    }
  }
}

/// The real downloader, over the runtime's MethodChannel to Android's download manager.
class MethodChannelDownloader extends BackgroundDownloader {
  MethodChannelDownloader([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/runtime';
  final MethodChannel _channel;

  @override
  Future<DownloadState> start({
    required String url,
    required String name,
    required String title,
    bool wifiOnly = false,
  }) async {
    final map = await _channel.invokeMapMethod<String, dynamic>('startDownload', {
      'url': url,
      'name': name,
      'title': title,
      'wifiOnly': wifiOnly,
    });
    return DownloadState.fromMap(Map<String, dynamic>.from(map ?? {}));
  }

  @override
  Future<DownloadState> status(String name) async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
        'downloadStatus', {'name': name});
    return DownloadState.fromMap(Map<String, dynamic>.from(map ?? {}));
  }
}
