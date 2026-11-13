import 'package:flutter/services.dart';

/// What a proot-based run returned.
class RunResult {
  const RunResult({required this.ok, required this.output, this.error, this.exitCode});
  final bool ok;
  final String output;
  final String? error;
  final int? exitCode;

  factory RunResult.fromMap(Map<String, dynamic> map) => RunResult(
        ok: map['ok'] == true,
        output: map['output'] as String? ?? '',
        error: map['error'] as String?,
        exitCode: map['exitCode'] as int?,
      );
}

/// Whether the Hermes install is running, its log so far, and its result when done.
class HermesStatus {
  const HermesStatus({required this.running, required this.log, this.result});
  final bool running;
  final String log;
  final RunResult? result;
}

/// The Linux runtime pieces, as the Android side reports them (WBS 1.2 to 1.4).
class RuntimeChannel {
  RuntimeChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const _name = 'herald/runtime';
  final MethodChannel _channel;

  /// Set this to see the progress of an unpack: a stage name and its fraction (0–1).
  void Function(String stage, double fraction)? onProgress;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'progress') {
      final args = Map<String, dynamic>.from(call.arguments as Map);
      onProgress?.call(
        args['stage'] as String,
        (args['fraction'] as num).toDouble(),
      );
    }
    return null;
  }

  Future<Map<String, dynamic>> describe() async =>
      Map<String, dynamic>.from(await _channel.invokeMapMethod<String, dynamic>('describe') ?? {});

  Future<RunResult> prootVersion() async => RunResult.fromMap(
        Map<String, dynamic>.from(
            await _channel.invokeMapMethod<String, dynamic>('prootVersion') ?? {}),
      );

  /// Unpacks the downloaded Linux base system at [path]. Can take minutes; see [onProgress].
  Future<RunResult> installRootfs({required String path}) async => RunResult.fromMap(
        Map<String, dynamic>.from(
          await _channel.invokeMapMethod<String, dynamic>(
                  'installRootfs', {'path': path}) ??
              {},
        ),
      );

  /// `uname -a` inside the Linux base system.
  Future<RunResult> runUname() async => RunResult.fromMap(
        Map<String, dynamic>.from(
            await _channel.invokeMapMethod<String, dynamic>('runUname') ?? {}),
      );

  /// Starts the Hermes install with the downloaded installer at [script]. It runs
  /// in a foreground service; poll [hermesStatus] for its progress.
  Future<void> hermesInstall({required String script}) async {
    await _channel.invokeMapMethod<String, dynamic>('hermesInstall', {'script': script});
  }

  Future<HermesStatus> hermesStatus() async {
    final map = Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('hermesStatus') ?? {});
    final result = map['result'];
    return HermesStatus(
      running: map['running'] == true,
      log: map['log'] as String? ?? '',
      result: result is Map
          ? RunResult.fromMap(Map<String, dynamic>.from(result))
          : null,
    );
  }

  /// Starts Hermes's dashboard in the foreground service; it restarts itself if it stops.
  Future<void> startHermes() async {
    await _channel.invokeMapMethod<String, dynamic>('startHermes');
  }

  /// Stops Hermes and its restarts.
  Future<void> stopHermes() async {
    await _channel.invokeMapMethod<String, dynamic>('stopHermes');
  }

  /// Hermes's state: stopped, starting, ready, restarting or gave up, with a plain message.
  Future<({String phase, String message})> hermesHealth() async {
    final map = Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('hermesHealth') ?? {});
    return (
      phase: map['phase'] as String? ?? 'STOPPED',
      message: map['message'] as String? ?? 'Hermes is stopped.',
    );
  }
}
