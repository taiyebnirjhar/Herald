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

/// The Linux runtime pieces, as the Android side reports them (WBS 1.2, 1.3).
class RuntimeChannel {
  RuntimeChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name) {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const _name = 'herald/runtime';
  final MethodChannel _channel;

  /// Set this to see the install's progress: a stage name and its fraction (0–1).
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

  /// Unpacks the Linux base system bundled in the app (or downloads it, in builds
  /// without the bundled copy). Can take a few minutes; see [onProgress].
  Future<RunResult> installRootfs() async => RunResult.fromMap(Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('installRootfs') ?? {},
      ));

  /// `uname -a` inside the Linux base system.
  Future<RunResult> runUname() async => RunResult.fromMap(
        Map<String, dynamic>.from(
            await _channel.invokeMapMethod<String, dynamic>('runUname') ?? {}),
      );
}
