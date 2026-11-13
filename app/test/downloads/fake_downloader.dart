import 'dart:io';

import 'package:herald/downloads/background_downloader.dart';

/// A downloader that "downloads" [bytes] into a file in [dir], or fails with [failWith].
class FakeDownloader extends BackgroundDownloader {
  FakeDownloader({required this.dir, this.bytes, this.failWith});

  final Directory dir;
  final List<int>? bytes;
  final String? failWith;
  DownloadState _state = const DownloadState(state: 'none');
  final started = <String>[];

  @override
  Future<DownloadState> start({
    required String url,
    required String name,
    required String title,
    bool wifiOnly = false,
  }) async {
    started.add(name);
    if (failWith != null) {
      _state = DownloadState(state: 'failed', reason: failWith);
    } else {
      final path = '${dir.path}/source-$name';
      final data = bytes ?? const <int>[];
      File(path).writeAsBytesSync(data);
      _state = DownloadState(
        state: 'done',
        path: path,
        bytes: data.length,
        total: data.length,
      );
    }
    return _state;
  }

  @override
  Future<DownloadState> status(String name) async => _state;
}
