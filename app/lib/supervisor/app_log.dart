/// The app's log (WBS 4.7): the last lines only, with secrets removed before
/// anything is shown or shared. Keys, tokens and passwords never leave the phone
/// through this log.
class AppLog {
  AppLog({this.maxLines = 500});

  final int maxLines;
  final List<String> _lines = [];

  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.add(redact(line));
    if (_lines.length > maxLines) {
      _lines.removeRange(0, _lines.length - maxLines);
    }
  }

  String text() => _lines.join('\n');

  static final _patterns = <(RegExp, String)>[
    (RegExp(r'sk-[A-Za-z0-9_\-]{8,}'), 'sk-[redacted]'),
    (RegExp(r'gh[pousr]_[A-Za-z0-9]{20,}'), '[redacted]'),
    (RegExp(r'Bearer\s+[A-Za-z0-9._\-]+', caseSensitive: false), 'Bearer [redacted]'),
    (
      RegExp(r'(api[_\-]?key|token|secret|password)(\s*[:=]\s*)\S+', caseSensitive: false),
      r'$1$2[redacted]',
    ),
  ];

  /// [text] with keys, tokens and passwords replaced by [redacted].
  static String redact(String text) {
    var out = text;
    for (final (pattern, replacement) in _patterns) {
      out = out.replaceAll(pattern, replacement);
    }
    return out;
  }
}
