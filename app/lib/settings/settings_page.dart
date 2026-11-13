import 'package:flutter/material.dart';

import '../battery/battery_page.dart';
import '../runtime/hermes_pin.dart';
import '../ui/herald_look.dart';
import '../update/app_installer.dart';
import 'app_settings.dart';
import 'licences.dart';

/// Settings (WBS 5.6): theme, Wi-Fi-only downloads, boot start, and About.
/// Every value is saved as soon as it changes.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings, this.installer});

  /// Shown only if Android does not report the version. Matches pubspec.yaml.
  static const fallbackVersion = '0.1.0';

  final AppSettings settings;

  /// Reads the app version from Android. Defaults to the real channel.
  final AppInstaller? installer;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppInstaller _installer =
      widget.installer ?? MethodChannelAppInstaller();

  ThemeChoice _theme = ThemeChoice.system;
  bool _wifiOnly = true;
  bool _bootStart = true;
  String _version = SettingsPage.fallbackVersion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final theme = await widget.settings.theme();
    final wifi = await widget.settings.wifiOnly();
    final boot = await widget.settings.bootStart();
    String version = SettingsPage.fallbackVersion;
    try {
      version = (await _installer.installedVersion()).versionName;
    } catch (_) {
      // Keep the fallback version.
    }
    if (!mounted) return;
    setState(() {
      _theme = theme;
      _wifiOnly = wifi;
      _bootStart = boot;
      _version = version;
    });
  }

  Future<void> _setTheme(ThemeChoice choice) async {
    setState(() => _theme = choice);
    await widget.settings.setTheme(choice);
  }

  Future<void> _setWifiOnly(bool value) async {
    setState(() => _wifiOnly = value);
    await widget.settings.setWifiOnly(value);
  }

  Future<void> _setBootStart(bool value) async {
    setState(() => _bootStart = value);
    await widget.settings.setBootStart(value);
  }

  void _openLicences() {
    registerHeraldLicences();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LicensePage(
          applicationName: 'Herald',
          applicationVersion: _version,
          applicationLegalese: 'Herald Licence. See the licence text below.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HeraldBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: HeraldLook.ink,
                    iconSize: 24,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: HeraldLook.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Look',
                children: [
                  RadioGroup<ThemeChoice>(
                    groupValue: _theme,
                    onChanged: (v) {
                      if (v != null) _setTheme(v);
                    },
                    child: const Column(
                      children: [
                        RadioListTile<ThemeChoice>(
                          title: Text('Follow the phone'),
                          value: ThemeChoice.system,
                        ),
                        RadioListTile<ThemeChoice>(
                          title: Text('Light'),
                          value: ThemeChoice.light,
                        ),
                        RadioListTile<ThemeChoice>(
                          title: Text('Dark'),
                          value: ThemeChoice.dark,
                        ),
                      ],
                    ),
                  ),
                  const _Note(
                    'Herald looks light for now. Dark mode comes later. '
                    'Your choice is saved.',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Downloads',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wi-Fi only'),
                    subtitle: const _Note(
                      'Setup and update downloads will use this in a later '
                      'update. Saved now.',
                    ),
                    value: _wifiOnly,
                    onChanged: _setWifiOnly,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Background',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start after the phone restarts'),
                    subtitle: const _Note(
                      'Starts Hermes again after a restart, once Hermes is '
                      'installed. Turn it off to keep Hermes stopped after a restart.',
                    ),
                    value: _bootStart,
                    onChanged: _setBootStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Keep Hermes running'),
                    subtitle: const _Note(
                      'Battery settings, so Android does not stop Herald when the screen is off.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BatteryPage()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'About',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 52,
                    title: const Text('App version'),
                    trailing: Text(
                      _version,
                      style: const TextStyle(color: HeraldLook.muted),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 52,
                    title: const Text('Hermes Agent'),
                    subtitle: const Text('Pinned commit'),
                    trailing: Text(
                      HermesPin.commit.substring(0, 12),
                      style: const TextStyle(color: HeraldLook.muted),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 52,
                    title: const Text('Open-source licences'),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: HeraldLook.muted,
                    ),
                    onTap: _openLicences,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HeraldCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HeraldLook.accent,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.4,
          color: HeraldLook.muted,
        ),
      ),
    );
  }
}
