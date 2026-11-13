/// A published Herald version that is newer than the one installed.
///
/// Found from the GitHub release page (`releases/latest`), which is not
/// subject to the API rate limit. Each release ships its APK and a
/// `<apk>.sha256` file next to it.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.tag,
    required this.apkName,
    required this.apkUrl,
    required this.sha256Url,
  });

  /// Version without the leading `v`, for example `0.1.3`.
  final String version;

  /// The release tag, for example `v0.1.3`.
  final String tag;

  final String apkName;
  final String apkUrl;
  final String sha256Url;

  static final _tagPattern = RegExp(r'^v(\d+\.\d+\.\d+)$');
  static final _hashPattern = RegExp(r'^([0-9a-fA-F]{64})\b');

  /// The update for [tag] (for example `v0.1.3`), or null if the tag is not a version.
  static AppUpdate? fromTag({
    required String owner,
    required String repo,
    required String tag,
  }) {
    final m = _tagPattern.firstMatch(tag);
    if (m == null) return null;
    final version = m.group(1)!;
    final base = 'https://github.com/$owner/$repo/releases/download/$tag';
    final apkName = 'herald-$version-arm64.apk';
    return AppUpdate(
      version: version,
      tag: tag,
      apkName: apkName,
      apkUrl: '$base/$apkName',
      sha256Url: '$base/$apkName.sha256',
    );
  }

  /// The tag from GitHub's redirect for "latest release":
  /// `https://github.com/<owner>/<repo>/releases/tag/v0.1.3` gives `v0.1.3`.
  static String? tagFromLocation(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final i = segments.indexOf('tag');
    if (i <= 0 || i + 1 >= segments.length || segments[i - 1] != 'releases') {
      return null;
    }
    return segments[i + 1];
  }

  /// The SHA-256 from a `.sha256` file (`sha256sum` format: `<hash>  <name>`),
  /// lowercase, or null if the file doesn't start with a valid hash.
  static String? sha256FromFile(String text) {
    final m = _hashPattern.firstMatch(text.trim());
    return m?.group(1)!.toLowerCase();
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
