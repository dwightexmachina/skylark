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
      return SizedBox(
        height: 172,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              top: 8,
              child: Row(
                children: [
                  for (final s in _whiteSemitones)
                    Expanded(child: _whiteKey(p, c, s)),
                ],
              ),
            ),
            for (final (semitone, n) in _blackKeys)
              Positioned(
                left: w * (n / 7) - w * 0.045,
                top: 0,
                width: w * 0.09,
                height: 96,
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
    Color shadow = p.btnShadow;
    var shadowed = enabled;
    if (flash != null) {
      bg = Color.lerp(p.keyWhite, flash, 0.35)!;
      fg = flash;
      edge = flash;
      shadow = flash;
    } else if (held) {
      bg = p.keyHeld;
      fg = p.keyHeldText;
      edge = p.accent;
      shadow = p.accentShadow;
    }

    return Listener(
      onPointerDown: enabled ? (_) => c.noteOn(semitone) : null,
      onPointerUp: (_) => c.noteOff(semitone),
      onPointerCancel: (_) => c.noteOff(semitone),
      child: MouseRegion(
        cursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: edge, width: 2.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: shadowed
                ? [BoxShadow(color: shadow, offset: const Offset(0, 4))]
                : null,
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Pitch(semitone).label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: enabled ? fg.withValues(alpha: 0.5) : fg,
                      width: 1.5),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  keyboardLetters[semitone],
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blackKey(Palette p, GameController c, int semitone) {
    final enabled = c.settings.noteSet.contains(semitone);
    final held = c.heldSemitones.contains(semitone);
    final flash = _flashColor(p, semitone);

    Color bg = enabled ? p.keyBlack : p.keyBlackDisabled;
    Color fg = enabled ? const Color(0xFFDCEBF7) : p.keyDisabled;
    Color shadow = p.keyBlackShadow;
    if (flash != null) {
      bg = Color.lerp(p.keyBlack, flash, 0.55)!;
      shadow = flash;
    } else if (held) {
      bg = Color.lerp(p.keyBlack, p.accent, 0.55)!;
      shadow = p.accentShadow;
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
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            boxShadow: enabled
                ? [BoxShadow(color: shadow, offset: const Offset(0, 4))]
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
                    fontSize: 11, fontWeight: FontWeight.w700, color: fg),
              ),
              Text(
                keyboardLetters[semitone],
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: fg.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
