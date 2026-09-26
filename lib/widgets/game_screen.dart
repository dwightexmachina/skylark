import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../models/round.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';
import 'keyboard.dart';
import 'settings_panel.dart';
import 'staff.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController controller = GameController();

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
  };

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
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
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Container(
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: p.line),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x14222222),
                          offset: Offset(0, 8),
                          blurRadius: 24),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _topBar(p),
                      Divider(height: 1, color: p.line),
                      LayoutBuilder(builder: (context, constraints) {
                        final wide = constraints.maxWidth > 860;
                        final stage = _stage(p);
                        final settings = Container(
                          color: p.surface2,
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                          child: SettingsPanel(controller: controller),
                        );
                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: stage),
                              SizedBox(width: 300, child: settings),
                            ],
                          );
                        }
                        return Column(children: [stage, settings]);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(Palette p) {
    final c = controller;
    String pct(int num, int den) =>
        den == 0 ? '—' : '${(100 * num / den).round()}%';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Row(
        children: [
          Text('Ear Trainer',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Georgia',
                  color: p.ink)),
          Text('  ♪', style: TextStyle(fontSize: 17, color: p.accent)),
          const SizedBox(width: 22),
          _modeToggle(p),
          const Spacer(),
          if (!c.freePlay) ...[
            _stat(p, 'Round', '${c.roundNumber}'),
            _stat(p, 'Pitch', pct(c.totalPitchCorrect, c.totalPitchEvents)),
            _stat(p, 'Timing', pct(c.totalOnTime, c.totalPitchEvents)),
            _stat(p, 'Streak', '${c.streak}'),
          ],
        ],
      ),
    );
  }

  Widget _modeToggle(Palette p) {
    final c = controller;
    Widget chip(String label, bool selected, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? p.accentSoft : p.surface,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? p.accent : p.muted)),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        chip('Training', !c.freePlay, () => c.setFreePlay(false)),
        Container(width: 1, height: 30, color: p.line),
        chip('Free play', c.freePlay, () => c.setFreePlay(true)),
      ]),
    );
  }

  Widget _stat(Palette p, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Row(children: [
        Text('$label ', style: TextStyle(fontSize: 13, color: p.muted)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: p.ink)),
      ]),
    );
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
        : c.judged;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusStrip(p),
          const SizedBox(height: 16),
          _transport(p),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: p.surface2,
              border: Border.all(color: p.line),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
            child: StaffView(
              judged: display,
              measures: c.melody?.measures ?? c.settings.measures,
              playheadBeat: c.playheadBeat,
              secondsPerBeat: c.secondsPerBeat,
              neutralInk: c.freePlay,
            ),
          ),
          const SizedBox(height: 8),
          if (!c.freePlay) _legend(p),
          if (!c.freePlay) const SizedBox(height: 18) else const SizedBox(height: 10),
          KeyboardView(controller: c),
          const SizedBox(height: 10),
          Text(
            'Play with the mouse or your computer keyboard — the letter on each key is its shortcut '
            '(A S D F G H J for naturals, W E T Y U for sharps). Held keys sustain. '
            'Greyed keys are outside the selected note set.',
            style: TextStyle(fontSize: 12, color: p.muted),
          ),
        ],
      ),
    );
  }

  Widget _statusStrip(Palette p) {
    final c = controller;
    final (msg, sub) = _statusText();
    return Container(
      decoration: BoxDecoration(
        color: p.surface2,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(fontSize: 12.5, color: p.muted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(children: [
            for (var b = 0; b < 4; b++)
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: c.activeBeat == b ? p.accent : Colors.transparent,
                  border: Border.all(
                      color: c.activeBeat == b ? p.accent : p.line,
                      width: 2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: c.activeBeat == b
                      ? [BoxShadow(color: p.accentSoft, spreadRadius: 4)]
                      : null,
                ),
              ),
            const SizedBox(width: 12),
            Text('♩ = ${c.settings.bpm}',
                style: TextStyle(
                    fontSize: 13, fontFamily: 'monospace', color: p.muted)),
          ]),
        ],
      ),
    );
  }

  (String, String?) _statusText() {
    final c = controller;
    if (c.freePlay) {
      return (
        'Free play',
        'The staff echoes what you play — no judging. Turn on the metronome to practice in time.'
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
            'The staff stays blank: pure dictation.');
      case Phase.userCount:
        return ('Get ready…', 'Your turn after the count. Play in time.');
      case Phase.performing:
        final beat = c.playheadBeat ?? 0;
        final m = (beat / 4).floor().clamp(0, measures - 1) + 1;
        final b = (beat % 4).floor() + 1;
        return ('Your turn — measure $m, beat $b',
            'Stay with the metronome. Sit out the rests.');
      case Phase.summary:
        return (
          'Round ${c.roundNumber}: ${c.roundPitchCorrect}/${c.roundPitchTotal} pitches · ${c.roundOnTime}/${c.roundPitchTotal} on time',
          c.streak > 0
              ? 'Perfect round — streak ${c.streak}. Replay to study, or press Next round.'
              : 'Replay to study the melody, or press Next round.'
        );
    }
  }

  Widget _transport(Palette p) {
    final c = controller;
    if (c.freePlay) {
      return Wrap(
        spacing: 10,
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
          _button(p, '♩  Hear tonic (C4)', tonic: true, onTap: c.hearTonic),
        ],
      );
    }
    final active = c.phase.isActiveRound;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _button(
          p,
          c.phase == Phase.summary ? '▶  Next round' : '▶  Play round',
          primary: true,
          onTap: active ? null : c.playRound,
        ),
        _button(p, '↻  Replay melody',
            onTap: c.melody == null ? null : c.replay),
        _button(p, '♩  Hear tonic (C4)', tonic: true, onTap: c.hearTonic),
        if (active) _button(p, 'Skip round', ghost: true, onTap: c.skip),
      ],
    );
  }

  Widget _button(Palette p, String label,
      {bool primary = false,
      bool tonic = false,
      bool ghost = false,
      VoidCallback? onTap}) {
    final enabled = onTap != null;
    Color bg = p.surface;
    Color fg = ghost ? p.muted : p.ink;
    Color edge = p.line;
    if (primary) {
      bg = p.accent;
      fg = p.onAccent;
      edge = p.accent;
    } else if (tonic) {
      bg = p.tonicSoft;
      fg = p.tonic;
      edge = p.tonic;
    }
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: edge),
              borderRadius: BorderRadius.circular(8),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
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
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, color: p.muted)),
          ],
        );
    return Wrap(
      spacing: 18,
      runSpacing: 6,
      children: [
        item(p.good, 'Right pitch, on the beat'),
        item(p.warn, 'Right pitch, off the beat'),
        item(p.bad, 'Wrong pitch or missed'),
        item(p.muted, 'Rest — wait it out'),
      ],
    );
  }
}
