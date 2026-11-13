import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/notify/job_run_watcher.dart';
import 'package:herald/notify/job_runs.dart';

class _FakeJobs implements JobListSource {
  List<JobRunSnapshot> next = [];
  Object? error;
  int calls = 0;

  @override
  Future<List<JobRunSnapshot>> fetch() async {
    calls++;
    if (error != null) throw error!;
    return next;
  }
}

class _MemoryState implements RunStateStore {
  final values = <String, String>{};

  @override
  Future<String?> lastNotified(String jobId) async => values[jobId];

  @override
  Future<void> setLastNotified(String jobId, String value) async => values[jobId] = value;
}

typedef _Shown = ({int id, String title, String body});

class _RecordingNotifier implements RunNotifier {
  final shown = <_Shown>[];

  @override
  Future<void> show({required int id, required String title, required String body}) async {
    shown.add((id: id, title: title, body: body));
  }
}

JobRunSnapshot _job(String id, String exec, String status) =>
    JobRunSnapshot(jobId: id, name: 'Morning news', executionId: exec, status: status);

void main() {
  late _FakeJobs jobs;
  late _MemoryState state;
  late _RecordingNotifier notifier;
  late JobRunWatcher watcher;

  setUp(() {
    jobs = _FakeJobs();
    state = _MemoryState();
    notifier = _RecordingNotifier();
    watcher = JobRunWatcher(jobs: jobs, state: state, notifier: notifier);
  });

  test('the first look is silent, then a finished run is shown once', () async {
    jobs.next = [_job('j1', 'e1', 'running')];
    expect(await watcher.checkNow(), 0);

    jobs.next = [_job('j1', 'e1', 'completed')];
    expect(await watcher.checkNow(), 1);
    expect(notifier.shown.single.title, 'Job finished');
    expect(notifier.shown.single.body, 'Morning news finished.');

    expect(await watcher.checkNow(), 0);
    expect(notifier.shown.length, 1);
  });

  test('state is saved before the notification is shown', () async {
    jobs.next = [_job('j1', 'e1', 'running')];
    await watcher.checkNow();
    jobs.next = [_job('j1', 'e1', 'failed')];
    await watcher.checkNow();
    expect(state.values['j1'], 'e1');
  });

  test('a failed fetch is skipped quietly and changes nothing', () async {
    jobs.error = StateError('Hermes is not answering');
    expect(await watcher.checkNow(), 0);
    expect(state.values, isEmpty);
    expect(notifier.shown, isEmpty);
  });

  test('two checks at the same time do not overlap', () async {
    jobs.next = [_job('j1', 'e1', 'running')];
    final first = watcher.checkNow();
    final second = await watcher.checkNow();
    expect(second, 0);
    await first;
    expect(jobs.calls, 1);
  });

  test('start checks at once and stop ends the periodic check', () async {
    final w = JobRunWatcher(
      jobs: jobs,
      state: state,
      notifier: notifier,
      interval: const Duration(hours: 1),
    );
    w.start();
    expect(w.isRunning, isTrue);
    w.start();
    await Future<void>.delayed(Duration.zero);
    expect(jobs.calls, 1);
    w.stop();
    expect(w.isRunning, isFalse);
  });

  test('the notification id comes from the run', () async {
    jobs.next = [_job('j1', 'e1', 'running')];
    await watcher.checkNow();
    jobs.next = [_job('j1', 'e1', 'completed')];
    await watcher.checkNow();
    expect(
      notifier.shown.single.id,
      const RunNotice(jobId: 'j1', name: 'Morning news', executionId: 'e1', status: 'completed')
          .notificationId,
    );
  });

  group('RunWatchHost', () {
    testWidgets('starts the watcher when resumed and stops it when paused', (tester) async {
      final starts = <String>[];
      final stops = <String>[];
      final fake = _RecordingWatcher(jobs: jobs, state: state, notifier: notifier, starts: starts, stops: stops);
      final shown = ValueNotifier<bool>(true);
      addTearDown(shown.dispose);
      await tester.pumpWidget(ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, on, _) => on
            ? RunWatchHost(
                watcher: fake,
                child: const Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text('home'),
                ),
              )
            : const SizedBox(),
      ));
      expect(find.text('home'), findsOneWidget);
      expect(starts, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(starts, ['start']);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      expect(stops, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(stops, ['stop']);

      // A paused app draws no frames, so bring it back before the screen goes away.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(starts, ['start', 'start']);
      shown.value = false;
      await tester.pump();
      expect(stops, ['stop', 'stop']);
    });

    testWidgets('with no watcher it just shows its child', (tester) async {
      await tester.pumpWidget(const RunWatchHost(
        watcher: null,
        child: Directionality(textDirection: TextDirection.ltr, child: Text('plain')),
      ));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(find.text('plain'), findsOneWidget);
    });
  });
}

class _RecordingWatcher extends JobRunWatcher {
  _RecordingWatcher({
    required super.jobs,
    required super.state,
    required super.notifier,
    required this.starts,
    required this.stops,
  });

  final List<String> starts;
  final List<String> stops;

  @override
  void start() => starts.add('start');

  @override
  void stop() => stops.add('stop');
}
