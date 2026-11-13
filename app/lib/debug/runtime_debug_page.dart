import 'dart:async';

import 'package:flutter/material.dart';

import '../downloads/background_downloader.dart';
import '../runtime/hermes_pin.dart';
import '../runtime/runtime_channel.dart';
import '../runtime/runtime_image.dart';

/// Debug screen for the Linux runtime and Hermes (WBS 1.2 to 1.4). Owner's phone
/// test; not for players. Downloads run in the background; the screen follows them.
class RuntimeDebugPage extends StatefulWidget {
  const RuntimeDebugPage({super.key, required this.runtime, this.downloader});

  final RuntimeChannel runtime;

  /// Downloads go through this. Defaults to the app's background downloader.
  final BackgroundDownloader? downloader;

  @override
  State<RuntimeDebugPage> createState() => _RuntimeDebugPageState();
}

class _RuntimeDebugPageState extends State<RuntimeDebugPage> {
  late final BackgroundDownloader _downloader =
      widget.downloader ?? MethodChannelDownloader();
  Map<String, dynamic> _facts = {};
  String _result = 'Not run yet.';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _loadFacts();
  }

  @override
  void dispose() {
    widget.runtime.onProgress = null;
    super.dispose();
  }

  Future<void> _loadFacts() async {
    try {
      final facts = await widget.runtime.describe();
      if (mounted) setState(() => _facts = facts);
    } catch (e) {
      if (mounted) setState(() => _facts = {'error': '$e'});
    }
  }

  void _show(String text) {
    if (mounted) setState(() => _result = text);
  }

  String _describeRun(RunResult check) {
    final buffer = StringBuffer(check.ok ? 'OK' : 'FAILED');
    if (check.exitCode != null) buffer.write(' (exit code ${check.exitCode})');
    if (check.error != null) buffer.write('\n${check.error}');
    if (check.output.isNotEmpty) buffer.write('\n\n${check.output}');
    return buffer.toString();
  }

  Future<void> _runProot() async {
    setState(() => _running = true);
    try {
      _show(_describeRun(await widget.runtime.prootVersion()));
    } catch (e) {
      _show('FAILED\n$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// Downloads [name] in the background, showing its progress, and returns its path.
  Future<String> _download({
    required String url,
    required String name,
    required String title,
    bool wifiOnly = false,
  }) async {
    await _downloader.start(url: url, name: name, title: title, wifiOnly: wifiOnly);
    return _downloader.waitFor(
      name,
      onProgress: (s) {
        if (s.state == 'waiting') {
          _show('$title: waiting for Wi-Fi. The download continues when it is available.');
        } else if (s.state == 'running') {
          _show('$title: downloading… ${(s.fraction * 100).round()}%\n'
              'You can close the app; the download continues.');
        }
      },
    );
  }

  Future<void> _installLinux() async {
    setState(() => _running = true);
    try {
      final path = await _download(
        url: RuntimeImage.url,
        name: RuntimeImage.fileName,
        title: 'Linux base',
        wifiOnly: true,
      );
      _show('Linux base downloaded. Unpacking…');
      widget.runtime.onProgress = (stage, f) => _show('$stage… ${(f * 100).round()}%');
      final r = await widget.runtime.installRootfs(path: path);
      _show('Install: ${_describeRun(r)}');
      await _loadFacts();
    } catch (e) {
      _show('Install FAILED\n$e');
    } finally {
      widget.runtime.onProgress = null;
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _installHermes() async {
    setState(() => _running = true);
    Timer? poll;
    try {
      final script = await _download(
        url: HermesPin.installerUrl,
        name: HermesPin.installerFileName,
        title: 'Hermes installer',
      );
      _show('Installing Hermes Agent. This can take a long time. It continues in the background.');
      await widget.runtime.hermesInstall(script: script);
      // Poll the installer's log until it finishes.
      final done = Completer<void>();
      poll = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final status = await widget.runtime.hermesStatus();
          if (!mounted) return;
          if (status.running) {
            _show('Installing Hermes…\n\n${status.log}');
          } else if (status.result != null) {
            _show('Hermes install: ${_describeRun(status.result!)}\n\n${status.log}');
            if (!done.isCompleted) done.complete();
          }
        } catch (_) {}
      });
      await done.future;
    } catch (e) {
      _show('Hermes install FAILED\n$e');
    } finally {
      poll?.cancel();
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runUname() async {
    setState(() => _running = true);
    try {
      _show('uname -a: ${_describeRun(await widget.runtime.runUname())}');
    } catch (e) {
      _show('uname FAILED\n$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Runtime check (debug)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('What the app has', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(
            _facts.isEmpty
                ? 'Loading…'
                : _facts.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _running ? null : _runProot,
            child: Text(_running ? 'Running…' : 'Run proot --version'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _running ? null : _installLinux,
            child: const Text('Install Linux base (1.3)'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _running ? null : _runUname,
            child: const Text('Run uname -a in Linux'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _running ? null : _installHermes,
            child: const Text('Install Hermes (1.4)'),
          ),
          const SizedBox(height: 16),
          const Text('Result', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(
            _result,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
