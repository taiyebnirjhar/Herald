import 'package:flutter/material.dart';

import 'update_controller.dart';

/// The version and update card on the Hello screen. Shows the step the update
/// is at, with one main button for the next step.
class UpdateStatusCard extends StatelessWidget {
  const UpdateStatusCard({super.key, required this.controller});

  final UpdateController controller;

  static const _ink = Color(0xFF17151F);
  static const _muted = Color(0xFF7A7785);
  static const _accent = Color(0xFF8B4DFF);
  static const _danger = Color(0xFFB3261E);

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Herald ${c.installedName}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _message(c),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: c.step == UpdateStep.failed ? _danger : _muted,
            ),
          ),
          if (c.step == UpdateStep.downloading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: c.progress,
                minHeight: 8,
                color: _accent,
                backgroundColor: const Color(0xFFE9E3FF),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD9CCFF),
                disabledForegroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _onPressed(c),
              child: Text(_buttonText(c)),
            ),
          ),
        ],
      ),
    );
  }

  String _message(UpdateController c) {
    switch (c.step) {
      case UpdateStep.idle:
      case UpdateStep.checking:
        return 'Checking for updates…';
      case UpdateStep.upToDate:
        return 'You have the newest version.';
      case UpdateStep.available:
        final u = c.update!;
        return 'Version ${u.version} is ready.'
            '${u.notes.isEmpty ? '' : '\n\n${u.notes}'}\n\nYour data stays.';
      case UpdateStep.downloading:
        return 'Downloading ${c.update!.version}… ${(c.progress * 100).round()}%';
      case UpdateStep.readyToInstall:
      case UpdateStep.installing:
        return "Android's installer is open. Tap Install there.";
      case UpdateStep.needsPermission:
        return 'One time only: turn on "Allow from this source" for Herald, '
            'then come back and tap the button.';
      case UpdateStep.failed:
        return c.message ?? 'Something went wrong. Try again.';
    }
  }

  String _buttonText(UpdateController c) {
    switch (c.step) {
      case UpdateStep.available:
        return 'Update now';
      case UpdateStep.downloading:
        return 'Downloading…';
      case UpdateStep.readyToInstall:
      case UpdateStep.installing:
        return 'Open installer again';
      case UpdateStep.needsPermission:
        return 'Allow and install';
      case UpdateStep.failed:
        return c.update != null ? 'Try again' : 'Check again';
      case UpdateStep.idle:
      case UpdateStep.checking:
      case UpdateStep.upToDate:
        return 'Check for updates';
    }
  }

  VoidCallback? _onPressed(UpdateController c) {
    if (c.busy || c.step == UpdateStep.checking) return null;
    switch (c.step) {
      case UpdateStep.available:
        return c.downloadAndInstall;
      case UpdateStep.readyToInstall:
      case UpdateStep.installing:
      case UpdateStep.needsPermission:
        return c.install;
      case UpdateStep.failed:
        return c.update != null ? c.downloadAndInstall : c.checkForUpdate;
      case UpdateStep.idle:
      case UpdateStep.upToDate:
        return c.checkForUpdate;
      case UpdateStep.checking:
      case UpdateStep.downloading:
        return null;
    }
  }
}
