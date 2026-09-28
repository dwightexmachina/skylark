import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/tutorial_controller.dart';
import '../ui/palette.dart';
import 'cloud_card.dart';

/// One popup's content and where it points.
class _StepConfig {
  final GlobalKey? anchor; // null = centered modal, full scrim
  final String title;
  final String body;
  final String? primaryLabel; // null = no button (the anchor itself advances)
  final String? secondaryLabel; // "skip" style button (welcome only)

  const _StepConfig({
    this.anchor,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.secondaryLabel,
  });
}

/// Full-screen layer: dim scrim with a cutout over the anchored element
/// (which stays clickable), plus a hovering cumulus-cloud card with a
/// thought-bubble puff trail pointing at the spotlight.
class TutorialOverlay extends StatefulWidget {
  final TutorialController tut;
  final GlobalKey rootKey;
  final GlobalKey keyboardKey;
  final GlobalKey playKey;
  final GlobalKey scoreKey;
  final GlobalKey settingsKey;
  final Listenable repaint; // scroll/resize ticks

  const TutorialOverlay({
    super.key,
    required this.tut,
    required this.rootKey,
    required this.keyboardKey,
    required this.playKey,
    required this.scoreKey,
    required this.settingsKey,
    required this.repaint,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final Listenable _merged =
      Listenable.merge([widget.tut, widget.repaint]);
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat();

  @override
  void initState() {
    super.initState();
    _merged.addListener(_bump);
  }

  @override
  void dispose() {
    _merged.removeListener(_bump);
    _bob.dispose();
    super.dispose();
  }

  void _bump() {
    if (mounted) setState(() {});
  }

  _StepConfig? _config() {
    final w = widget;
    return switch (w.tut.stage) {
      TutStage.welcome => const _StepConfig(
          title: 'Train your ear.',
          body:
              'Skylark plays you a short melody, then you play it back from memory. Ready to try your first round?',
          primaryLabel: 'Start the tour',
          secondaryLabel: 'Skip — I’ll figure it out',
        ),
      TutStage.keyboard => _StepConfig(
          anchor: w.keyboardKey,
          title: 'This is your instrument.',
          body:
              'Click the keys, or use your computer keyboard — each key shows its shortcut letter. Try playing a note or two right now.',
          primaryLabel: 'Next',
        ),
      TutStage.pressPlay => _StepConfig(
          anchor: w.playKey,
          title: 'A round has two halves: listen, then play back.',
          body:
              'Press Play round to begin. You’ll hear a home note (the tonic), a 4-beat count-in, then the melody.',
        ),
      TutStage.listen => _StepConfig(
          anchor: w.scoreKey,
          title: 'Just listen.',
          body:
              'The staff stays blank on purpose — this is dictation, by ear only. Follow the beat lamps; the melody starts on the downbeat.',
          primaryLabel: 'Got it',
        ),
      TutStage.turn => _StepConfig(
          anchor: w.keyboardKey,
          title: 'Your turn is coming.',
          body:
              'After this count-in, play the melody back in time with the clicks. One note per beat — this round is all quarter notes.',
          primaryLabel: 'I’m ready',
        ),
      TutStage.summaryStep => _StepConfig(
          anchor: w.scoreKey,
          title: 'Green: right note, on the beat. Amber: right note, off the beat. Red: wrong or missed.',
          body:
              'Press Replay melody to study this round, or Next round to keep going. That’s the whole game — good luck!',
          primaryLabel: 'Finish tour',
        ),
      TutStage.freeTip => _StepConfig(
          anchor: w.scoreKey,
          title: 'Free play: no judging here.',
          body:
              'The staff just echoes whatever you play. Warm up, noodle, or practice with the metronome.',
          primaryLabel: 'Got it',
        ),
      TutStage.settingsTip => _StepConfig(
          anchor: w.settingsKey,
          title: 'Feeling comfortable?',
          body:
              'Raise the difficulty, add more notes, or lengthen the round here. Settings apply to the next round.',
          primaryLabel: 'Got it',
        ),
      _ => null,
    };
  }

  Rect? _rectFor(GlobalKey key) {
    final ctx = key.currentContext;
    final rootCtx = widget.rootKey.currentContext;
    if (ctx == null || rootCtx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    final rootBox = rootCtx.findRenderObject() as RenderBox?;
    if (box == null || rootBox == null || !box.attached || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero, ancestor: rootBox) & box.size;
  }

  /// Ease-in-out oscillation, 0→1→0 over one cycle, optionally phase-shifted.
  double _wave(double phase) {
    final t = (_bob.value - phase) % 1.0;
    return 0.5 - 0.5 * math.cos(2 * math.pi * t);
  }

  Widget _hover(Widget child,
      {double amplitude = 7, double tilt = 0.010, double phase = 0}) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) return child;
    return AnimatedBuilder(
      animation: _bob,
      builder: (context, c) {
        final w = _wave(phase);
        return Transform(
          transform: Matrix4.translationValues(0, -amplitude * w, 0)
            ..rotateZ(-tilt * w),
          alignment: Alignment.center,
          child: c,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config();
    if (cfg == null || !widget.tut.popupVisible) {
      return const SizedBox.shrink();
    }
    final p = Palette.of(context);
    final scrim = p.isNight
        ? const Color(0xFF06091C).withValues(alpha: 0.6)
        : const Color(0xFF1E325A).withValues(alpha: 0.45);

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;

      Rect? cut;
      if (cfg.anchor != null) {
        final r = _rectFor(cfg.anchor!);
        if (r == null) {
          // Not laid out yet — try again next frame.
          WidgetsBinding.instance.addPostFrameCallback((_) => _bump());
        } else {
          cut = r.inflate(6).intersect(Offset.zero & Size(w, h));
        }
      }

      final card = _hover(_card(p, cfg));

      if (cut == null) {
        // Centered modal over a full scrim.
        return Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: ColoredBox(color: scrim),
            ),
          ),
          Center(child: card),
        ]);
      }

      // Four scrim panels around the cutout: the hole itself has no widget,
      // so the anchored element underneath stays fully interactive.
      Widget block(Rect r) => Positioned.fromRect(
            rect: r,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: ColoredBox(color: scrim),
            ),
          );

