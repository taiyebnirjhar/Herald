/// The Linux base system (WBS 1.3). The app downloads it in the background
/// the first time the player installs it. Android checks its SHA-256 before it
/// is unpacked (see RuntimeImage.kt).
class RuntimeImage {
  const RuntimeImage._();

  static const url =
      'https://github.com/taiyebnirjhar/Herald/releases/download/runtime-v0.0.2/debian-trixie-arm64.tar.gz';

  /// File name the download is kept under.
  static const fileName = 'debian-trixie-arm64.tar.gz';
}
