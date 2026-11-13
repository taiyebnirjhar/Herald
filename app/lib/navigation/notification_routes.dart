import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat/native_chat_page.dart';
import '../jobs/jobs_page.dart';
import '../runtime/runtime_channel.dart';
import '../setup/setup_page.dart';

/// The channel on which Android says which screen a notification asked for.
const String navigationChannelName = 'herald/navigation';

/// The screens a notification can open. The names match Routes.kt on the Android side.
enum NotificationRoute {
  /// The Linux base and Hermes install screen.
  setup('setup'),

  /// The scheduled jobs list.
  jobs('jobs'),

  /// The native chat with Hermes.
  chat('chat');

  const NotificationRoute(this.wireName);

  /// The name Android sends for this route.
  final String wireName;

  /// The route for [value], or null when [value] is missing or not a known name.
  static NotificationRoute? parse(Object? value) {
    if (value is! String) return null;
    for (final route in values) {
      if (route.wireName == value) return route;
    }
    return null;
  }
}

/// The page that [route] opens.
Widget pageForRoute(NotificationRoute route) {
  return switch (route) {
    NotificationRoute.setup => SetupPage(runtime: RuntimeChannel()),
    NotificationRoute.jobs => const JobsPage(),
    NotificationRoute.chat => NativeChatPage(
      startHermes: RuntimeChannel().startHermes,
    ),
  };
}

/// Pushes the page for [route] on [navigator]. Does nothing when there is no navigator yet.
void openNotificationRoute(NavigatorState? navigator, NotificationRoute route) {
  navigator?.push(MaterialPageRoute<void>(builder: (_) => pageForRoute(route)));
}

/// Hears which screen a notification asked for and passes it to [onRoute].
///
/// On [start] it asks Android once for the route the app was opened with. After that
/// it listens for "route" calls, which Android sends when a notification is tapped
/// while the app is already open.
class NotificationRouter {
  NotificationRouter({required this.onRoute, MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(navigationChannelName);

  /// Called with each route. Unknown route names are ignored.
  final ValueChanged<NotificationRoute> onRoute;

  final MethodChannel _channel;
  bool _started = false;

  /// Starts once. Later calls do nothing.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    _channel.setMethodCallHandler(_onCall);
    final initial = await _askInitialRoute();
    if (initial != null) onRoute(initial);
  }

  Future<NotificationRoute?> _askInitialRoute() async {
    try {
      final value = await _channel.invokeMethod<String>('initialRoute');
      return NotificationRoute.parse(value);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> _onCall(MethodCall call) async {
    if (call.method != 'route') return;
    final route = NotificationRoute.parse(call.arguments);
    if (route != null) onRoute(route);
  }
}
