import 'package:flutter/services.dart';

/// Where the Hermes API server listens on this phone, and the key it asks for.
class EngineAddress {
  const EngineAddress({required this.port, required this.key});
  final int port;
  final String key;
}

/// What the native chat needs from Android (WBS 6.2). Kotlin keeps the key.
abstract class EngineConnection {
  Future<EngineAddress> address();
}

/// The real one, over a MethodChannel to `EngineChannel.kt`.
class MethodChannelEngineConnection implements EngineConnection {
  MethodChannelEngineConnection([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/engine';
  final MethodChannel _channel;

  @override
  Future<EngineAddress> address() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('connection');
    if (map == null) throw StateError('No connection details from Android');
    return EngineAddress(
      port: map['port'] as int,
      key: map['key'] as String,
    );
  }
}
