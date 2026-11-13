import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'native_chat_page.dart';

/// Saves a provider's key and model inside Hermes (WBS 5.2). Returns null on success,
/// or a plain message for the player.
abstract class ProviderSaver {
  Future<String?> save({required String provider, required String key, required String model});
}

class MethodChannelProviderSaver implements ProviderSaver {
  MethodChannelProviderSaver([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(_name);

  static const _name = 'herald/engine';
  final MethodChannel _channel;

  @override
  Future<String?> save({required String provider, required String key, required String model}) async {
    final map = await _channel.invokeMapMethod<String, dynamic>('saveProvider', {
      'provider': provider,
      'key': key,
      'model': model,
    });
    if (map != null && map['ok'] == true) return null;
    return (map?['error'] as String?) ?? "Couldn't save. Try again.";
  }
}

/// The providers the first version supports, with a starting model each. The player can change the model.
class ProviderChoice {
  const ProviderChoice(this.id, this.label, this.defaultModel, this.keyHint);
  final String id;
  final String label;
  final String defaultModel;
  final String keyHint;

  static const all = [
    ProviderChoice('openrouter', 'OpenRouter', 'openrouter/auto', 'sk-or-…'),
    ProviderChoice('gemini', 'Google Gemini', 'gemini-2.5-flash', 'AI Studio key'),
    ProviderChoice('xai', 'xAI (Grok)', 'grok-4', 'xai-…'),
  ];
}

class ProviderPage extends StatefulWidget {
  const ProviderPage({super.key, this.saver});

  /// Saves the key. Defaults to the real channel; tests pass a fake.
  final ProviderSaver? saver;

  @override
  State<ProviderPage> createState() => _ProviderPageState();
}

class _ProviderPageState extends State<ProviderPage> {
  late final ProviderSaver _saver = widget.saver ?? MethodChannelProviderSaver();
  final _key = TextEditingController();
  final _model = TextEditingController(text: ProviderChoice.all.first.defaultModel);

  ProviderChoice _choice = ProviderChoice.all.first;
  bool _saving = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  void _pick(ProviderChoice choice) {
    setState(() {
      _choice = choice;
      _model.text = choice.defaultModel;
      _message = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });
    final problem = await _saver.save(
      provider: _choice.id,
      key: _key.text.trim(),
      model: _model.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _ok = problem == null;
      _message = problem ?? 'Saved. Hermes will use ${_choice.label} with ${_model.text.trim()}.';
      if (problem == null) _key.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatLook.bg,
      appBar: AppBar(
        backgroundColor: ChatLook.bg,
        foregroundColor: ChatLook.text,
        title: const Text('AI provider'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pick the provider and paste its key. Hermes answers with that provider.',
              style: TextStyle(color: ChatLook.text, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ProviderChoice.all)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: c.id == _choice.id,
                    onSelected: _saving ? null : (_) => _pick(c),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _key,
              enabled: !_saving,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: ChatLook.text),
              decoration: InputDecoration(
                labelText: 'API key',
                hintText: _choice.keyHint,
                labelStyle: const TextStyle(color: ChatLook.muted),
                hintStyle: const TextStyle(color: ChatLook.muted),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _model,
              enabled: !_saving,
              autocorrect: false,
              style: const TextStyle(color: ChatLook.text),
              decoration: const InputDecoration(
                labelText: 'Model',
                labelStyle: TextStyle(color: ChatLook.muted),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: _ok ? ChatLook.text : ChatLook.problem, height: 1.4),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Your key is kept only on this phone, in Hermes\'s settings file. '
              'Herald does not send it anywhere; Hermes sends it to the provider you picked.',
              style: TextStyle(color: ChatLook.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
