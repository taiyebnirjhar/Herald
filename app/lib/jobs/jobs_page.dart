import 'package:flutter/material.dart';

import '../chat/engine_connection.dart';
import '../chat/native_chat_page.dart';
import 'jobs_api.dart';

/// Scheduled jobs (WBS 0.3.5): see them, run one now, pause or resume.
/// Creating jobs comes later; for now the web screen creates them.
class JobsPage extends StatefulWidget {
  const JobsPage({super.key, this.connection, this.createApi});

  final EngineConnection? connection;

  /// Builds the client from the address. Tests pass one that uses a mock server.
  final JobsApi Function(EngineAddress address)? createApi;

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  JobsApi? _api;
  List<ScheduledJob> _jobs = const [];
  bool _loading = true;
  String? _problem;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api?.close();
    super.dispose();
  }

  Future<JobsApi> _client() async {
    final existing = _api;
    if (existing != null) return existing;
    final address = await (widget.connection ?? MethodChannelEngineConnection()).address();
    final api = (widget.createApi ?? _defaultApi)(address);
    _api = api;
    return api;
  }

  JobsApi _defaultApi(EngineAddress a) => JobsApi(port: a.port, apiKey: a.key);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _problem = null;
    });
    try {
      final jobs = await (await _client()).list();
      if (!mounted) return;
      setState(() {
        _jobs = jobs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _problem = e is JobsApiException ? e.message : "Herald couldn't read its connection details.";
        _loading = false;
      });
    }
  }

  Future<void> _act(ScheduledJob job, String verb, Future<void> Function(JobsApi api) action) async {
    setState(() => _busy.add(job.id));
    try {
      await action(await _client());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$verb: ${job.name}')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is JobsApiException ? e.message : 'Something went wrong. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(job.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatLook.bg,
      appBar: AppBar(
        backgroundColor: ChatLook.bg,
        foregroundColor: ChatLook.text,
        title: const Text('Scheduled jobs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_problem != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_problem!, textAlign: TextAlign.center, style: const TextStyle(color: ChatLook.problem)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_jobs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No scheduled jobs yet. Create one in the Hermes web screen, and it will show here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ChatLook.muted, height: 1.4),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _card(_jobs[i]),
    );
  }

  Widget _card(ScheduledJob job) {
    final busy = _busy.contains(job.id);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatLook.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ChatLook.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.name,
                  style: const TextStyle(color: ChatLook.text, fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                job.paused ? 'Paused' : 'On',
                style: TextStyle(color: job.paused ? ChatLook.muted : ChatLook.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (job.scheduleText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(job.scheduleText, style: const TextStyle(color: ChatLook.muted)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => _act(job, 'Started', (api) => api.runNow(job.id)),
                  child: const Text('Run now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => job.paused
                          ? _act(job, 'Resumed', (api) => api.resume(job.id))
                          : _act(job, 'Paused', (api) => api.pause(job.id)),
                  child: Text(job.paused ? 'Resume' : 'Pause'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
