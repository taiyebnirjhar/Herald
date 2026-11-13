import 'dart:async';

import 'package:flutter/widgets.dart';

import 'job_runs.dart';

/// Where the job list comes from. The real one asks Hermes; tests use a fake.
abstract class JobListSource {
  Future<List<JobRunSnapshot>> fetch();
}

/// The saved "last announced run" for each job (kept on the Android side).
abstract class RunStateStore {
  /// The saved value, or null when the job was never seen.
  Future<String?> lastNotified(String jobId);

  Future<void> setLastNotified(String jobId, String value);
}

/// Shows a notification on the "Agent results" channel.
abstract class RunNotifier {
  Future<void> show({required int id, required String title, required String body});
}

/// Checks the scheduled jobs every minute while the app is open, and announces each
/// finished run once (WBS 0.3.4). Any failure (Hermes not answering, for example)
/// is skipped quietly and tried again on the next check.
class JobRunWatcher {
  JobRunWatcher({
    required this.jobs,
    required this.state,
    required this.notifier,
    this.interval = const Duration(seconds: 60),
  });

  final JobListSource jobs;
  final RunStateStore state;
  final RunNotifier notifier;
  final Duration interval;

  Timer? _timer;
  bool _checking = false;

  bool get isRunning => _timer != null;

  /// Checks now, then every [interval]. Does nothing if already running.
  void start() {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => checkNow());
    checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One check. Returns how many notifications were shown. Never throws.
  Future<int> checkNow() async {
    if (_checking) return 0;
    _checking = true;
    try {
      final list = await jobs.fetch();
      final last = <String, String?>{};
      for (final job in list) {
        if (job.jobId.isNotEmpty) last[job.jobId] = await state.lastNotified(job.jobId);
      }
      final decision = decideRunNotices(list, last);
      // Save first: a run is never announced twice, even if showing fails.
      for (final entry in decision.writes.entries) {
        await state.setLastNotified(entry.key, entry.value);
      }
      for (final notice in decision.notices) {
        await notifier.show(
          id: notice.notificationId,
          title: notice.title,
          body: notice.body,
        );
      }
      return decision.notices.length;
    } catch (_) {
      return 0;
    } finally {
      _checking = false;
    }
  }
}

/// Runs the watcher only while the app is in front. Put it above the app's screens.
class RunWatchHost extends StatefulWidget {
  const RunWatchHost({super.key, required this.watcher, required this.child});

  final JobRunWatcher? watcher;
  final Widget child;

  @override
  State<RunWatchHost> createState() => _RunWatchHostState();
}

class _RunWatchHostState extends State<RunWatchHost> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      widget.watcher?.start();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        widget.watcher?.start();
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        widget.watcher?.stop();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.watcher?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
