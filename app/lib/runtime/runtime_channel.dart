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
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/runtime';
  final MethodChannel _channel;

  Future<Map<String, dynamic>> describe() async =>
      Map<String, dynamic>.from(await _channel.invokeMapMethod<String, dynamic>('describe') ?? {});

  Future<RunResult> prootVersion() async => RunResult.fromMap(
        Map<String, dynamic>.from(
            await _channel.invokeMapMethod<String, dynamic>('prootVersion') ?? {}),
      );

  /// Downloads, checks and unpacks the Linux base system. Can take minutes.
  Future<RunResult> installRootfs({required String url, required String sha256}) async =>
      RunResult.fromMap(Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>(
                'installRootfs', {'url': url, 'sha256': sha256}) ??
            {},
      ));

  /// `uname -a` inside the Linux base system.
  Future<RunResult> runUname() async => RunResult.fromMap(
        Map<String, dynamic>.from(
            await _channel.invokeMapMethod<String, dynamic>('runUname') ?? {}),
      );
}
