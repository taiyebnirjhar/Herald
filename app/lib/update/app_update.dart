import 'dart:convert';

/// A published Herald version that is newer than the one installed.
///
/// Read from the GitHub Releases API (`releases/latest`), which lists the APK
/// and its SHA-256. A release without a usable APK and checksum is ignored.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.tag,
    required this.apkName,
    required this.apkUrl,
    required this.apkSize,
    required this.sha256,
    required this.notes,
  });

  /// Version without the leading `v`, for example `0.1.1`.
  final String version;

  /// The release tag, for example `v0.1.1`.
  final String tag;

  final String apkName;
  final String apkUrl;

  /// Size in bytes, as GitHub reports it.
  final int apkSize;

  /// Lowercase hex SHA-256 of the APK.
  final String sha256;

  /// The release notes, shortened for the screen.
  final String notes;

  static final _tagPattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');
  static final _digestPattern = RegExp(r'^sha256:([0-9a-f]{64})$');

  /// Reads the JSON of one release. Returns null when it isn't a usable
  /// release: no version tag, no `.apk` asset, or no checksum for it.
  static AppUpdate? fromReleaseJson(String body) {
    final dynamic json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      return null;
    }
    if (json is! Map<String, dynamic>) return null;

    final tag = json['tag_name'];
    if (tag is! String || !_tagPattern.hasMatch(tag)) return null;
    final version = tag.replaceFirst('v', '');

    final assets = json['assets'];
    if (assets is! List) return null;
    Map<String, dynamic>? apk;
    for (final a in assets) {
      if (a is Map<String, dynamic> &&
          a['name'] is String &&
          (a['name'] as String).endsWith('.apk')) {
        apk = a;
        break;
      }
    }
    if (apk == null) return null;

    final url = apk['browser_download_url'];
    if (url is! String || !url.startsWith('https://github.com/')) return null;

    final size = apk['size'];
    if (size is! int || size <= 0) return null;

    final digest = apk['digest'];
    if (digest is! String) return null;
    final match = _digestPattern.firstMatch(digest);
    if (match == null) return null;

    final body0 = json['body'];
    final notes = body0 is String ? _shortNotes(body0) : '';

    return AppUpdate(
      version: version,
      tag: tag,
      apkName: apk['name'] as String,
      apkUrl: url,
      apkSize: size,
      sha256: match.group(1)!,
      notes: notes,
    );
  }

  static String _shortNotes(String text) {
    // Keep the first few lines that say something; drop the boilerplate links.
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('**Full Changelog'))
        .take(4)
        .toList();
    return lines.join('\n');
  }
}

/// Compares `major.minor.patch` versions. Returns <0, 0 or >0 like compareTo.
/// Anything that doesn't parse compares as 0.0.0.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final d = pa[i].compareTo(pb[i]);
    if (d != 0) return d;
  }
  return 0;
}

/// True when [latest] is a higher version than [installed].
bool isNewerVersion(String latest, String installed) =>
    compareVersions(latest, installed) > 0;

List<int> _parts(String v) {
  final m = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?').firstMatch(v.trim());
  if (m == null) return const [0, 0, 0];
  return [
    int.parse(m.group(1)!),
    int.parse(m.group(2) ?? '0'),
    int.parse(m.group(3) ?? '0'),
  ];
}
