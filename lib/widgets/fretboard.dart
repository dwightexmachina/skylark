import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/round.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';
import 'keyboard.dart' show keyboardLetters;

/// (string row from the top e..E, fret) for each semitone C4–C5, in second
/// position: C4–D♯4 on the A string, E4–G♯4 on the D string, A4–C5 on the
/// G string. Written pitch — on a real guitar these sound an octave lower,
/// but Skylark's audio is identical to piano mode.
const List<(int, int)> _positionII = [
  (4, 3), (4, 4), (4, 5), (4, 6), // C4 C#4 D4 D#4
  (3, 2), (3, 3), (3, 4), (3, 5), (3, 6), // E4 F4 F#4 G4 G#4
  (2, 2), (2, 3), (2, 4), (2, 5), // A4 A#4 B4 C5
];

const _openLabels = ['e', 'B', 'G', 'D', 'A', 'E'];
const _nFrets = 7;
const double _labelW = 28; // open-string letters at the left
const double _boardTop = 24;
const double _stringGap = 30;
const double _boardPad = 14; // wood beyond the outer strings
const double _markerSize = 32;

double get _boardBottom => _boardTop + 5 * _stringGap;

/// Guitar fingerboard: the same thirteen notes as the piano, marked in
/// second position. Markers mirror the piano keys' states — disabled,
/// held, and verdict flashes.
class FretboardView extends StatelessWidget {
  final GameController controller;

