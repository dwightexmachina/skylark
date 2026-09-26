import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/round.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';

const _whiteSemitones = [0, 2, 4, 5, 7, 9, 11];
// Black keys sit at the boundary after white key n (1-indexed): C♯ after C, etc.
const _blackKeys = [(1, 1), (3, 2), (6, 4), (8, 5), (10, 6)];

/// Physical key for each semitone (piano-style DAW mapping).
const keyboardLetters = [
  'A', 'W', 'S', 'E', 'D', 'F', 'T', 'G', 'Y', 'H', 'U', 'J',
];

class KeyboardView extends StatelessWidget {
  final GameController controller;

  const KeyboardView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = controller;

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: p.keyBlack,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(8), bottom: Radius.circular(10)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                for (final s in _whiteSemitones)
                  Expanded(child: _whiteKey(p, c, s)),
              ],
            ),
            for (final (semitone, n) in _blackKeys)
              Positioned(
                left: (w - 8) * (n / 7) - (w - 8) * 0.043,
                top: 0,
                width: (w - 8) * 0.086,
                height: 116,
                child: _blackKey(p, c, semitone),
              ),
          ],
        ),
      );
    });
  }

  Color? _flashColor(Palette p, int semitone) {
    if (controller.flashSemitone != semitone) return null;
    return switch (controller.flashVerdict) {
      Verdict.good => p.good,
      Verdict.offTime => p.warn,
      Verdict.wrongPitch => p.bad,
      _ => null,
    };
  }

  Widget _whiteKey(Palette p, GameController c, int semitone) {
    final enabled = c.settings.noteSet.contains(semitone);
    final held = c.heldSemitones.contains(semitone);
    final flash = _flashColor(p, semitone);

    Color bg = enabled ? p.keyWhite : p.keyDisabled;
    Color fg = enabled ? p.muted : p.keyBlackDisabled;
    Color edge = p.keyWhiteEdge;
    if (flash != null) {
      bg = Color.lerp(p.keyWhite, flash, 0.35)!;
      fg = flash;
      edge = flash;
    } else if (held) {
      bg = p.accentSoft;
      fg = p.accent;
      edge = p.accent;
    }

    return Listener(
      onPointerDown: enabled ? (_) => c.noteOn(semitone) : null,
      onPointerUp: (_) => c.noteOff(semitone),
      onPointerCancel: (_) => c.noteOff(semitone),
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: edge),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(6)),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Pitch(semitone).label,
                style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                  color: fg,
                  fontWeight: (held || flash != null)
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              _letterBadge(p, semitone, enabled, fg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _letterBadge(Palette p, int semitone, bool enabled, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(
            color: enabled ? fg.withValues(alpha: 0.5) : fg),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keyboardLetters[semitone],
        style: TextStyle(
            fontSize: 10, fontFamily: 'monospace', color: fg),
      ),
    );
  }

  Widget _blackKey(Palette p, GameController c, int semitone) {
    final enabled = c.settings.noteSet.contains(semitone);
    final held = c.heldSemitones.contains(semitone);
    final flash = _flashColor(p, semitone);

    Color bg = enabled ? p.keyBlack : p.keyBlackDisabled;
    Color fg = enabled ? p.keyWhite : p.keyDisabled;
    if (flash != null) {
      bg = Color.lerp(p.keyBlack, flash, 0.55)!;
    } else if (held) {
      bg = Color.lerp(p.keyBlack, p.accent, 0.5)!;
      fg = p.keyWhite;
    }

    return Listener(
      onPointerDown: enabled ? (_) => c.noteOn(semitone) : null,
      onPointerUp: (_) => c.noteOff(semitone),
      onPointerCancel: (_) => c.noteOff(semitone),
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(5)),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                        color: Color(0x59000000),
                        offset: Offset(0, 3),
                        blurRadius: 6)
                  ]
                : null,
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pitchClassLabels[semitone],
                style: TextStyle(
                    fontSize: 11, fontFamily: 'monospace', color: fg),
              ),
              Text(
                keyboardLetters[semitone],
                style: TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    color: fg.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
