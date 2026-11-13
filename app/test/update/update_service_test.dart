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

String _releaseJson({String? sha, int? size}) => jsonEncode({
      'tag_name': 'v0.1.1',
      'body': 'Notes',
      'assets': [
        {
          'name': 'herald-0.1.1-arm64.apk',
          'size': size ?? _apkBytes.length,
          'digest': 'sha256:${sha ?? _goodSha}',
          'browser_download_url':
              'https://github.com/taiyebnirjhar/Herald/releases/download/v0.1.1/herald-0.1.1-arm64.apk',
        },
      ],
    });

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('herald_update_test');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  UpdateService serviceWith(http.Client client) => UpdateService(
        client: client,
        downloadsDir: () async => dir,
      );

  test('finds the newest release', () async {
    final service = serviceWith(MockClient((request) async {
      expect(request.url.host, 'api.github.com');
      expect(request.url.path, '/repos/taiyebnirjhar/Herald/releases/latest');
      return http.Response(_releaseJson(), 200);
    }));
    final u = await service.latestRelease();
    expect(u?.version, '0.1.1');
  });

  test('no release yet is not an error', () async {
    final service = serviceWith(MockClient((_) async => http.Response('', 404)));
    expect(await service.latestRelease(), isNull);
  });

  test('a GitHub error says so, in plain words', () async {
    final service = serviceWith(MockClient((_) async => http.Response('', 503)));
    expect(
      service.latestRelease(),
      throwsA(isA<UpdateException>().having(
          (e) => e.message, 'message', contains('GitHub answered 503'))),
    );
  });

  test('downloads the APK, checks it and keeps it', () async {
    final service = serviceWith(MockClient((request) async {
      return http.Response.bytes(_apkBytes, 200);
    }));
    final update = AppUpdate.fromReleaseJson(_releaseJson())!;
    final progress = <double>[];
    final file = await service.download(update, onProgress: progress.add);

    expect(file.path, endsWith('herald-0.1.1.apk'));
    expect(await file.readAsBytes(), _apkBytes);
    expect(progress.last, 1.0);
  });

  test('a file that fails the checksum is deleted and not kept', () async {
    final service = serviceWith(MockClient((_) async {
      return http.Response.bytes(utf8.encode('x' * _apkBytes.length), 200);
    }));
    final update = AppUpdate.fromReleaseJson(_releaseJson())!;

    await expectLater(
      service.download(update),
      throwsA(isA<UpdateException>().having(
          (e) => e.message, 'message', contains("didn't pass the safety check"))),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('a short download is refused', () async {
    final service = serviceWith(MockClient((_) async {
      return http.Response.bytes(_apkBytes.sublist(0, 5), 200);
    }));
    final update = AppUpdate.fromReleaseJson(_releaseJson())!;

    await expectLater(
      service.download(update),
      throwsA(isA<UpdateException>()
          .having((e) => e.message, 'message', contains('incomplete'))),
    );
    expect(dir.listSync(), isEmpty);
  });

  test('older downloads are removed when a newer one is fetched', () async {
    File('${dir.path}/herald-0.1.0.apk').writeAsStringSync('old');
    final service = serviceWith(MockClient((_) async {
      return http.Response.bytes(_apkBytes, 200);
    }));
    final update = AppUpdate.fromReleaseJson(_releaseJson())!;
    await service.download(update);

    expect(File('${dir.path}/herald-0.1.0.apk').existsSync(), isFalse);
    expect(File('${dir.path}/herald-0.1.1.apk').existsSync(), isTrue);
  });
}
