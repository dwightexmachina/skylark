import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/audio_engine.dart' show Tone;
import '../models/note.dart';
import '../models/round.dart';
import '../state/game_controller.dart';
import '../state/theme_controller.dart';
import '../state/tutorial_controller.dart';
import '../ui/palette.dart';
import 'fretboard.dart';
import 'keyboard.dart';
import 'lark.dart';
import 'result_pop.dart';
import 'round_log_pop.dart';
import 'settings_panel.dart';
import 'splash_screen.dart';
import 'staff.dart';
import 'tutorial_overlay.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController controller = GameController();
  late final TutorialController tutorial = TutorialController(controller);

  // Anchors for the tutorial spotlight.
  final GlobalKey _rootKey = GlobalKey();
  final GlobalKey _keyboardKey = GlobalKey();
  final GlobalKey _playKey = GlobalKey();
  final GlobalKey _scoreKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final ValueNotifier<int> _scrollTick = ValueNotifier(0);

  bool _splashVisible = true;
  bool _logVisible = false;
  final GlobalKey<SplashScreenState> _splashKey = GlobalKey();

  /// Timeline attempt whose result pop was dismissed (-1 = none).
  /// [GameController.attempt] increments on every start (incl. replays),
  /// so each attempt gets exactly one pop.
  int _popDismissedForAttempt = -1;

  bool get _resultPopVisible {
    final c = controller;
    return c.phase == Phase.summary &&
        !c.freePlay &&
        !c.lastRoundSkipped &&
        c.attempt != _popDismissedForAttempt &&
        !tutorial.popupVisible;
  }

  ResultTier get _resultTier {
    final c = controller;
    if (c.roundPitchTotal > 0 &&
        c.roundPitchCorrect == c.roundPitchTotal &&
        c.roundOnTime == c.roundPitchTotal) {
      return ResultTier.perfect;
    }
    if (c.roundPitchCorrect * 2 >= c.roundPitchTotal) return ResultTier.good;
    return ResultTier.lost;
  }

  void _dismissPop() {
    setState(() => _popDismissedForAttempt = controller.attempt);
  }

  static final Map<LogicalKeyboardKey, int> _keyMap = {
    LogicalKeyboardKey.keyA: 0,
    LogicalKeyboardKey.keyW: 1,
    LogicalKeyboardKey.keyS: 2,
    LogicalKeyboardKey.keyE: 3,
    LogicalKeyboardKey.keyD: 4,
    LogicalKeyboardKey.keyF: 5,
    LogicalKeyboardKey.keyT: 6,
    LogicalKeyboardKey.keyG: 7,
    LogicalKeyboardKey.keyY: 8,
    LogicalKeyboardKey.keyH: 9,
    LogicalKeyboardKey.keyU: 10,
    LogicalKeyboardKey.keyJ: 11,
    LogicalKeyboardKey.keyK: 12,
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Any key dismisses the splash.
    if (_splashVisible) {
      if (event is KeyDownEvent) _splashKey.currentState?.close();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent && _logVisible) {
        setState(() => _logVisible = false);
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent && tutorial.popupVisible) {
        tutorial.skip();
        return KeyEventResult.handled;
      }
      if (event is KeyDownEvent && _resultPopVisible) {
        _dismissPop();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final semitone = _keyMap[event.logicalKey];
    if (semitone == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent) {
      controller.noteOn(semitone);
    } else if (event is KeyUpEvent) {
      controller.noteOff(semitone);
    }
    return KeyEventResult.handled; // swallow repeats too
  }

  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    ThemeController.instance.removeListener(_onThemeChanged);
    tutorial.dispose();
    controller.dispose();
    _scrollTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: SizedBox.expand(
        child: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Stack(
          key: _rootKey,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _scrollTick.value++;
                return false;
              },
              child: _mainContent(p),
            ),
            Positioned.fill(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, tutorial]),
                builder: (context, _) => _resultPopVisible
                    ? ResultPop(
                        tier: _resultTier,
                        pitchCorrect: controller.roundPitchCorrect,
                        onTime: controller.roundOnTime,
                        pitchTotal: controller.roundPitchTotal,
                        streak: controller.streak,
                        showReplay: !controller.perfectPitch,
                        onDismiss: _dismissPop,
                        onNext: () {
                          _dismissPop();
                          controller.playRound();
                        },
                        onReplay: () {
                          _dismissPop();
                          controller.replay();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            if (_logVisible)
              Positioned.fill(
                child: RoundLogPop(
                  controller: controller,
                  onDismiss: () => setState(() => _logVisible = false),
                ),
              ),
            Positioned.fill(
              child: TutorialOverlay(
                tut: tutorial,
                rootKey: _rootKey,
                keyboardKey: _keyboardKey,
                playKey: _playKey,
                scoreKey: _scoreKey,
                settingsKey: _settingsKey,
                repaint: _scrollTick,
              ),
            ),
            if (_splashVisible)
              Positioned.fill(
                child: SplashScreen(
                  key: _splashKey,
                  onDismiss: () {
                    setState(() => _splashVisible = false);
                    // The dismiss gesture doubles as the browser audio unlock.
                    controller.engine.unlock();
                    tutorial.startTour();
                  },
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _mainContent(Palette p) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [p.skyTop, p.skyMid, p.skyBottom],
                  stops: const [0, 0.45, 1],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                      color: p.cardShadow,
                      offset: const Offset(0, 14),
                      blurRadius: 40),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                if (p.isNight)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _NightSkyPainter()),
                    ),
                  ),
                Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _topBar(p),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth > 860;
                    final stage = _stage(p);
                    final settings = KeyedSubtree(
                      key: _settingsKey,
                      child: Container(
                        margin: wide
                            ? const EdgeInsets.fromLTRB(0, 6, 22, 26)
                            : const EdgeInsets.fromLTRB(24, 0, 24, 26),
                        decoration: BoxDecoration(
                          color: p.panel,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: p.cardShadow,
                                offset: const Offset(0, 6)),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                        child: SettingsPanel(controller: controller),
                      ),
                    );
                    if (wide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: stage),
                          SizedBox(width: 306, child: settings),
                        ],
                      );
                    }
                    return Column(children: [stage, settings]);
                  }),
                ],
              ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(Palette p, Widget child,
      {EdgeInsets padding =
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6)}) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: p.cardShadow, offset: const Offset(0, 3)),
        ],
      ),
      padding: padding,
      child: child,
    );
  }

  Widget _topBar(Palette p) {
    final c = controller;
    String pct(int num, int den) =>
        den == 0 ? '—' : '${(100 * num / den).toStringAsFixed(2)}%';
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 10,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: CustomPaint(
                  size: const Size(46, 35), painter: LarkPainter()),
            ),
            Text('Skylark',
                style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    shadows: const [
                      Shadow(color: Color(0xAAFFFFFF), offset: Offset(0, 2))
                    ])),
          ]),
          _modeToggle(p),
          Tooltip(
            message: 'Replay the tutorial',
            child: InkWell(
              onTap: tutorial.restart,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: p.surface.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: p.cardShadow, offset: const Offset(0, 3)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text('?',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.muted)),
              ),
            ),
          ),
                if (!c.freePlay) ...[
                  _stat(p, 'Pitch', pct(c.totalPitchCorrect, c.totalPitchEvents)),
                  if (!c.perfectPitch && !c.pairDrill)
                    _stat(p, 'Timing', pct(c.totalOnTime, c.totalTimedEvents)),
                  _stat(p, '⭐ Streak', '${c.streak}'),
                ],
                _logButton(p),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _dayNightToggle(p),
        ],
      ),
    );
  }

  Widget _logButton(Palette p) {
    final count = controller.roundLog.length;
    return InkWell(
      onTap: () => setState(() => _logVisible = true),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(color: p.cardShadow, offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_rounded, size: 15, color: p.muted),
          const SizedBox(width: 5),
          Text('Log',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: p.ink)),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: p.onAccent)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _dayNightToggle(Palette p) {
    Widget chip(IconData icon, String label, bool selected, bool toNight) =>
        InkWell(
          onTap: () => ThemeController.instance.setNight(toNight),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? p.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [BoxShadow(color: p.accentShadow, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon,
                  size: 14, color: selected ? p.onAccent : p.muted),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? p.onAccent : p.muted)),
            ]),
          ),
        );
    final night = p.isNight;
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: night ? 0.85 : 0.72),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: p.cardShadow, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip(Icons.wb_sunny_rounded, 'Day', !night, false),
        chip(Icons.nightlight_round, 'Night', night, true),
      ]),
    );
  }

  Widget _modeToggle(Palette p) {
    final c = controller;
    Widget chip(String label, bool selected, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? p.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: selected
                  ? [BoxShadow(color: p.accentShadow, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? p.onAccent : p.muted)),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: p.cardShadow, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip('Training', c.mode == GameMode.training,
            () => c.setMode(GameMode.training)),
        chip('Perfect Pitch', c.perfectPitch,
            () => c.setMode(GameMode.perfectPitch)),
        chip('Pair Drill', c.pairDrill, () => c.setMode(GameMode.pairDrill)),
        chip('Free play', c.freePlay, () => c.setMode(GameMode.freePlay)),
      ]),
    );
  }

  Widget _stat(Palette p, String label, String value) {
    return _pill(
      p,
      Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: p.muted)),
        Text(value,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: p.ink)),
      ]),
    );
  }

  /// Perfect Pitch shows the tail of the stream: the last few notes,
  /// re-based to beat 0, so older notes slide off to the left as new ones
  /// arrive. Two measures' worth always fits the staff without scrolling.
  static const _ppWindowNotes = 8;

  List<JudgedEvent> _ppWindow(List<JudgedEvent> judged) {
    final start =
        judged.length <= _ppWindowNotes ? 0 : judged.length - _ppWindowNotes;
    return [
      for (var i = start; i < judged.length; i++)
        JudgedEvent(NoteEvent(
            startBeat: (i - start).toDouble(),
            durationBeats: 1,
            pitch: judged[i].event.pitch))
          ..verdict = judged[i].verdict
          ..played = judged[i].played
          ..revealed = judged[i].revealed,
    ];
  }

  Widget _stage(Palette p) {
    final c = controller;
    final display = c.freePlay
        ? [
            for (var i = 0; i < c.echo.length; i++)
              JudgedEvent(NoteEvent(
                  startBeat: i.toDouble(),
                  durationBeats: 1,
                  pitch: c.echo[i]))
                ..revealed = true,
          ]
        : (c.perfectPitch || c.pairDrill)
            ? _ppWindow(c.judged)
            : c.judged;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 6, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _transport(p),
          const SizedBox(height: 18),
          Container(
            key: _scoreKey,
            decoration: BoxDecoration(
              color: p.surface2,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(color: p.cardShadow, offset: const Offset(0, 8)),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _scoreHeader(p),
                _DottedDivider(color: p.line),
                if ((c.perfectPitch || c.pairDrill) && c.ppFeedback != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                    child: Text(c.ppFeedback!,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.muted)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                  child: StaffView(
                    judged: display,
                    measures: (c.perfectPitch || c.pairDrill)
                        ? ((display.length + 3) ~/ 4).clamp(1, 2)
                        : c.melody?.measures ?? c.settings.measures,
                    playheadBeat: c.playheadBeat,
                    secondsPerBeat: c.secondsPerBeat,
                    neutralInk: c.freePlay,
                    wrongDyad: c.perfectPitch || c.pairDrill,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // The verdict legend appears once notes are actually being judged.
          if (!c.freePlay &&
              (c.phase == Phase.performing ||
                  c.phase == Phase.summary ||
                  ((c.perfectPitch || c.pairDrill) &&
                      c.judged.isNotEmpty))) ...[
            _legend(p),
            const SizedBox(height: 18),
          ] else
            const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [_instrumentToggle(p), _toneQuickPicks(p)],
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: _keyboardKey,
            child: c.instrument == Instrument.guitar
                ? FretboardView(controller: c)
                : KeyboardView(controller: c),
          ),
        ],
      ),
    );
  }

  /// Piano / Guitar switch for the playing surface. Visual only: the
  /// notes, computer keys, and audio are identical on both.
  Widget _instrumentToggle(Palette p) {
    final c = controller;
    Widget chip(String label, Instrument v) => InkWell(
          onTap: () => c.setInstrument(v),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: c.instrument == v ? p.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: c.instrument == v
                  ? [BoxShadow(color: p.accentShadow, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: c.instrument == v ? p.onAccent : p.muted)),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: p.cardShadow, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip('Piano', Instrument.piano),
        chip('Guitar', Instrument.guitar),
      ]),
    );
  }

  /// The selected instrument's tones as one-tap chips. Synth waves stay
  /// under More settings; these are the sampled sounds per instrument.
  Widget _toneQuickPicks(Palette p) {
    final c = controller;
    final tones = c.instrument == Instrument.guitar
        ? const [Tone.guitarClean, Tone.guitarOverdrive, Tone.guitarDistortion]
        : const [Tone.salamander, Tone.fluid];
    String short(Tone t) => switch (t) {
          Tone.guitarClean => 'Clean',
          Tone.guitarOverdrive => 'Overdrive',
          Tone.guitarDistortion => 'Distortion',
          _ => t.label,
        };
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final t in tones)
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => c.updateSettings(c.settings.copyWith(tone: t)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                color: t == c.settings.tone
                    ? p.accent
                    : p.surface.withValues(alpha: 0.72),
                border: Border.all(
                    color: t == c.settings.tone ? p.accentShadow : p.line,
                    width: 2),
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                      color: t == c.settings.tone
                          ? p.accentShadow
                          : p.cardShadow,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text(short(t),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          t == c.settings.tone ? p.onAccent : p.muted)),
            ),
          ),
      ],
    );
  }

  /// Status message, sun beat-lamps, and tempo — the notation card's header.
  Widget _scoreHeader(Palette p) {
    final c = controller;
    final (msg, sub) = _statusText();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg,
                    style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(fontSize: 12.5, color: p.muted)),
                if (c.ppStreaming) ...[
                  const SizedBox(height: 10),
                  _hearAgain(p),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (c.perfectPitch || c.pairDrill)
            Text(
                switch (c.ppAnswered) {
                  0 => '',
                  1 => '♪ 1 note',
                  final n => '♪ $n notes',
                },
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: p.muted))
          else
            Row(children: [
              for (var b = 0; b < 4; b++)
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: c.activeBeat == b ? p.accent : p.soft,
                    shape: BoxShape.circle,
                    boxShadow: c.activeBeat == b
                        ? [BoxShadow(color: p.accentSoft, spreadRadius: 4)]
                        : null,
                  ),
                ),
              const SizedBox(width: 12),
              Text('♩ = ${c.settings.bpm}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.muted)),
            ]),
        ],
      ),
    );
  }

  Widget _hearAgain(Palette p) {
    final c = controller;
    final left = c.ppReplaysLeft;
    final enabled = left != 0;
    final suffix = switch (left) {
      -1 => ' · unlimited',
      0 => ' · none left',
      1 => ' · 1 left',
      _ => ' · $left left',
    };
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: enabled ? c.ppHearAgain : null,
          child: Container(
            decoration: BoxDecoration(
              color: p.tonicSoft,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(color: p.blueShadow, offset: const Offset(0, 3)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('↻  Hear it again$suffix',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.tonic)),
          ),
        ),
      ),
    );
  }

  (String, String?) _statusText() {
    final c = controller;
    if (c.paused) {
      return ('Paused', 'Everything is frozen in place. Press Resume to continue.');
    }
    if (c.freePlay) {
      return (
        'Free play',
        'The staff echoes what you play — no judging. Turn on the metronome to practice in time.'
      );
    }
    if (c.perfectPitch) {
      if (c.phase == Phase.performing) {
        return (
          c.streak > 1 ? 'What do you hear? — streak ${c.streak}'
              : 'What do you hear?',
          'No tonic, no pulse. Press the key you think it is — your first press counts.'
        );
      }
      return (
        'Ready when you are',
        'Press Start for a stream of mystery notes. No tonic, no pulse — stop whenever you like.'
      );
    }
    if (c.pairDrill) {
      final pairLabels =
          c.settings.focusPair.map((s) => Pitch(s).label).toList();
      if (c.phase == Phase.performing) {
        return (
          c.streak > 1 ? 'What do you hear? — streak ${c.streak}'
              : 'What do you hear?',
          'Listening for ${pairLabels.join(" and ")} most of the time — but never twice in a row.'
        );
      }
      if (pairLabels.length != 2) {
        return (
          'Pick your pair',
          'Choose exactly two notes you mix up under Choose your pair, then press Start.'
        );
      }
      return (
        'Ready when you are',
        'Press Start to drill ${pairLabels.join(" vs ")}. No tonic, no pulse — stop whenever you like.'
      );
    }
    final measures = c.melody?.measures ?? c.settings.measures;
    switch (c.phase) {
      case Phase.idle:
        return (
          'Ready when you are',
          'Press Play round. Active keys are free to try any time.'
        );
      case Phase.tonic:
        return ('Reference: tonic C4', 'The melody’s home base.');
      case Phase.countIn:
        return ('Count-in…', 'The melody starts on the next downbeat.');
      case Phase.listening:
        final m =
            ((c.playheadBeat ?? 0) / 4).floor().clamp(0, measures - 1) + 1;
        return ('Listen — measure $m of $measures',
            'Ears only! The staff stays blank on purpose.');
      case Phase.userCount:
        return ('Get ready…', 'Your turn after the count. Play in time.');
      case Phase.performing:
        final beat = c.playheadBeat ?? 0;
        final m = (beat / 4).floor().clamp(0, measures - 1) + 1;
        final b = (beat % 4).floor() + 1;
        return ('Your turn — measure $m, beat $b',
            'Stay with the beat — you’ve got this!');
      case Phase.summary:
        return (
          'Round ${c.roundNumber}: ${c.roundPitchCorrect}/${c.roundPitchTotal} pitches · ${c.roundOnTime}/${c.roundPitchTotal} on time',
          c.streak > 0
              ? 'Perfect round — streak ${c.streak}! Replay to study, or press Next round.'
              : 'Replay to study the melody, or press Next round.'
        );
    }
  }

  Widget _transport(Palette p) {
    final c = controller;
    if (c.freePlay) {
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          _button(
            p,
            c.metronomeOn ? '■  Metronome off' : '▶  Metronome',
            primary: c.metronomeOn,
            onTap: c.toggleMetronome,
          ),
          _button(p, '⌫  Clear staff',
              onTap: c.echo.isEmpty ? null : c.clearEcho),
        ],
      );
    }
    final active = c.phase.isActiveRound;
    if (c.perfectPitch || c.pairDrill) {
      final canStart = !c.pairDrill || c.settings.focusPair.length == 2;
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          KeyedSubtree(
            key: _playKey,
            child: _button(
              p,
              active ? '■  Stop' : '▶  Start',
              primary: !active,
              onTap: active ? c.stopPP : (canStart ? c.playRound : null),
            ),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        KeyedSubtree(
          key: _playKey,
          child: _button(
            p,
            c.phase == Phase.summary ? '▶  Next round' : '▶  Play round',
            primary: !c.paused,
            onTap: active ? null : c.playRound,
          ),
        ),
        if (active)
          _button(p, c.paused ? '▶  Resume' : '❚❚  Pause',
              blue: !c.paused, primary: c.paused, onTap: c.togglePause),
        if (c.melody != null && !active)
          _button(p, '↻  Replay melody', onTap: c.replay),
        if (active) _button(p, 'Skip round', ghost: true, onTap: c.skip),
      ],
    );
  }

  Widget _button(Palette p, String label,
      {bool primary = false,
      bool blue = false,
      bool ghost = false,
      VoidCallback? onTap}) {
    final enabled = onTap != null;
    Color bg = p.surface;
    Color fg = p.muted;
    Color shadow = p.btnShadow;
    if (primary) {
      bg = p.accent;
      fg = p.onAccent;
      shadow = p.accentShadow;
    } else if (blue) {
      bg = p.tonicSoft;
      fg = p.tonic;
      shadow = p.blueShadow;
    } else if (ghost) {
      bg = p.surface.withValues(alpha: 0.6);
    }
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 4))],
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }

  Widget _legend(Palette p) {
    Widget item(Color c, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.muted)),
          ],
        );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: (controller.perfectPitch || controller.pairDrill)
          ? [
              item(p.good, 'Right'),
              item(p.bad, 'Your guess'),
              item(p.warn, 'Correct answer'),
            ]
          : [
              item(p.good, 'Right & on the beat'),
              item(p.warn, 'Right, off the beat'),
              item(p.bad, 'Wrong or missed'),
              item(const Color(0xFFB9C7DC), 'Rest — float through it'),
            ],
    );
  }
}

