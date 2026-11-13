/// Hermes Agent (WBS 1.4): the pinned installer, at the commit in runtime/HERMES_PIN.
/// Never run `hermes update` on the phone (PLAN.md D3).
class HermesPin {
  const HermesPin._();

  static const commit = 'f97608f178d1ffeca59860195ab7da295f7c8e5f';

  static const installerUrl =
      'https://raw.githubusercontent.com/NousResearch/hermes-agent/$commit/scripts/install.sh';

  /// File name the installer is kept under.
  static const installerFileName = 'hermes-install.sh';
}
