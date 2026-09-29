import 'package:flutter/material.dart';

import '../audio/audio_engine.dart';
import '../models/note.dart';
import '../models/round.dart';
import '../models/settings.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';

class SettingsPanel extends StatefulWidget {
  final GameController controller;

  const SettingsPanel({super.key, required this.controller});

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
                c.perfectPitch
                    ? switch (s.difficulty) {
                        Difficulty.beginner =>
                          'Replay the mystery note as often as you like.',
                        Difficulty.easy => 'Two replays per mystery note.',
                        Difficulty.standard ||
                        Difficulty.custom =>
                          'One replay per mystery note.',
                        Difficulty.hard => 'One listen only — no replays.',
                      }
                    : switch (s.difficulty) {
                        Difficulty.beginner =>
                          'Quarter notes only, no rests, loose timing — pitch dictation on a steady pulse.',
                        Difficulty.easy =>
                          'Quarters and halves, no rests. Standard timing.',
                        Difficulty.standard =>
                          'Quarters, halves, eighth pairs, and rests. Standard timing.',
                        Difficulty.hard =>
                          'Full vocabulary, more eighths and rests. Tight timing.',
                        Difficulty.custom =>
                          'Custom — tweaked under More settings.',
                      }),
            const SizedBox(height: 20),
            _head(p, 'Notes in play'),
            const SizedBox(height: 8),
            _noteChips(p, c),
            const SizedBox(height: 6),
            _sub(
                p,
                c.perfectPitch
                    ? '${s.noteSet.length} of $semitoneCount selected — the real difficulty dial. At least 2 required.'
                    : '${s.noteSet.length} of $semitoneCount selected. At least 2 required.'),
            const SizedBox(height: 20),
            _head(p, c.perfectPitch ? 'Notes per round' : 'Length'),
            const SizedBox(height: 8),
            _stepper(p, c),
            const SizedBox(height: 6),
            _sub(
                p,
                c.perfectPitch
                    ? 'Mystery notes per round (1–10).'
                    : 'Measures per round (1–4), in 4/4.'),
            const SizedBox(height: 20),
            if (c.perfectPitch)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: p.line, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Tempo is hidden here — Perfect Pitch has no pulse. '
                  'Tonic-first is off by design: no reference note allowed.',
                  style: TextStyle(
                      fontSize: 11.5, height: 1.4, color: p.muted),
                ),
              )
            else ...[
            _head(p, 'Tempo'),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: p.tonicSoft,
                inactiveTrackColor: p.soft,
                thumbColor: p.accent,
                overlayColor: p.accentSoft.withValues(alpha: 0.5),
                trackHeight: 8,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 11),
              ),
              child: Slider(
                value: s.bpm.toDouble(),
                min: 40,
                max: 140,
                divisions: 20,
                onChanged: (v) =>
                    c.updateSettings(s.copyWith(bpm: v.round())),
              ),
            ),
            _sub(p, '♩ = ${s.bpm} BPM (40–140)'),
            ],
            const SizedBox(height: 20),
            // ------------------------------------------------ More settings
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
              _sub(
                  p,
                  c.perfectPitch
                      ? 'Tone — practice across timbres'
                      : 'Rhythm vocabulary · Timing window · Play tonic first · Tone'),
            ] else if (c.perfectPitch) ...[
              const SizedBox(height: 18),
              _head(p, 'Tone'),
              const SizedBox(height: 8),
              _segmented<Tone>(
                p,
                values: Tone.values,
                selected: s.tone,
                label: (t) => t.label,
                onTap: (t) => c.updateSettings(s.copyWith(tone: t)),
              ),
              const SizedBox(height: 6),
              _sub(p,
                  'Pure = sine · Warm = triangle · Organ = layered harmonics. Recognizing pitch across timbres is the real test.'),
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
              const SizedBox(height: 18),
              _head(p, 'Tone'),
              const SizedBox(height: 8),
              _segmented<Tone>(
                p,
                values: Tone.values,
                selected: s.tone,
                label: (t) => t.label,
                onTap: (t) => c.updateSettings(s.copyWith(tone: t)),
              ),
              const SizedBox(height: 6),
              _sub(p,
                  'Pure = sine · Warm = triangle · Organ = layered harmonics.'),
            ],
          ],
        ),
      ),
    );
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
    final pp = c.perfectPitch;
    final value = pp ? s.ppNotes : s.measures;
    final min = 1, max = pp ? 10 : 4;
    void set(int v) => c.updateSettings(
        pp ? s.copyWith(ppNotes: v) : s.copyWith(measures: v));
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

  Widget _stepBtn(Palette p, String label, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 40,
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