class _DottedDivider extends StatelessWidget {
  final Color color;
  const _DottedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: CustomPaint(painter: _DotsPainter(color), size: Size.infinite),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  _DotsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 12.0; x < size.width - 6; x += 9) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}

/// Night dressing behind the app content: twinkle stars and
/// night-cloud silhouettes.
class _NightSkyPainter extends CustomPainter {
  const _NightSkyPainter();

  // (fx, fy, radius, opacity) in fractions of the frame.
  static const _stars = [
    (0.06, 0.06, 2.4, 0.9),
    (0.16, 0.16, 1.6, 0.55),
    (0.30, 0.05, 2.0, 0.8),
    (0.44, 0.12, 1.4, 0.5),
    (0.55, 0.04, 2.2, 0.85),
    (0.66, 0.17, 1.5, 0.5),
    (0.78, 0.07, 2.4, 0.9),
    (0.90, 0.13, 1.6, 0.55),
    (0.09, 0.42, 1.5, 0.45),
    (0.50, 0.30, 1.3, 0.4),
    (0.93, 0.38, 1.8, 0.6),
    (0.03, 0.68, 1.8, 0.5),
    (0.97, 0.62, 1.5, 0.5),
    (0.38, 0.50, 1.2, 0.35),
  ];

  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final p = Path()
      ..moveTo(c.dx, c.dy - r * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
      ..close();
    canvas.drawPath(p, paint);
  }

  void _puff(Canvas canvas, Offset c, double w, Color color) {
    final paint = Paint()..color = color;
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(-w * 0.16, w * 0.05),
            width: w * 0.62,
            height: w * 0.24),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(w * 0.14, -w * 0.02),
            width: w * 0.52,
            height: w * 0.22),
        paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, r, o) in _stars) {
      _sparkle(
          canvas,
          Offset(fx * size.width, fy * size.height),
          r,
          Paint()..color = Color.fromRGBO(0xCB, 0xD6, 0xFF, o));
    }
    _puff(canvas, Offset(size.width * 0.10, size.height * 0.10), 140,
        const Color(0xCC232E58));
    _puff(canvas, Offset(size.width * 0.88, size.height * 0.22), 110,
        const Color(0x99232E58));
    _puff(canvas, Offset(size.width * 0.16, size.height * 0.86), 120,
        const Color(0x88232E58));
  }

  @override
  bool shouldRepaint(_NightSkyPainter old) => false;
}
