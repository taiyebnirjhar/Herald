import 'package:flutter/material.dart';

import '../runtime/runtime_channel.dart';

/// Debug screen for the Linux runtime spike (WBS 1.2). Shows what the app has
/// and runs `proot --version`. Owner's phone test; not for players.
class RuntimeDebugPage extends StatefulWidget {
  const RuntimeDebugPage({super.key, required this.runtime});

  final RuntimeChannel runtime;

  @override
  State<RuntimeDebugPage> createState() => _RuntimeDebugPageState();
}

class _RuntimeDebugPageState extends State<RuntimeDebugPage> {
  Map<String, dynamic> _facts = {};
  String _result = 'Not run yet.';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _loadFacts();
  }

  Future<void> _loadFacts() async {
    try {
      final facts = await widget.runtime.describe();
      if (mounted) setState(() => _facts = facts);
    } catch (e) {
      if (mounted) setState(() => _facts = {'error': '$e'});
    }
  }

  Future<void> _runProot() async {
    setState(() {
      _running = true;
      _result = 'Running proot --version…';
    });
    try {
      final check = await widget.runtime.prootVersion();
      setState(() => _result = _describeRun(check));
    } catch (e) {
      setState(() => _result = 'FAILED\n$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _describeRun(RunResult check) {
    final buffer = StringBuffer(check.ok ? 'OK' : 'FAILED');
    if (check.exitCode != null) buffer.write(' (exit code ${check.exitCode})');
    if (check.error != null) buffer.write('\n${check.error}');
    if (check.output.isNotEmpty) buffer.write('\n\n${check.output}');
    return buffer.toString();
  }

  Future<void> _installLinux() async {
    setState(() {
      _running = true;
      _result = 'Starting the install…';
    });
    widget.runtime.onProgress = (stage, fraction) {
      if (mounted) {
        setState(() => _result = '$stage… ${(fraction * 100).round()}%');
      }
    };
    try {
      final r = await widget.runtime.installRootfs();
      setState(() => _result = 'Install: ${_describeRun(r)}');
      await _loadFacts();
    } catch (e) {
      setState(() => _result = 'Install FAILED\n$e');
    } finally {
      widget.runtime.onProgress = null;
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _installHermes() async {
    setState(() {
      _running = true;
      _result = 'Installing Hermes Agent. This can take a long time. Keep the app open and the screen on.';
    });
    // Poll the installer's log while it runs.
    var polling = true;
    () async {
      while (polling && mounted) {
        await Future<void>.delayed(const Duration(seconds: 3));
        try {
          final status = await widget.runtime.hermesStatus();
          if (mounted && polling && status.log.isNotEmpty) {
            setState(() => _result = 'Installing Hermes…\n\n${status.log}');
          }
        } catch (_) {}
      }
    }();
    try {
      final r = await widget.runtime.hermesInstall();
      setState(() => _result = 'Hermes install: ${_describeRun(r)}');
    } catch (e) {
      setState(() => _result = 'Hermes install FAILED\n$e');
    } finally {
      polling = false;
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _runUname() async {
    setState(() {
      _running = true;
      _result = 'Running uname -a inside Linux…';
    });
    try {
      final r = await widget.runtime.runUname();
      setState(() => _result = 'uname -a: ${_describeRun(r)}');
    } catch (e) {
      setState(() => _result = 'uname FAILED\n$e');
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
