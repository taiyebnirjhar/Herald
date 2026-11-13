import 'package:flutter_test/flutter_test.dart';
import 'package:herald/update/app_update.dart';

void main() {
  group('AppUpdate.fromTag', () {
    test('builds the APK and checksum URLs from the tag', () {
      final u = AppUpdate.fromTag(owner: 'taiyebnirjhar', repo: 'Herald', tag: 'v0.1.3')!;
      expect(u.version, '0.1.3');
      expect(u.tag, 'v0.1.3');
      expect(u.apkName, 'herald-0.1.3-arm64.apk');
      expect(u.apkUrl,
          'https://github.com/taiyebnirjhar/Herald/releases/download/v0.1.3/herald-0.1.3-arm64.apk');
      expect(u.sha256Url, '${u.apkUrl}.sha256');
    });

    test('a tag that is not a version is not an update', () {
      expect(AppUpdate.fromTag(owner: 'a', repo: 'b', tag: 'nightly'), isNull);
      expect(AppUpdate.fromTag(owner: 'a', repo: 'b', tag: '0.1.3'), isNull);
      expect(AppUpdate.fromTag(owner: 'a', repo: 'b', tag: 'v0.1'), isNull);
    });
  });

  group('AppUpdate.tagFromLocation', () {
    test('reads the tag from GitHub\'s redirect', () {
      expect(
        AppUpdate.tagFromLocation('https://github.com/taiyebnirjhar/Herald/releases/tag/v0.1.3'),
        'v0.1.3',
      );
    });

    test('anything else gives no tag', () {
      expect(AppUpdate.tagFromLocation('https://github.com/taiyebnirjhar/Herald'), isNull);
      expect(AppUpdate.tagFromLocation('https://github.com/taiyebnirjhar/Herald/releases/tag'), isNull);
      expect(AppUpdate.tagFromLocation('not a url at all'), isNull);
    });
  });

  group('AppUpdate.sha256FromFile', () {
    const hash = 'ec953a86b24e7b0844f56de25860581687c2c7d36d2e63b5e2f98d4e6c8bb482';

    test('reads the hash from sha256sum output', () {
      expect(AppUpdate.sha256FromFile('$hash  herald-0.1.3-arm64.apk\n'), hash);
    });

    test('lowercases an upper-case hash', () {
      expect(AppUpdate.sha256FromFile(hash.toUpperCase()), hash);
    });

    test('a file without a valid hash gives nothing', () {
      expect(AppUpdate.sha256FromFile('<html>404</html>'), isNull);
      expect(AppUpdate.sha256FromFile('abc123'), isNull);
    });
  });

  group('versions', () {
    test('compares major, minor and patch numerically', () {
      expect(isNewerVersion('0.1.1', '0.1.0'), isTrue);
      expect(isNewerVersion('0.2.0', '0.1.9'), isTrue);
      expect(isNewerVersion('0.1.10', '0.1.9'), isTrue);
      expect(isNewerVersion('0.1.0', '0.1.0'), isFalse);
      expect(isNewerVersion('0.1.0', '0.1.1'), isFalse);
    });

    test('ignores a leading v and missing parts', () {
      expect(isNewerVersion('v0.2.0', '0.1.0'), isTrue);
      expect(isNewerVersion('0.2', '0.1.5'), isTrue);
    });
  });
}
