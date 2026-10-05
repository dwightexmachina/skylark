import 'package:flutter/material.dart';

import '../logic/songs.dart';
import '../models/note.dart';
import '../models/round.dart';
import '../models/settings.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';

class SettingsPanel extends StatefulWidget {
  final GameController controller;
  final VoidCallback onOpenNotesFrequency;

  const SettingsPanel(
      {super.key, required this.controller, required this.onOpenNotesFrequency});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _moreOpen = false;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = widget.controller;
    final s = c.settings;
    final locked = c.phase.isActiveRound;

    return IgnorePointer(
      ignoring: locked,
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚙ Settings',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: p.ink)),
            const SizedBox(height: 18),
            if (c.echoMode)
              ..._echoSections(p, c, s)
            else if (c.songsMode)
              ..._songSections(p, c, s)
            else ...[
            _head(p, 'Difficulty'),
            const SizedBox(height: 8),
            _segmented<Difficulty>(
              p,
              values: const [
                Difficulty.beginner,
                Difficulty.easy,
                Difficulty.standard,
                Difficulty.hard,
              ],
              selected: s.difficulty,
              label: (d) => d.label,
              onTap: (d) => c.updateSettings(s.withDifficulty(d)),
            ),
            const SizedBox(height: 6),
            _sub(
                p,
                switch (s.difficulty) {
                  Difficulty.beginner =>
                    'Quarter notes only, no rests, loose timing — pitch dictation on a steady pulse.',
                  Difficulty.easy =>
                    'Quarters and halves, no rests. Standard timing.',
                  Difficulty.standard =>
                    'Quarters, halves, eighth pairs, and rests. Standard timing.',
                  Difficulty.hard =>
                    'Full vocabulary, more eighths and rests. Tight timing.',
                  Difficulty.custom => 'Custom — tweaked under More settings.',
                }),
            const SizedBox(height: 20),
            _head(p, 'Notes in play'),
            const SizedBox(height: 8),
            _noteChips(p, c),
            const SizedBox(height: 6),
            _sub(p,
                '${s.noteSet.length} of $semitoneCount selected. At least 2 required.'),
            const SizedBox(height: 20),
            _head(p, 'Length'),
            const SizedBox(height: 8),
            _stepper(p, c),
            const SizedBox(height: 6),
            _sub(p, 'Measures per round (1–4), in 4/4.'),
            const SizedBox(height: 20),
            ..._tempo(p, c, s),
            const SizedBox(height: 20),
            InkWell(
              onTap: () => setState(() => _moreOpen = !_moreOpen),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: p.btnShadow, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('More settings',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: p.staffInk)),
                    Text(_moreOpen ? '▾' : '▸',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: p.tonicSoft)),
                  ],
                ),
              ),
            ),
            if (!_moreOpen) ...[
              const SizedBox(height: 6),
              _sub(p,
                  'Rhythm vocabulary · Timing window · Play tonic first'),
            ] else ...[
              const SizedBox(height: 18),
              _head(p, 'Rhythm vocabulary'),
              const SizedBox(height: 6),
              _check(p, c, 'Half notes', s.allowHalves,
                  (v) => s.copyWith(
                      allowHalves: v, difficulty: Difficulty.custom)),
              _check(p, c, 'Eighth-note pairs', s.allowEighths,
                  (v) => s.copyWith(
                      allowEighths: v, difficulty: Difficulty.custom)),
              _check(p, c, 'Rests', s.allowRests,
                  (v) => s.copyWith(
                      allowRests: v, difficulty: Difficulty.custom)),
              _sub(p, 'Quarter notes are always in play.'),
              const SizedBox(height: 18),
              _head(p, 'Timing window'),
              const SizedBox(height: 8),
              _segmented<TimingWindow>(
                p,
                values: TimingWindow.values,
                selected: s.window,
                label: (w) => w.label,
                onTap: (w) => c.updateSettings(
                    s.copyWith(window: w, difficulty: Difficulty.custom)),
              ),
              const SizedBox(height: 6),
              _sub(p,
                  'How far off the beat a note may land: ±½ · ±¼ · ±⅛ beat.'),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _head(p, 'Play tonic first'),
                  Switch(
                    value: s.tonicFirst,
                    activeThumbColor: p.accent,
                    activeTrackColor: p.tonicSoft,
                    inactiveThumbColor: p.surface,
                    inactiveTrackColor: p.soft,
                    thumbIcon: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Icon(Icons.wb_sunny, size: 14, color: p.onAccent)
                          : null,
                    ),
                    onChanged: (v) =>
                        c.updateSettings(s.copyWith(tonicFirst: v)),
                  ),
                ],
              ),
              _sub(p,
                  'Each round opens with C4 as a reference before the count-in.'),
            ],
            ],
            const SizedBox(height: 16),
            _sub(p,
                'Sounds: Salamander Grand Piano by Alexander Holm (CC-BY 3.0) · FluidR3 soundfont (MIT).'),
          ],
        ),
      ),
    );
  }

  /// Songs' whole sidebar: pick a tune, set the pulse, set how strict the
  /// beat is. No difficulty preset (the song *is* the difficulty, and the
  /// list is ordered easiest first), no note chips (the song decides which
  /// keys are live), no length (the song decides that too).
  List<Widget> _songSections(Palette p, GameController c, Settings s) {
    final song = c.song;
    final index = s.songIndex.clamp(0, kSongs.length - 1);
    return [
      _head(p, 'Song'),
      const SizedBox(height: 8),
      // The library is long enough to push the rest of the sidebar off the
      // page, so it scrolls within its own box instead.
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 322),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: kSongs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) => _songRow(p, c, i, i == index),
        ),
      ),
      const SizedBox(height: 10),
      _sub(
          p,
          'In C, 4/4 — ${song.measures} measures. '
              'Notes you’ll need: ${song.noteLabels}.'),
      const SizedBox(height: 20),
      ..._tempo(p, c, s),
      const SizedBox(height: 20),
      _head(p, 'Timing window'),
      const SizedBox(height: 8),
      _segmented<TimingWindow>(
        p,
        values: TimingWindow.values,
        selected: s.window,
        label: (w) => w.label,
        // Unlike Training's copy of this control, no difficulty to mark
        // custom — Songs never shows a preset to deviate from.
        onTap: (w) => c.updateSettings(s.copyWith(window: w)),
      ),
      const SizedBox(height: 6),
      _sub(p, 'How far off the beat a note may land: ±½ · ±¼ · ±⅛ beat.'),
    ];
  }

  Widget _songRow(Palette p, GameController c, int index, bool on) {
    final song = kSongs[index];
    return InkWell(
      onTap: () => c.updateSettings(c.settings.copyWith(songIndex: index)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: on ? p.accent : p.surface,
          border: Border.all(color: on ? p.accentShadow : p.line, width: 2),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: on ? p.accentShadow : p.btnShadow,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Text(song.name,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? p.onAccent : p.staffInk)),
      ),
    );
  }

  /// Shared by Training and Songs — both run on the metronome.
  List<Widget> _tempo(Palette p, GameController c, Settings s) {
    return [
      _head(p, 'Tempo'),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: p.tonicSoft,
          inactiveTrackColor: p.soft,
          thumbColor: p.accent,
          overlayColor: p.accentSoft.withValues(alpha: 0.5),
          trackHeight: 8,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
        ),
        child: Slider(
          value: s.bpm.toDouble(),
          min: 40,
          max: 140,
          divisions: 20,
          onChanged: (v) => c.updateSettings(s.copyWith(bpm: v.round())),
        ),
      ),
      _sub(p, '♩ = ${s.bpm} BPM (40–140)'),
    ];
  }

  /// Echo's whole sidebar: no difficulty preset, no tempo, no Log grouping
  /// (batch size is derived from Notes per round, not user-configurable).
  List<Widget> _echoSections(Palette p, GameController c, Settings s) {
    return [
      _head(p, 'Notes in play'),
      const SizedBox(height: 8),
      _noteChips(p, c),
      const SizedBox(height: 6),
      _sub(p, '${s.noteSet.length} of $semitoneCount selected. At least 2 required.'),
      const SizedBox(height: 12),
      InkWell(
        onTap: widget.onOpenNotesFrequency,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: p.tonicSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text('🎚️ Notes Frequency',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: p.tonic)),
        ),
      ),
      const SizedBox(height: 20),
      _head(p, 'Notes per round'),
      const SizedBox(height: 8),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _echoNotesStepper(p, c),
          if (s.echoNotes > 1) ...[
            const SizedBox(width: 8),
            _echoLagStepper(p, c),
          ],
        ],
      ),
      const SizedBox(height: 6),
      _sub(
          p,
          s.echoNotes > 1
              ? 'How many quarter notes play before you echo them back, in '
                  'order (1–5), and the gap between each (0.25s–2s).'
              : 'How many quarter notes play before you echo them back, in '
                  'order (1–5).'),
      const SizedBox(height: 20),
      _head(p, 'Replays'),
      const SizedBox(height: 8),
      _segmented<ReplayBudget>(
        p,
        values: ReplayBudget.values,
        selected: s.echoReplays,
        label: (r) => r.label,
        onTap: (r) => c.updateSettings(s.copyWith(echoReplays: r)),
      ),
      const SizedBox(height: 6),
      _sub(p, switch (s.echoReplays) {
        ReplayBudget.unlimited => 'Replay the whole round as often as you like.',
        ReplayBudget.two => 'Two replays of the whole round.',
        ReplayBudget.one => 'One replay of the whole round.',
        ReplayBudget.none => 'One listen only — no replays.',
      }),
    ];
  }

  Widget _echoNotesStepper(Palette p, GameController c) {
    final value = c.settings.echoNotes;
    void set(int v) => c.updateSettings(c.settings.copyWith(echoNotes: v));
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: p.btnShadow, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(p, '−', value > 1, () => set(value - 1), width: 32),
          Container(
            width: 30,
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            child: Text('$value',
                style: TextStyle(fontWeight: FontWeight.w700, color: p.ink)),
          ),
          _stepBtn(p, '+', value < 5, () => set(value + 1), width: 32),
        ],
      ),
    );
  }

  /// Hidden at one note per round — there's no gap to configure between a
  /// single note and itself.
  Widget _echoLagStepper(Palette p, GameController c) {
    if (c.settings.echoNotes < 2) return const SizedBox.shrink();
    final value = c.settings.echoNoteLag;
    void set(double v) => c.updateSettings(c.settings.copyWith(echoNoteLag: v));
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: p.btnShadow, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(p, '−', value > 0.25, () => set(value - 0.25), width: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            alignment: Alignment.center,
            child: Text('⏱${_lagLabel(value)}',
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: p.ink)),
          ),
          _stepBtn(p, '+', value < 2, () => set(value + 0.25), width: 32),
        ],
      ),
    );
  }

  String _lagLabel(double seconds) {
    final text = seconds == seconds.roundToDouble()
        ? seconds.toStringAsFixed(0)
        : seconds.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
    return '${text}s';
  }


  Widget _head(Palette p, String text) => Text(text,
      style: TextStyle(
          fontSize: 14.5, fontWeight: FontWeight.w700, color: p.ink));

  Widget _sub(Palette p, String text) =>
      Text(text, style: TextStyle(fontSize: 12, color: p.muted));

  Widget _check(Palette p, GameController c, String label, bool value,
      Settings Function(bool) update) {
    return InkWell(
      onTap: () => c.updateSettings(update(!value)),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
            width: 19,
            height: 19,
            decoration: BoxDecoration(
              color: value ? p.good : p.surface,
              border: Border.all(
                  color: value ? p.good : p.keyWhiteEdge, width: 2.5),
              borderRadius: BorderRadius.circular(7),
            ),
            child: value
                ? const Icon(Icons.check, size: 12, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: p.staffInk)),
        ]),
      ),
    );
  }

  Widget _noteChips(Palette p, GameController c) {
    return LayoutBuilder(builder: (context, constraints) {
      final chipW = (constraints.maxWidth - 6 * 7) / 7;
      return Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (var s = 0; s < semitoneCount; s++) _chip(p, c, s, chipW),
        ],
      );
    });
  }

  Widget _chip(Palette p, GameController c, int semitone, double width) {
    final on = c.settings.noteSet.contains(semitone);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => c.toggleNote(semitone),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: on ? p.accent : p.surface,
          border: Border.all(
              color: on ? p.accentShadow : p.line, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: on
              ? [BoxShadow(color: p.accentShadow, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          semitone < 12 ? pitchClassLabels[semitone] : Pitch(semitone).label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: on
                ? p.onAccent
                : (p.isNight ? p.muted : p.keyBlackDisabled),
          ),
        ),
      ),
    );
  }

  Widget _stepper(Palette p, GameController c) {
    final s = c.settings;
    final value = s.measures;
    const min = 1, max = 4;
    void set(int v) => c.updateSettings(s.copyWith(measures: v));
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: p.btnShadow, offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(p, '−', value > min, () => set(value - 1)),
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            child: Text('$value',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: p.ink)),
          ),
          _stepBtn(p, '+', value < max, () => set(value + 1)),
        ],
      ),
    );
  }

  Widget _stepBtn(Palette p, String label, bool enabled, VoidCallback onTap,
      {double width = 40}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: enabled ? p.tonicSoft : p.line)),
      ),
    );
  }

  Widget _segmented<T>(
    Palette p, {
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onTap(v),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: v == selected ? p.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: v == selected
                        ? [
                            BoxShadow(
                                color: p.accentShadow,
                                offset: const Offset(0, 2))
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label(v),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: v == selected ? p.onAccent : p.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
