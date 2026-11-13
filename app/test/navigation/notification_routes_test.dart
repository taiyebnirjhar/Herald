import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herald/chat/native_chat_page.dart';
import 'package:herald/jobs/jobs_page.dart';
import 'package:herald/navigation/notification_routes.dart';
import 'package:herald/setup/setup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(navigationChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    channel.setMethodCallHandler(null);
  });

  /// Plays a call that Android would send to Dart on the navigation channel.
  Future<void> fromAndroid(String method, Object? arguments) async {
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  group('NotificationRoute.parse', () {
    test('each known name gives its route', () {
      expect(NotificationRoute.parse('setup'), NotificationRoute.setup);
      expect(NotificationRoute.parse('jobs'), NotificationRoute.jobs);
      expect(NotificationRoute.parse('chat'), NotificationRoute.chat);
    });

    test('an unknown name gives null', () {
      expect(NotificationRoute.parse('settings'), isNull);
      expect(NotificationRoute.parse(''), isNull);
    });

    test('names are exact: a different case gives null', () {
      expect(NotificationRoute.parse('Jobs'), isNull);
      expect(NotificationRoute.parse('CHAT'), isNull);
    });

    test('a missing or non-text value gives null', () {
      expect(NotificationRoute.parse(null), isNull);
      expect(NotificationRoute.parse(42), isNull);
    });

    test('every route has a name that parses back to itself', () {
      for (final route in NotificationRoute.values) {
        expect(NotificationRoute.parse(route.wireName), route);
      }
    });
  });

  group('pageForRoute', () {
    test('setup opens the Linux and Hermes setup screen', () {
      expect(pageForRoute(NotificationRoute.setup), isA<SetupPage>());
    });

    test('jobs opens the scheduled jobs list', () {
      expect(pageForRoute(NotificationRoute.jobs), isA<JobsPage>());
    });

    test('chat opens the native chat', () {
      expect(pageForRoute(NotificationRoute.chat), isA<NativeChatPage>());
    });
  });

  group('openNotificationRoute', () {
    test('does nothing when there is no navigator yet', () {
      expect(
        () => openNotificationRoute(null, NotificationRoute.jobs),
        returnsNormally,
      );
    });
  });

  group('NotificationRouter', () {
    test(
      'the route Android was opened with is passed on once at start',
      () async {
        var asked = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'initialRoute');
          asked++;
          return 'jobs';
        });
        final opened = <NotificationRoute>[];
        final router = NotificationRouter(onRoute: opened.add);

        await router.start();
        await router.start();

        expect(opened, [NotificationRoute.jobs]);
        expect(asked, 1, reason: 'the initial route is asked for once');
      },
    );

    test('no initial route means nothing is opened', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final opened = <NotificationRoute>[];
      await NotificationRouter(onRoute: opened.add).start();
      expect(opened, isEmpty);
    });

    test('an unknown initial route is ignored', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => 'nowhere');
      final opened = <NotificationRoute>[];
      await NotificationRouter(onRoute: opened.add).start();
      expect(opened, isEmpty);
    });

    test('a channel error while asking gives no route and no crash', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'boom'),
      );
      final opened = <NotificationRoute>[];
      await NotificationRouter(onRoute: opened.add).start();
      expect(opened, isEmpty);
    });

    test('a missing native side gives no route and no crash', () async {
      final opened = <NotificationRoute>[];
      await NotificationRouter(onRoute: opened.add).start();
      expect(opened, isEmpty);
    });

    test('a route sent while the app is open is passed on', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final opened = <NotificationRoute>[];
      final router = NotificationRouter(onRoute: opened.add);
      await router.start();

      await fromAndroid('route', 'chat');
      await fromAndroid('route', 'setup');

      expect(opened, [NotificationRoute.chat, NotificationRoute.setup]);
    });

    test('an unknown route sent while open is ignored', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final opened = <NotificationRoute>[];
      await NotificationRouter(onRoute: opened.add).start();

      await fromAndroid('route', 'settings');
      await fromAndroid('route', null);

      expect(opened, isEmpty);
    });

    test('other calls on the channel are not treated as routes', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      final opened = <NotificationRoute>[];
      await NotificationRouter(onRoute: opened.add).start();

      await fromAndroid('something-else', 'jobs');

      expect(opened, isEmpty);
    });
  });
}
