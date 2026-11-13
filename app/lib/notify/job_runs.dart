/// Plain-word notices for finished scheduled-job runs (WBS 0.3.4).
///
/// Hermes lists each job with its newest run (`GET /api/jobs`, `latest_execution`).
/// This file decides which finished runs are new, so each run is announced once.
/// It holds no prompt text: a job's name is the only words shown.
library;

/// Shown when a job has no name of its own.
const String fallbackJobName = 'Scheduled job';

const int _maxNameLength = 60;

const Set<String> _finishedStatuses = {'completed', 'failed', 'unknown'};

/// A run is finished once Hermes writes a final status. Running or claimed runs are not.
bool isFinishedRunStatus(String? status) =>
    status != null && _finishedStatuses.contains(status);

/// The name to show. Hermes fills in a name from the prompt when a job has none, so a
/// name that is just the start of the prompt (or empty) is replaced by [fallbackJobName].
String displayNameFor(String rawName, String prompt) {
  final name = _clean(rawName);
  final text = _clean(prompt);
  if (name.isEmpty || (text.isNotEmpty && text.startsWith(name))) {
    return fallbackJobName;
  }
  if (name.length > _maxNameLength) {
    return '${name.substring(0, _maxNameLength - 3)}...';
  }
  return name;
}

String _clean(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

String? _text(Object? value) => value is String && value.isNotEmpty ? value : null;

/// One job, as the notifier needs it. The prompt is read only to check the name, then dropped.
class JobRunSnapshot {
  const JobRunSnapshot({
    required this.jobId,
    required this.name,
    this.executionId,
    this.status,
  });

  final String jobId;

  /// The safe display name (see [displayNameFor]).
  final String name;

  /// The newest run's id, or null when the job has never run.
  final String? executionId;

  /// The newest run's status, such as "running" or "completed".
  final String? status;

  factory JobRunSnapshot.fromJson(Map<String, dynamic> json) {
    final execution = json['latest_execution'];
    final run = execution is Map<String, dynamic> ? execution : const <String, dynamic>{};
    return JobRunSnapshot(
      jobId: _text(json['id']) ?? '',
      name: displayNameFor(_text(json['name']) ?? '', _text(json['prompt']) ?? ''),
      executionId: _text(run['id']),
      status: _text(run['status']),
    );
  }
}

/// A run that has finished and has not been announced yet.
class RunNotice {
  const RunNotice({
    required this.jobId,
    required this.name,
    required this.executionId,
    required this.status,
  });

  final String jobId;
  final String name;
  final String executionId;
  final String status;

  String get title => switch (status) {
        'completed' => 'Job finished',
        'failed' => 'Job failed',
        _ => 'Job ended unclearly',
      };

  String get body => switch (status) {
        'completed' => '$name finished.',
        'failed' => '$name did not finish. Open Herald to see why.',
        _ => '$name stopped before it could report a result.',
      };

  /// A stable id per run, so one run's notification does not stack on another's.
  int get notificationId => executionId.hashCode & 0x7fffffff;
}

/// What one check decided: the notices to show now, and the state to save first.
class RunDecision {
  const RunDecision({required this.notices, required this.writes});

  final List<RunNotice> notices;

  /// Job id to the value to save. An empty value means "known, nothing announced yet".
  final Map<String, String> writes;
}

/// Decides which finished runs are new.
///
/// [lastNotified] maps a job id to the saved value, or to null when the job was never seen.
///
/// - Never seen: the first look is silent. A finished run is accepted as known; anything
///   else is saved as "nothing announced yet", so the run is announced when it finishes.
/// - Seen before: announce the newest run once, when it is finished and is not the one
///   already announced.
RunDecision decideRunNotices(
  List<JobRunSnapshot> jobs,
  Map<String, String?> lastNotified,
) {
  final notices = <RunNotice>[];
  final writes = <String, String>{};
  for (final job in jobs) {
    if (job.jobId.isEmpty) continue;
    final seen = lastNotified[job.jobId];
    // The newest run's id, but only once it has finished; otherwise null.
    final finished = isFinishedRunStatus(job.status) ? job.executionId : null;
    if (seen == null) {
      writes[job.jobId] = finished ?? '';
    } else if (finished != null && finished != seen) {
      notices.add(RunNotice(
        jobId: job.jobId,
        name: job.name,
        executionId: finished,
        status: job.status ?? '',
      ));
      writes[job.jobId] = finished;
    }
  }
  return RunDecision(notices: notices, writes: writes);
}