      final below = cut.center.dy < h * 0.55;
      const cardW = 350.0;
      const cardEst = 230.0; // keep at least this much room for the card
      final cardLeft =
          (cut.center.dx - cardW / 2).clamp(16.0, (w - cardW - 16).clamp(16.0, w));
      final puffX = cut.center.dx.clamp(cardLeft + 36, cardLeft + cardW - 36);
      // Tall anchors (e.g. the settings sidebar) can push the card off-screen;
      // clamp so it stays visible, overlapping the spotlight if it must.
      double? cardTop = below ? cut.bottom + 40 : null;
      double? cardBottom = below ? null : h - cut.top + 34;
      if (cardTop != null && cardTop > h - cardEst) {
        cardTop = (h - cardEst).clamp(16.0, h);
      }
      if (cardBottom != null && cardBottom > h - cardEst) {
        cardBottom = (h - cardEst).clamp(16.0, h);
      }

      Widget puff(double size, double x, double? top, double? bottom,
          double phase) {
        return Positioned(
          left: x - size / 2,
          top: top,
          bottom: bottom,
          child: IgnorePointer(
            child: _hover(
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: p.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: p.cardShadow, offset: const Offset(0, 4)),
                  ],
                ),
              ),
              amplitude: 4,
              tilt: 0,
              phase: phase,
            ),
          ),
        );
      }

      return Stack(children: [
        block(Rect.fromLTRB(0, 0, w, cut.top)),
        block(Rect.fromLTRB(0, cut.bottom, w, h)),
        block(Rect.fromLTRB(0, cut.top, cut.left, cut.bottom)),
        block(Rect.fromLTRB(cut.right, cut.top, w, cut.bottom)),
        // Accent outline around the spotlit element.
        Positioned.fromRect(
          rect: cut,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: p.accent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        // Thought-bubble puff trail between spotlight and cloud.
        if (below) ...[
          puff(14, puffX + 10, cut.bottom + 6, null, 0.16),
          puff(22, puffX - 6, cut.bottom + 20, null, 0.08),
        ] else ...[
          puff(14, puffX + 10, null, h - cut.top + 4, 0.16),
          puff(22, puffX - 6, null, h - cut.top + 16, 0.08),
        ],
        // The hovering cloud card.
        Positioned(
          left: cardLeft,
          width: cardW,
          top: cardTop,
          bottom: cardBottom,
          child: card,
        ),
      ]);
    });
  }

  Widget _card(Palette p, _StepConfig cfg) {
    final tut = widget.tut;
    return Material(
      color: Colors.transparent,
      child: CustomPaint(
        painter: CloudCardPainter(fill: p.surface, shadow: p.cardShadow),
        child: Container(
          width: 350,
          padding: const EdgeInsets.fromLTRB(
              26, CloudCardPainter.bandVisible + 16, 26, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(cfg.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: p.ink)),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: tut.skip,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text('✕',
                          style: TextStyle(fontSize: 14, color: p.muted)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(cfg.body,
                  style:
                      TextStyle(fontSize: 13, height: 1.45, color: p.muted)),
              if (cfg.primaryLabel != null || cfg.secondaryLabel != null) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (cfg.secondaryLabel != null) ...[
                      _btn(p, cfg.secondaryLabel!, primary: false,
                          onTap: tut.skip),
                      const SizedBox(width: 8),
                    ],
                    if (cfg.primaryLabel != null)
                      _btn(p, cfg.primaryLabel!,
                          primary: true, onTap: tut.next),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text('Waiting for you…',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: p.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(Palette p, String label,
      {required bool primary, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: primary ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
                color: primary ? p.accentShadow : p.btnShadow,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: primary ? p.onAccent : p.muted)),
      ),
    );
  }
}
