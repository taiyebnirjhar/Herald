import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:herald/update/app_update.dart';

const _digest =
    'sha256:ec953a86b24e7b0844f56de25860581687c2c7d36d2e63b5e2f98d4e6c8bb482';

String _release({
  Object? tag = 'v0.1.1',
  Object? digest = _digest,
  Object? size = 16044414,
  String name = 'herald-0.1.1-arm64.apk',
  String url = 'https://github.com/taiyebnirjhar/Herald/releases/download/v0.1.1/herald-0.1.1-arm64.apk',
  String body = 'Faster start\n\n**Full Changelog**: https://example.test',
}) =>
    jsonEncode({
      'tag_name': tag,
      'body': body,
      'assets': [
        {
          'name': name,
          'size': size,
          'digest': digest,
          'browser_download_url': url,
        },
      ],
    });

void main() {
  group('compareVersions', () {
    test('compares major, minor and patch numerically', () {
      expect(isNewerVersion('0.1.1', '0.1.0'), isTrue);
      expect(isNewerVersion('0.2.0', '0.1.9'), isTrue);
      expect(isNewerVersion('1.0.0', '0.9.9'), isTrue);
      expect(isNewerVersion('0.1.10', '0.1.9'), isTrue);
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.1.1'), isFalse);
    });

    test('ignores a leading v and missing parts', () {
      expect(isNewerVersion('v0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('0.2', '0.1.5'), isTrue);
    });
  });

  group('AppUpdate.fromReleaseJson', () {
    test('reads the version, APK, size, checksum and notes', () {
      final u = AppUpdate.fromReleaseJson(_release())!;
      expect(u.version, '0.1.1');
      expect(u.tag, 'v0.1.1');
      expect(u.apkName, 'herald-0.1.1-arm64.apk');
      expect(u.apkSize, 16044414);
      expect(u.sha256,
          'ec953a86b24e7b0844f56de25860581687c2c7d36d2e63b5e2f98d4e6c8bb482');
      expect(u.apkUrl, startsWith('https://github.com/'));
      expect(u.notes, 'Faster start');
    });

    test('ignores a release with no version tag', () {
      expect(AppUpdate.fromReleaseJson(_release(tag: 'nightly')), isNull);
    });

    test('ignores a release with no APK', () {
      expect(AppUpdate.fromReleaseJson(_release(name: 'source.zip')), isNull);
    });

    test('refuses an APK without a SHA-256 checksum', () {
      expect(AppUpdate.fromReleaseJson(_release(digest: null)), isNull);
      expect(AppUpdate.fromReleaseJson(_release(digest: 'md5:abc')), isNull);
    });

    test('refuses an APK that is not served from GitHub over https', () {
      expect(
        AppUpdate.fromReleaseJson(_release(url: 'http://github.com/x.apk')),
        isNull,
      );
      expect(
        AppUpdate.fromReleaseJson(_release(url: 'https://evil.example/x.apk')),
        isNull,
      );
    });

    test('garbage is not an update', () {
      expect(AppUpdate.fromReleaseJson('<html>nope</html>'), isNull);
      expect(AppUpdate.fromReleaseJson('{"tag_name": '), isNull);
    });
  });
}
