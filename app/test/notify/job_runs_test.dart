import 'package:flutter_test/flutter_test.dart';
import 'package:herald/notify/job_runs.dart';

JobRunSnapshot _job(String id, String? exec, String? status, {String name = 'Morning news'}) =>
    JobRunSnapshot(jobId: id, name: name, executionId: exec, status: status);

/// One poll against a saved map, the way the watcher does it.
List<RunNotice> _poll(Map<String, String?> saved, List<JobRunSnapshot> jobs) {
  final decision = decideRunNotices(jobs, saved);
  saved.addAll(decision.writes);
  return decision.notices;
}

void main() {
  group('decideRunNotices', () {
    test('a finished run seen first is accepted silently', () {
      final saved = <String, String?>{};
      expect(_poll(saved, [_job('j1', 'e1', 'completed')]), isEmpty);
      expect(saved['j1'], 'e1');
    });

    test('a run still going when first seen is announced once it finishes', () {
      final saved = <String, String?>{};
      expect(_poll(saved, [_job('j1', 'e1', 'running')]), isEmpty);
      expect(saved['j1'], '');
      expect(_poll(saved, [_job('j1', 'e1', 'running')]), isEmpty);
      final notices = _poll(saved, [_job('j1', 'e1', 'completed')]);
      expect(notices.map((n) => n.executionId), ['e1']);
      expect(notices.single.body, 'Morning news finished.');
    });

    test('a run is announced only once', () {
      final saved = <String, String?>{'j1': 'e0'};
      expect(_poll(saved, [_job('j1', 'e1', 'completed')]).length, 1);
      expect(_poll(saved, [_job('j1', 'e1', 'completed')]), isEmpty);
      expect(_poll(saved, [_job('j1', 'e1', 'completed')]), isEmpty);
    });

    test('a new run after an announced one is announced too', () {
      final saved = <String, String?>{};
      _poll(saved, [_job('j1', 'e1', 'completed')]);
      expect(_poll(saved, [_job('j1', 'e2', 'running')]), isEmpty);
      expect(_poll(saved, [_job('j1', 'e2', 'completed')]).length, 1);
    });

    test('a run that starts and ends between polls is announced', () {
      final saved = <String, String?>{'j1': 'e1'};
      final notices = _poll(saved, [_job('j1', 'e2', 'failed')]);
      expect(notices.single.title, 'Job failed');
      expect(notices.single.body, contains('did not finish'));
    });

    test('a job that has never run is announced when its first run ends', () {
      final saved = <String, String?>{};
      expect(_poll(saved, [_job('j1', null, null)]), isEmpty);
      expect(saved['j1'], '');
      expect(_poll(saved, [_job('j1', 'e1', 'completed')]).length, 1);
    });

    test('an unknown ending uses plain words', () {
      final saved = <String, String?>{'j1': ''};
      final notice = _poll(saved, [_job('j1', 'e1', 'unknown')]).single;
      expect(notice.title, 'Job ended unclearly');
      expect(notice.body, 'Morning news stopped before it could report a result.');
    });

    test('a run still in progress is not announced', () {
      final saved = <String, String?>{'j1': 'e1'};
      expect(_poll(saved, [_job('j1', 'e2', 'claimed')]), isEmpty);
      expect(_poll(saved, [_job('j1', 'e2', 'running')]), isEmpty);
      expect(saved['j1'], 'e1');
    });

    test('jobs are tracked separately, and jobs without an id are skipped', () {
      final saved = <String, String?>{'a': 'x1', 'b': 'y1'};
      final notices = _poll(saved, [
        _job('a', 'x2', 'completed'),
        _job('b', 'y1', 'completed'),
        _job('', 'z1', 'completed'),
      ]);
      expect(notices.map((n) => n.jobId), ['a']);
      expect(saved.containsKey(''), isFalse);
    });

    test('notification ids differ between runs', () {
      const a = RunNotice(jobId: 'j', name: 'n', executionId: 'exec-1', status: 'completed');
      const b = RunNotice(jobId: 'j', name: 'n', executionId: 'exec-2', status: 'completed');
      expect(a.notificationId, isNot(b.notificationId));
      expect(a.notificationId, greaterThanOrEqualTo(0));
    });
  });

  group('notice text', () {
    test('completed, failed and unknown read in plain words', () {
      const done = RunNotice(jobId: 'j', name: 'Backup', executionId: 'e', status: 'completed');
      const bad = RunNotice(jobId: 'j', name: 'Backup', executionId: 'e', status: 'failed');
      const odd = RunNotice(jobId: 'j', name: 'Backup', executionId: 'e', status: 'unknown');
      expect(done.title, 'Job finished');
      expect(done.body, 'Backup finished.');
      expect(bad.title, 'Job failed');
      expect(bad.body, 'Backup did not finish. Open Herald to see why.');
      expect(odd.title, 'Job ended unclearly');
    });
  });

  group('JobRunSnapshot.fromJson', () {
    test('reads id, name and the newest run, and drops the prompt', () {
      final job = JobRunSnapshot.fromJson({
        'id': 'job-1',
        'name': 'Morning news',
        'prompt': 'Summarise the news and keep my API token safe',
        'latest_execution': {'id': 'exec-1', 'status': 'completed', 'pid': 42},
      });
      expect(job.jobId, 'job-1');
      expect(job.name, 'Morning news');
      expect(job.executionId, 'exec-1');
      expect(job.status, 'completed');
      expect(job.toString(), isNot(contains('token')));
    });

    test('a job with no run has null run fields', () {
      final job = JobRunSnapshot.fromJson({'id': 'j', 'name': 'x', 'latest_execution': null});
      expect(job.executionId, isNull);
      expect(job.status, isNull);
    });

    test('Hermes-made names from the prompt are replaced by the fallback', () {
      const prompt = 'Summarise the top ten world news stories and send them to me';
      final job = JobRunSnapshot.fromJson({'id': 'j', 'name': prompt.substring(0, 50), 'prompt': prompt});
      expect(job.name, fallbackJobName);
    });

    test('bad types are ignored instead of throwing', () {
      final job = JobRunSnapshot.fromJson({
        'id': 42,
        'name': null,
        'latest_execution': 'nope',
      });
      expect(job.jobId, '');
      expect(job.name, fallbackJobName);
      expect(job.executionId, isNull);
    });
  });

  group('displayNameFor', () {
    test('keeps a name the user gave', () {
      expect(displayNameFor('Morning news', 'Summarise the news'), 'Morning news');
    });

    test('collapses spaces and shortens long names', () {
      expect(displayNameFor('  a \n  b ', ''), 'a b');
      final shown = displayNameFor('x' * 100, '');
      expect(shown.length, 60);
      expect(shown.endsWith('...'), isTrue);
    });

    test('an empty name becomes the fallback', () {
      expect(displayNameFor('   ', 'Some prompt'), fallbackJobName);
    });
  });
}
