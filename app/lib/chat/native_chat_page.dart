import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'engine_connection.dart';
import 'hermes_api.dart';

/// Colours for the native chat: dark, quiet, one accent (Grok/Muse style).
class ChatLook {
  const ChatLook._();
  static const bg = Color(0xFF0B0B0F);
  static const surface = Color(0xFF17171D);
  static const bubble = Color(0xFF26262E);
  static const border = Color(0xFF2A2A33);
  static const text = Color(0xFFF2F2F7);
  static const muted = Color(0xFF8E8E9A);
  static const accent = Color(0xFF8B4DFF);
  static const problem = Color(0xFFFF8A8A);
}

enum _Status { checking, ready, notRunning, failed }

class _Line {
  _Line({required this.fromUser, this.text = ''});
  final bool fromUser;
  String text;
  bool failed = false;
}

/// The native chat (WBS 6.2): a Grok/Muse-style screen over Hermes's API server.
/// Replies stream in as Hermes writes them. Nothing is saved on the phone yet.
class NativeChatPage extends StatefulWidget {
  const NativeChatPage({
    super.key,
    this.connection,
    this.createApi,
    this.startHermes,
  });

  /// Where the server is and its key. Defaults to the real channel; tests pass a fake.
  final EngineConnection? connection;

  /// Builds the client from the address. Tests pass one that uses a mock server.
  final HermesApi Function(EngineAddress address)? createApi;

  /// Starts Hermes when it is not running. Null hides the button.
  final Future<void> Function()? startHermes;

  @override
  State<NativeChatPage> createState() => _NativeChatPageState();
}

