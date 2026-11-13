/// The Linux base system Herald runs Hermes in (WBS 1.3).
///
/// The address and SHA-256 are compiled into the app. The app never trusts a
/// checksum it downloads next to the image (PLAN.md D4). Changing the image
/// means changing these two lines in a new release.
class RuntimeImage {
  const RuntimeImage._();

  /// Debian trixie (arm64) base system, built by `.github/workflows/runtime.yml`.
  static const url =
      'https://github.com/taiyebnirjhar/Herald/releases/download/runtime-v0.0.1/debian-trixie-arm64.tar.gz';

  /// SHA-256 of the file at [url]. Set from the release's `.sha256` file.
  static const sha256 = 'PENDING_RELEASE_HASH';
}
