import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/update/app_update.dart';
import 'package:herald/update/update_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _apkBytes = utf8.encode('pretend this is an APK');
final _goodSha = sha256.convert(_apkBytes).toString();
const _latestPath = '/taiyebnirjhar/Herald/releases/latest';
const _apkPath = '/taiyebnirjhar/Herald/releases/download/v0.1.3/herald-0.1.3-arm64.apk';

/// Answers the three GitHub pages the update uses.
http.Response Function(http.Request) _github({
  String tag = 'v0.1.3',
  String? sha,
  int? shaStatus,
  List<int>? apk,
  Map<String, String>? apkHeaders,
}) {
  return (request) {
    if (request.url.path == _latestPath) {
      return http.Response('', 302, headers: {
        'location': 'https://github.com/taiyebnirjhar/Herald/releases/tag/$tag',
      });
    }
    if (request.url.path == '$_apkPath.sha256') {
      if (shaStatus != null) return http.Response('', shaStatus);
      return http.Response('${sha ?? _goodSha}  herald-0.1.3-arm64.apk\n', 200);
    }
    if (request.url.path == _apkPath) {
      return http.Response.bytes(apk ?? _apkBytes, 200, headers: apkHeaders ?? {});
    }
    return http.Response('', 404);
  };
}

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('herald_update_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  UpdateService serviceWith(http.Client client) =>
      UpdateService(client: client, downloadsDir: () async => dir);

  group('latestRelease', () {
    test('reads the newest tag from the release page redirect', () async {
      final service = serviceWith(MockClient((request) async {
        expect(request.url.host, 'github.com');
        expect(request.url.path, _latestPath);
        expect(request.followRedirects, isFalse);
        return _github()(request);
      }));
      final u = await service.latestRelease();
      expect(u?.version, '0.1.3');
      expect(u?.apkUrl, startsWith('https://github.com/'));
    });

    test('a newer tag that is not a version is no update', () async {
      final service = serviceWith(MockClient((r) async => _github(tag: 'nightly')(r)));
      expect(await service.latestRelease(), isNull);
    });

    test('no release yet is not an error', () async {
      final service = serviceWith(MockClient((_) async => http.Response('', 404)));
      expect(await service.latestRelease(), isNull);
    });

    test('a GitHub error says so, in plain words', () async {
      final service = serviceWith(MockClient((_) async => http.Response('', 503)));
      expect(
        service.latestRelease(),
        throwsA(isA<UpdateException>()
            .having((e) => e.message, 'message', contains('GitHub answered 503'))),
      );
    });

    test('a page without a redirect cannot be read', () async {
      final service = serviceWith(MockClient((_) async => http.Response('', 200)));
      expect(service.latestRelease(), throwsA(isA<UpdateException>()));
    });
  });

  group('download', () {
    test('downloads the APK, checks it against its checksum and keeps it', () async {
      final service = serviceWith(MockClient((r) async => _github()(r)));
      final update = AppUpdate.fromTag(owner: 'taiyebnirjhar', repo: 'Herald', tag: 'v0.1.3')!;
      final progress = <double>[];
      final file = await service.download(update, onProgress: progress.add);

      expect(file.path, endsWith('herald-0.1.3.apk'));
      expect(await file.readAsBytes(), _apkBytes);
      expect(progress.last, 1.0);
    });

    test('a file that fails the checksum is deleted and not kept', () async {
      final service = serviceWith(MockClient((r) async => _github(
            apk: utf8.encode('x' * _apkBytes.length),
          )(r)));
      final update = AppUpdate.fromTag(owner: 'taiyebnirjhar', repo: 'Herald', tag: 'v0.1.3')!;

      await expectLater(
        service.download(update),
        throwsA(isA<UpdateException>().having(
            (e) => e.message, 'message', contains("didn't pass the safety check"))),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a release with no checksum file is refused before any download', () async {
      final service = serviceWith(MockClient((r) async => _github(shaStatus: 404)(r)));
      final update = AppUpdate.fromTag(owner: 'taiyebnirjhar', repo: 'Herald', tag: 'v0.1.3')!;

      await expectLater(
        service.download(update),
        throwsA(isA<UpdateException>().having(
            (e) => e.message, 'message', contains('no checksum file'))),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('a short download is refused by the checksum', () async {
      // A cut-off file never matches the published hash, however the
      // connection ended.
      final service = serviceWith(MockClient((r) async => _github(
            apk: _apkBytes.sublist(0, 5),
          )(r)));
      final update = AppUpdate.fromTag(owner: 'taiyebnirjhar', repo: 'Herald', tag: 'v0.1.3')!;

      await expectLater(
        service.download(update),
        throwsA(isA<UpdateException>().having(
            (e) => e.message, 'message', contains("didn't pass the safety check"))),
      );
      expect(dir.listSync(), isEmpty);
    });

    test('older downloads are removed when a newer one is fetched', () async {
      File('${dir.path}/herald-0.1.0.apk').writeAsStringSync('old');
      final service = serviceWith(MockClient((r) async => _github()(r)));
      final update = AppUpdate.fromTag(owner: 'taiyebnirjhar', repo: 'Herald', tag: 'v0.1.3')!;
      await service.download(update);

      expect(File('${dir.path}/herald-0.1.0.apk').existsSync(), isFalse);
      expect(File('${dir.path}/herald-0.1.3.apk').existsSync(), isTrue);
    });
  });
}
