import 'package:flutter/services.dart';

/// What proot's check returned.
class ProotCheck {
  const ProotCheck({required this.ok, required this.output, this.error, this.exitCode});
  final bool ok;
  final String output;
  final String? error;
  final int? exitCode;
}

/// The Linux runtime pieces, as the Android side reports them (WBS 1.2).
class RuntimeChannel {
  RuntimeChannel([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/runtime';
  final MethodChannel _channel;

  Future<Map<String, dynamic>> describe() async =>
      Map<String, dynamic>.from(await _channel.invokeMapMethod<String, dynamic>('describe') ?? {});

  Future<ProotCheck> prootVersion() async {
    final map = Map<String, dynamic>.from(
        await _channel.invokeMapMethod<String, dynamic>('prootVersion') ?? {});
    return ProotCheck(
      ok: map['ok'] == true,
      output: map['output'] as String? ?? '',
      error: map['error'] as String?,
      exitCode: map['exitCode'] as int?,
    );
  }
}
