import 'dart:async';

import 'package:flutter/material.dart';

import '../downloads/background_downloader.dart';
import '../runtime/hermes_pin.dart';
import '../runtime/runtime_channel.dart';
import '../runtime/runtime_image.dart';
import '../update/update_exception.dart';

/// Removes terminal colour codes (ESC [ ... m, shown as a box or a replacement
/// character when the bytes are not valid text) so logs read as plain text.
String plainLog(String text) =>
    text.replaceAll(RegExp(r'(\x1B|�)\[[0-9;?]*[A-Za-z]'), '');

enum StepState { notStarted, working, done, failed }

/// Sets Herald up in three steps: the Linux base, Hermes Agent, and the
/// technical details. Downloads continue in the background.
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.runtime, this.downloader});

  final RuntimeChannel runtime;

  /// Downloads go through this. Defaults to the app's background downloader.
  final BackgroundDownloader? downloader;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  static const _muted = Color(0xFF7A7785);

  late final BackgroundDownloader _downloader =
      widget.downloader ?? MethodChannelDownloader();
  Timer? _poll;
  bool _busy = false;

  StepState _linux = StepState.notStarted;
  String _linuxText = 'Not set up yet.';
  double? _linuxProgress;

  StepState _hermes = StepState.notStarted;
  String _hermesText = 'Set up the Linux base first.';
  String _hermesLog = '';
  double? _hermesProgress;

  bool _showLog = false;
  bool _showDetails = false;
  Map<String, dynamic> _facts = {};
  String _techResult = '';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.runtime.onProgress = null;
    super.dispose();
  }

  /// Reads what is already installed, so the screen opens on the right step.
  Future<void> _loadState() async {
    try {
      final facts = await widget.runtime.describe();
      final linuxReady = facts['linuxInstalled'] == true;
      final status = await widget.runtime.hermesStatus();
      if (!mounted) return;
      setState(() {
        _facts = facts;
        if (linuxReady) {
          _linux = StepState.done;
          _linuxText = 'Ready.';
        }
        if (status.running) {
          _hermes = StepState.working;
          _hermesText = 'Installing…';
          _startPolling();
        } else if (status.result != null) {
          _hermesLog = plainLog(status.log);
          _hermes = status.result!.ok ? StepState.done : StepState.failed;
          _hermesText = status.result!.ok
              ? _readyText(status.result!.output)
              : 'The install stopped. Open the log for details.';
        } else if (linuxReady) {
          _hermesText = 'Not installed yet.';
        }
      });
    } catch (_) {
      // Leave the steps as not started; the buttons still work.
    }
  }

  String _readyText(String output) {
    final firstLine = output.split('\n').firstWhere(
          (l) => l.trim().isNotEmpty,
          orElse: () => '',
        );
    return firstLine.isEmpty ? 'Ready.' : 'Ready: ${firstLine.trim()}';
  }

  Future<String> _download({
    required String url,
    required String name,
    required String title,
    required void Function(DownloadState s) onState,
    bool wifiOnly = false,
  }) async {
    await _downloader.start(url: url, name: name, title: title, wifiOnly: wifiOnly);
    return _downloader.waitFor(name, onProgress: onState);
  }

  Future<void> _setupLinux() async {
    if (_busy) return;
    _busy = true;
    setState(() {
      _linux = StepState.working;
      _linuxText = 'Starting the download…';
      _linuxProgress = null;
    });
    try {
      final path = await _download(
        url: RuntimeImage.url,
        name: RuntimeImage.fileName,
        title: 'Linux base',
        wifiOnly: true,
        onState: (s) {
          if (!mounted) return;
          setState(() {
            if (s.state == 'waiting') {
              _linuxText = 'Waiting for Wi-Fi. It continues when Wi-Fi is on.';
              _linuxProgress = null;
            } else {
              _linuxText = 'Downloading… ${(s.fraction * 100).round()}%. '
                  'You can close the app; it keeps going.';
              _linuxProgress = s.fraction;
            }
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _linuxText = 'Unpacking…';
        _linuxProgress = 0;
      });
      widget.runtime.onProgress = (stage, f) {
        if (mounted) setState(() => _linuxProgress = f);
      };
      final r = await widget.runtime.installRootfs(path: path);
      if (!mounted) return;
      setState(() {
        _linux = r.ok ? StepState.done : StepState.failed;
        _linuxText = r.ok ? 'Ready.' : (r.error ?? 'It did not install. Try again.');
        _linuxProgress = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _linux = StepState.failed;
        _linuxText = e is UpdateException ? e.message : 'It did not install. Try again.';
        _linuxProgress = null;
      });
    } finally {
      widget.runtime.onProgress = null;
      _busy = false;
    }
  }

  Future<void> _installHermes() async {
    if (_busy || _linux != StepState.done) return;
    _busy = true;
    setState(() {
      _hermes = StepState.working;
      _hermesText = 'Downloading the installer…';
      _hermesLog = '';
      _hermesProgress = null;
    });
    try {
      final script = await _download(
        url: HermesPin.installerUrl,
        name: HermesPin.installerFileName,
        title: 'Hermes installer',
        onState: (s) {
          if (mounted) setState(() => _hermesProgress = s.fraction);
        },
      );
      if (!mounted) return;
      setState(() {
        _hermesText = 'Installing Hermes. This takes a long time. It continues in the background.';
        _hermesProgress = null;
      });
      await widget.runtime.hermesInstall(script: script);
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hermes = StepState.failed;
        _hermesText = e is UpdateException ? e.message : 'The install did not start. Try again.';
      });
      _busy = false;
    }
  }

  /// Follows the Hermes install until it finishes, showing its latest line.
  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final status = await widget.runtime.hermesStatus();
        if (!mounted) return;
        final log = plainLog(status.log);
        if (status.running) {
          setState(() {
            _hermes = StepState.working;
            _hermesLog = log;
            _hermesText = _latestLine(log, fallback: 'Installing…');
          });
        } else if (status.result != null) {
          _poll?.cancel();
          _busy = false;
          setState(() {
            _hermesLog = log;
            _hermes = status.result!.ok ? StepState.done : StepState.failed;
            _hermesText = status.result!.ok
                ? _readyText(status.result!.output)
                : 'The install stopped. Open the log for details.';
          });
        }
      } catch (_) {}
    });
  }

  String _latestLine(String log, {required String fallback}) {
    final lines = log.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    return lines.isEmpty ? fallback : lines.last;
  }

  Future<void> _loadFacts() async {
    try {
      final facts = await widget.runtime.describe();
      if (mounted) setState(() => _facts = facts);
    } catch (_) {}
  }

  Future<void> _runProotCheck() async {
    final r = await widget.runtime.prootVersion();
    if (mounted) setState(() => _techResult = _describe('proot --version', r));
  }

  Future<void> _runUnameCheck() async {
    final r = await widget.runtime.runUname();
    if (mounted) setState(() => _techResult = _describe('uname -a', r));
  }

  String _describe(String what, RunResult r) {
    final buffer = StringBuffer('$what: ${r.ok ? 'OK' : 'FAILED'}');
    if (r.exitCode != null) buffer.write(' (exit code ${r.exitCode})');
    if (r.error != null) buffer.write('\n${r.error}');
    if (r.output.isNotEmpty) buffer.write('\n\n${r.output}');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final logLines = _hermesLog.split('\n');
    final shownLog = logLines.length > 60
        ? logLines.sublist(logLines.length - 60).join('\n')
        : _hermesLog;
    return Scaffold(
      appBar: AppBar(title: const Text('Set up Herald')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Herald sets up a small Linux system and Hermes Agent on this phone. '
            'Use Wi-Fi. Downloads continue in the background.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          _StepCard(
            number: 1,
            title: 'Linux base',
            state: _linux,
            text: _linuxText,
            progress: _linuxProgress,
            buttonLabel: switch (_linux) {
              StepState.notStarted => 'Set up',
              StepState.failed => 'Try again',
              StepState.working => 'Working…',
              StepState.done => 'Ready',
            },
            onPressed: _linux == StepState.notStarted || _linux == StepState.failed
                ? _setupLinux
                : null,
          ),
          const SizedBox(height: 12),
          _StepCard(
            number: 2,
            title: 'Hermes Agent',
            state: _hermes,
            text: _hermesText,
            progress: _hermesProgress,
            buttonLabel: switch (_hermes) {
              StepState.notStarted => 'Install',
              StepState.failed => 'Try again',
              StepState.working => 'Installing…',
              StepState.done => 'Installed',
            },
            onPressed: _linux == StepState.done &&
                    (_hermes == StepState.notStarted || _hermes == StepState.failed)
                ? _installHermes
                : null,
          ),
          if (_hermesLog.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showLog = !_showLog),
              child: Text(_showLog ? 'Hide log' : 'Show log'),
            ),
            if (_showLog)
              SelectableText(
                shownLog,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
              ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => _showDetails = !_showDetails);
              if (_showDetails) _loadFacts();
            },
            child: Text(_showDetails ? 'Hide technical details' : 'Show technical details'),
          ),
          if (_showDetails) ...[
            SelectableText(
              _facts.isEmpty
                  ? 'Loading…'
                  : _facts.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _runProotCheck, child: const Text('Run proot --version')),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _runUnameCheck, child: const Text('Run uname -a in Linux')),
            if (_techResult.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                _techResult,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.state,
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
    this.progress,
  });

  final int number;
  final String title;
  final StepState state;
  final String text;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final double? progress;

  static const _accent = Color(0xFF8B4DFF);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      StepState.done => (Icons.check_circle, Colors.green),
      StepState.failed => (Icons.error, Colors.red),
      StepState.working => (Icons.hourglass_top, _accent),
      StepState.notStarted => (Icons.radio_button_unchecked, Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$number. $title',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: Color(0xFF55525E), height: 1.4)),
          if (state == StepState.working) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: _accent,
                backgroundColor: const Color(0xFFE9E3FF),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                shape: const StadiumBorder(),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}
