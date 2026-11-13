import 'package:flutter_test/flutter_test.dart';
import 'package:herald/supervisor/app_log.dart';
import 'package:herald/supervisor/restart_backoff.dart';

void main() {
  group('RestartBackoff', () {
    test('doubles the wait each time, then gives up after five tries', () {
      final b = RestartBackoff();
      final waits = [for (var i = 0; i < 5; i++) b.next()];
      expect(waits, [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
        const Duration(seconds: 8),
        const Duration(seconds: 16),
        const Duration(seconds: 32),
      ]);
      expect(b.giveUp, isTrue);
      expect(() => b.next(), throwsStateError);
    });

    test('the wait never goes past the cap', () {
      final b = RestartBackoff(maxAttempts: 10);
      Duration last = Duration.zero;
      for (var i = 0; i < 10; i++) {
        last = b.next();
      }
      expect(last, const Duration(minutes: 1));
    });

    test('reset starts the count again', () {
      final b = RestartBackoff();
      b.next();
      b.next();
      b.reset();
      expect(b.attempts, 0);
      expect(b.next(), const Duration(seconds: 2));
    });
  });

  group('AppLog', () {
    test('keeps only the last lines', () {
      final log = AppLog(maxLines: 3);
      for (var i = 1; i <= 5; i++) {
        log.add('line $i');
      }
      expect(log.lines, ['line 3', 'line 4', 'line 5']);
    });

    test('removes API keys, tokens and passwords before they are kept', () {
      final log = AppLog();
      log.add('key sk-abcdefgh12345678 in use');
      log.add('api_key=supersecret123 set');
      log.add('Authorization: Bearer ghp_abcdefghijklmnopqrstuvwx');
      log.add('password: hunter2');
      final text = log.text();
      expect(text, isNot(contains('sk-abcdefgh')));
      expect(text, isNot(contains('supersecret')));
      expect(text, isNot(contains('ghp_abcdef')));
      expect(text, isNot(contains('hunter2')));
      expect(text, contains('[redacted]'));
    });

    test('ordinary lines are left as they are', () {
      expect(AppLog.redact('Linux localhost aarch64 GNU/Linux'), 'Linux localhost aarch64 GNU/Linux');
    });
  });
}