  const FretboardView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      const minW = 620.0;
      final fits = constraints.maxWidth.isFinite && constraints.maxWidth >= minW;
      final w = fits ? constraints.maxWidth : minW;
      final board = SizedBox(
        width: w,
        height: _boardBottom + 66,
        child: _board(p, w),
      );
      if (fits) return board;
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal, child: board),
      );
    });
  }

  /// Fret wire x-positions: nut first, then frets shrinking like a real neck.
  static List<double> fretXs(double width) {
    const nutX = _labelW + 12;
    const shrink = 0.93;
    var sum = 0.0, f = 1.0;
    for (var i = 0; i < _nFrets; i++) {
      sum += f;
      f *= shrink;
    }
    final unit = (width - 6 - nutX) / sum;
    final xs = [nutX];
    var fretW = unit;
    for (var i = 1; i <= _nFrets; i++) {
      xs.add(xs[i - 1] + fretW);
      fretW *= shrink;
    }
    return xs;
  }

  Widget _board(Palette p, double w) {
    final c = controller;
    final xs = fretXs(w);
    double cellX(int fret) => (xs[fret - 1] + xs[fret]) / 2;
    double stringY(int row) => _boardTop + row * _stringGap;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _BoardPainter(p))),
        for (var s = 0; s < semitoneCount; s++)
          Positioned(
            left: cellX(_positionII[s].$2) - _markerSize / 2,
            top: stringY(_positionII[s].$1) - _markerSize / 2,
            width: _markerSize,
            height: _markerSize,
            child: _marker(p, c, s),
          ),
      ],
    );
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

  Widget _marker(Palette p, GameController c, int semitone) {
    final enabled = c.settings.noteSet.contains(semitone);
    final held = c.heldSemitones.contains(semitone);
    final flash = _flashColor(p, semitone);
    final sharp = Pitch(semitone).isBlack;

    Color bg = sharp
        ? (enabled ? p.keyBlack : p.keyBlackDisabled)
        : (enabled ? p.keyWhite : p.keyDisabled);
    Color fg = sharp
        ? (enabled ? const Color(0xFFDCEBF7) : p.keyDisabled)
        : (enabled ? p.muted : p.keyBlackDisabled);
    Color edge = sharp ? Colors.transparent : p.keyWhiteEdge;
    Color shadow = sharp ? p.keyBlackShadow : p.btnShadow;
    if (flash != null) {
      bg = Color.lerp(sharp ? p.keyBlack : p.keyWhite, flash, sharp ? 0.55 : 0.35)!;
      fg = sharp ? const Color(0xFFDCEBF7) : flash;
      edge = flash;
      shadow = flash;
    } else if (held) {
      bg = sharp ? Color.lerp(p.keyBlack, p.accent, 0.55)! : p.keyHeld;
      fg = sharp ? const Color(0xFFDCEBF7) : p.keyHeldText;
      edge = p.accent;
      shadow = p.accentShadow;
    }

    return Listener(
      onPointerDown: enabled ? (_) => c.noteOn(semitone) : null,
      onPointerUp: (_) => c.noteOff(semitone),
      onPointerCancel: (_) => c.noteOff(semitone),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: edge, width: 2),
            boxShadow: enabled
                ? [BoxShadow(color: shadow, offset: const Offset(0, 3))]
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                Pitch(semitone).label,
                style: TextStyle(
                    fontSize: 9.5, fontWeight: FontWeight.w800, color: fg,
                    height: 1.1),
              ),
              Text(
                keyboardLetters[semitone],
                style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    color: fg.withValues(alpha: 0.75),
                    height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BoardPainter extends CustomPainter {
  final Palette p;
  _BoardPainter(this.p);

  void _text(Canvas canvas, String s, Offset center, double fontSize,
      Color color,
      {FontWeight weight = FontWeight.w700, double letterSpacing = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontWeight: weight,
            letterSpacing: letterSpacing),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final xs = FretboardView.fretXs(size.width);
    double cellX(int fret) => (xs[fret - 1] + xs[fret]) / 2;
    double stringY(int row) => _boardTop + row * _stringGap;
    final nutX = xs[0], right = xs[_nFrets];
    final woodTop = _boardTop - _boardPad;
    final woodBottom = _boardBottom + _boardPad;

    // Fingerboard wood.
    canvas.drawRRect(
      RRect.fromLTRBR(
          nutX, woodTop, right, woodBottom, const Radius.circular(6)),
      Paint()..color = p.soft,
    );

    // Inlay dots at frets 3, 5, 7.
    final inlay = Paint()..color = p.line;
    for (final f in [3, 5, 7]) {
      canvas.drawCircle(
          Offset(cellX(f), (_boardTop + _boardBottom) / 2), 6, inlay);
    }

    // Nut and fret wires.
    canvas.drawRRect(
      RRect.fromLTRBR(nutX - 5, woodTop, nutX + 2, woodBottom,
          const Radius.circular(2)),
      Paint()..color = p.staffInk.withValues(alpha: 0.65),
    );
    final wire = Paint()..color = p.keyWhiteEdge;
    for (var f = 1; f <= _nFrets; f++) {
      canvas.drawRRect(
        RRect.fromLTRBR(xs[f] - 1.4, woodTop, xs[f] + 1.4, woodBottom,
            const Radius.circular(1.4)),
        wire,
      );
    }

    // Strings (gauge thickens toward low E) and open-string labels.
    for (var i = 0; i < 6; i++) {
      final gauge = 1.2 + i * 0.45;
      canvas.drawRect(
        Rect.fromLTWH(nutX - 5, stringY(i) - gauge / 2, right - nutX + 5, gauge),
        Paint()..color = p.staffInk.withValues(alpha: 0.75),
      );
      _text(canvas, _openLabels[i], Offset(_labelW / 2, stringY(i)), 12.5,
          p.muted);
    }

    // Fret numbers and the second-position bracket.
    for (var f = 1; f <= _nFrets; f++) {
      _text(canvas, '$f', Offset(cellX(f), _boardBottom + _boardPad + 13), 11.5,
          p.muted);
    }
    final bracketY = _boardBottom + _boardPad + 27;
    canvas.drawLine(
      Offset(xs[1] + 5, bracketY),
      Offset(xs[6] - 5, bracketY),
      Paint()
        ..color = p.tonicSoft
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    _text(canvas, 'SECOND POSITION',
        Offset((xs[1] + xs[6]) / 2, bracketY + 12), 9.5, p.tonic,
        letterSpacing: 0.8);
  }

  @override
  bool shouldRepaint(_BoardPainter old) => old.p != p;
}
