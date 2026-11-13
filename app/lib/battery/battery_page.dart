import 'package:flutter/material.dart';

import '../ui/herald_look.dart';
import 'battery_control.dart';

/// Keep Hermes running (WBS 4.6): shows whether Android may stop Herald to save
/// battery, lets the player allow it, and opens the battery screens with plain steps.
/// The status is checked again each time the player comes back to this screen.
class BatteryPage extends StatefulWidget {
  const BatteryPage({super.key, this.control});

  /// Talks to Android. Defaults to the real channel; tests pass a fake.
  final BatteryControl? control;

  @override
  State<BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends State<BatteryPage> with WidgetsBindingObserver {
  late final BatteryControl _control = widget.control ?? MethodChannelBatteryControl();

  /// Null while the status is still being checked.
  bool? _exempt;
  String? _problem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The player may have changed the setting in Android's screen and come back.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final exempt = await _control.isExempt();
      if (!mounted) return;
      setState(() {
        _exempt = exempt;
        _problem = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _problem = 'Could not read the battery setting on this phone.');
    }
  }

  Future<void> _allow() async {
    setState(() => _problem = null);
    final opened = await _control.requestExemption();
    if (!mounted) return;
    if (!opened) {
      setState(() => _problem = 'This phone did not open the Android question. Use the battery settings button.');
      return;
    }
    await _refresh();
  }

  Future<void> _openSettings() async {
    setState(() => _problem = null);
    final opened = await _control.openBatterySettings();
    if (!mounted) return;
    if (!opened) {
      setState(() => _problem = 'This phone did not open a battery screen.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final exempt = _exempt;
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
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Keep Hermes running',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: HeraldLook.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              HeraldCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      exempt == null
                          ? 'Checking…'
                          : exempt
                              ? 'Allowed. Android will not stop Herald to save battery.'
                              : 'Not allowed yet. Android may stop Hermes when the screen is off.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: HeraldLook.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: exempt == false ? _allow : null,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: Text(exempt == true ? 'Allowed' : 'Allow'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _openSettings,
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('Open battery settings'),
                    ),
                    if (_problem != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _problem!,
                        style: const TextStyle(color: HeraldLook.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const HeraldCard(
                padding: EdgeInsets.all(16),
                child: Text(
                  'On a Samsung phone, also check these steps:\n'
                  '1. Open Settings, then Battery.\n'
                  '2. Open Background usage limits.\n'
                  '3. Make sure Herald is not in "Sleeping apps" or "Deep sleeping apps".\n'
                  '4. Keep Battery saver off while you test.',
                  style: TextStyle(height: 1.4, color: HeraldLook.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