class _NativeChatPageState extends State<NativeChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _lines = <_Line>[];

  _Status _status = _Status.checking;
  String _problem = '';
  HermesApi? _api;
  StreamSubscription<String>? _reply;

  bool get _busy => _reply != null;

  static const _suggestions = [
    'Summarise a topic',
    'Plan my day',
    'Search the web',
    'Explain something simply',
  ];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _reply?.cancel();
    _input.dispose();
    _scroll.dispose();
    _api?.close();
    super.dispose();
  }

  HermesApi _defaultApi(EngineAddress a) => HermesApi(port: a.port, apiKey: a.key);

  /// Reads the address from Android and keeps one client for it. The key is empty until
  /// Android has seen Hermes answer, so nothing is sent to a port that is not confirmed.
  Future<(EngineAddress, HermesApi)> _readAddress() async {
    final address = await (widget.connection ?? MethodChannelEngineConnection()).address();
    var api = _api;
    if (api == null || api.port != address.port || api.apiKey != address.key) {
      api?.close();
      api = (widget.createApi ?? _defaultApi)(address);
      _api = api;
    }
    return (address, api);
  }

  /// True when Android says the key is ready and Hermes answers its health check.
  Future<bool> _probeReady() async {
    try {
      final pair = await _readAddress();
      return pair.$1.key.isNotEmpty && await pair.$2.isUp();
    } catch (_) {
      return false;
    }
  }

  Future<void> _connect() async {
    setState(() {
      _status = _Status.checking;
      _problem = '';
    });
    try {
      await _readAddress();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _Status.failed;
        _problem = "Herald couldn't read its connection details. Try again.";
      });
      return;
    }
    final up = await _probeReady();
    if (!mounted) return;
    setState(() => _status = up ? _Status.ready : _Status.notRunning);
  }

  Future<void> _startHermes() async {
    final start = widget.startHermes;
    if (start == null) return;
    setState(() => _status = _Status.checking);
    try {
      await start();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _Status.notRunning;
      });
      return;
    }
    // Give the server a little time to answer.
    for (var i = 0; i < 15 && mounted; i++) {
      if (await _probeReady()) break;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (!mounted) return;
    final up = await _probeReady();
    setState(() => _status = up ? _Status.ready : _Status.notRunning);
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _busy || _status != _Status.ready) return;
    final pair = await _readAddress();
    if (!mounted) return;
    if (pair.$1.key.isEmpty) {
      setState(() => _status = _Status.notRunning);
      return;
    }
    final api = pair.$2;
    _input.clear();

    final turns = [
      for (final line in _lines)
        if (!line.failed && line.text.isNotEmpty)
          ChatTurn(role: line.fromUser ? 'user' : 'assistant', content: line.text),
      ChatTurn(role: 'user', content: text),
    ];
    final reply = _Line(fromUser: false);
    setState(() {
      _lines.add(_Line(fromUser: true, text: text));
      _lines.add(reply);
    });
    _scrollToEnd();

    _reply = api.reply(turns).listen(
      (piece) {
        setState(() => reply.text += piece);
        _scrollToEnd();
      },
      onError: (Object error) {
        setState(() {
          reply.failed = true;
          reply.text = error.toString();
          _reply = null;
        });
      },
      onDone: () => setState(() => _reply = null),
    );
  }

  void _stop() {
    _reply?.cancel();
    setState(() => _reply = null);
  }

  void _retry() {
    if (_busy || _lines.length < 2) return;
    final question = _lines[_lines.length - 2];
    setState(() => _lines.removeRange(_lines.length - 2, _lines.length));
    _send(question.text);
  }

  void _newChat() {
    _stop();
    setState(_lines.clear);
  }

  void _scrollToEnd() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatLook.bg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (_status != _Status.ready) _statusBanner(),
            Expanded(child: _lines.isEmpty ? _greeting() : _thread()),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, color: ChatLook.text),
          ),
          const Expanded(
            child: Text(
              'Herald',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ChatLook.text),
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: _lines.isEmpty && !_busy ? null : _newChat,
            icon: const Icon(Icons.edit_outlined, color: ChatLook.text),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final (String text, Widget? action) = switch (_status) {
      _Status.checking => ('Starting Herald…', null),
      _Status.notRunning => (
          'Hermes is not running.',
          widget.startHermes == null
              ? null
              : FilledButton(
                  onPressed: _startHermes,
                  child: const Text('Start Hermes'),
                ),
        ),
      _Status.failed => (
          _problem,
          OutlinedButton(onPressed: _connect, child: const Text('Try again')),
        ),
      _Status.ready => ('', null),
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ChatLook.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatLook.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: ChatLook.text, height: 1.3)),
          ),
          if (action != null) ...[const SizedBox(width: 12), action],
        ],
      ),
    );
  }

  Widget _greeting() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What do you want to do?',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: ChatLook.text, height: 1.15),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in _suggestions)
                ActionChip(
                  label: Text(s),
                  labelStyle: const TextStyle(color: ChatLook.text),
                  backgroundColor: ChatLook.surface,
                  side: const BorderSide(color: ChatLook.border),
                  onPressed: () => setState(() => _input.text = s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _thread() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: _lines.length,
      itemBuilder: (context, i) {
        final line = _lines[i];
        if (line.fromUser) return _userBubble(line.text);
        return _assistantBlock(line, isLast: i == _lines.length - 1);
      },
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: ChatLook.bubble,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SelectableText(text, style: const TextStyle(color: ChatLook.text, height: 1.4)),
      ),
    );
  }

  Widget _assistantBlock(_Line line, {required bool isLast}) {
    final showRetry = line.failed && isLast && !_busy;
    final text = line.text.isEmpty && !line.failed ? '…' : line.text;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: TextStyle(
              color: line.failed ? ChatLook.problem : ChatLook.text,
              height: 1.45,
              fontSize: 16,
            ),
          ),
          if (showRetry)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _retry,
                child: const Text('Try again'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _composer() {
    final canSend = _status == _Status.ready;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
        decoration: BoxDecoration(
          color: ChatLook.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ChatLook.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                enabled: canSend,
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(color: ChatLook.text, fontSize: 16),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: canSend ? 'Ask Herald anything' : 'Hermes is not ready yet',
                  hintStyle: const TextStyle(color: ChatLook.muted),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 6),
            if (_busy)
              _circleButton(icon: Icons.stop_rounded, tooltip: 'Stop', onTap: _stop)
            else
              _circleButton(
                icon: Icons.arrow_upward_rounded,
                tooltip: 'Send',
                onTap: canSend ? _send : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required String tooltip, required VoidCallback? onTap}) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onTap == null ? ChatLook.border : ChatLook.accent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
