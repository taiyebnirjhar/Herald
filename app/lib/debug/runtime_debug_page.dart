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
      final buffer = StringBuffer(check.ok ? 'OK' : 'FAILED');
      if (check.exitCode != null) buffer.write(' (exit code ${check.exitCode})');
      if (check.error != null) buffer.write('\n${check.error}');
      if (check.output.isNotEmpty) buffer.write('\n\n${check.output}');
      setState(() => _result = buffer.toString());
    } catch (e) {
      setState(() => _result = 'FAILED\n$e');
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
