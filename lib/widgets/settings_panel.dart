import 'package:flutter/material.dart';

import '../audio/audio_engine.dart';
import '../models/note.dart';
import '../models/round.dart';
import '../models/settings.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';

class SettingsPanel extends StatelessWidget {
  final GameController controller;

  const SettingsPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final c = controller;
    final s = c.settings;
    final locked = c.phase.isActiveRound;

    return IgnorePointer(
      ignoring: locked,
      child: Opacity(
        opacity: locked ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SETTINGS',
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    color: p.muted)),
            const SizedBox(height: 20),
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
                    'Quarter notes only, no rests — pitch dictation on a steady pulse.',
                  Difficulty.easy => 'Quarters and halves, no rests.',
                  Difficulty.standard =>
                    'Quarters, halves, eighth pairs, and rests.',
                  Difficulty.hard =>
                    'Full vocabulary, with more eighths and rests.',
                  Difficulty.custom => 'Custom — rhythm edited below.',
                }),
            const SizedBox(height: 22),
            _head(p, 'Rhythm vocabulary'),
            const SizedBox(height: 4),
            _check(p, c, 'Half notes', s.allowHalves,
                (v) => s.copyWith(allowHalves: v, difficulty: Difficulty.custom)),
            _check(p, c, 'Eighth-note pairs', s.allowEighths,
                (v) => s.copyWith(allowEighths: v, difficulty: Difficulty.custom)),
            _check(p, c, 'Rests', s.allowRests,
                (v) => s.copyWith(allowRests: v, difficulty: Difficulty.custom)),
            _sub(p, 'Quarter notes are always in play.'),
            const SizedBox(height: 22),
            _head(p, 'Notes in play'),
            const SizedBox(height: 8),
            _noteChips(p, c),
            const SizedBox(height: 6),
            _sub(p,
                '${s.noteSet.length} of 12 selected. At least 2 required.'),
            const SizedBox(height: 22),
            _head(p, 'Length'),
            const SizedBox(height: 8),
            _stepper(p, c),
            const SizedBox(height: 6),
            _sub(p,
                'Measures per round (1–4), in 4/4. Rhythms use quarters, halves, paired eighths, and quarter rests.'),
            const SizedBox(height: 22),
            _head(p, 'Tempo'),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: p.accent,
                inactiveTrackColor: p.line,
                thumbColor: p.accent,
                overlayColor: p.accent.withValues(alpha: 0.12),
                trackHeight: 4,
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
            _sub(p, '♩ = ${s.bpm} BPM'),
            const SizedBox(height: 22),
            _head(p, 'Timing window'),
            const SizedBox(height: 8),
            _segmented<TimingWindow>(
              p,
              values: TimingWindow.values,
              selected: s.window,
              label: (w) => w.label,
              onTap: (w) => c.updateSettings(s.copyWith(window: w)),
            ),
            const SizedBox(height: 6),
            _sub(p, 'How far off the beat a click may land: ±½ · ±¼ · ±⅛ beat.'),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _head(p, 'Play tonic first'),
                Switch(
                  value: s.tonicFirst,
                  activeThumbColor: p.surface,
                  activeTrackColor: p.accent,
                  inactiveTrackColor: p.line,
                  onChanged: (v) =>
                      c.updateSettings(s.copyWith(tonicFirst: v)),
                ),
              ],
            ),
            _sub(p, 'Each round opens with C4 as a reference before the count-in.'),
            const SizedBox(height: 22),
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
            _sub(p, 'Pure = sine · Warm = triangle · Organ = layered harmonics.'),
          ],
        ),
      ),
    );
  }

  Widget _head(Palette p, String text) => Text(text,
      style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: p.ink));

  Widget _check(Palette p, GameController c, String label, bool value,
      Settings Function(bool) update) {
    return InkWell(
      onTap: () => c.updateSettings(update(!value)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: value ? p.accent : p.surface,
              border: Border.all(color: value ? p.accent : p.line, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? Icon(Icons.check, size: 12, color: p.surface)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, color: p.ink)),
        ]),
      ),
    );
  }

  Widget _sub(Palette p, String text) =>
      Text(text, style: TextStyle(fontSize: 12, color: p.muted));

  Widget _noteChips(Palette p, GameController c) {
    return LayoutBuilder(builder: (context, constraints) {
      final chipW = (constraints.maxWidth - 5 * 6) / 6;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var s = 0; s < 12; s++)
            _chip(p, c, s, chipW),
        ],
      );
    });
  }

  Widget _chip(Palette p, GameController c, int semitone, double width) {
    final on = c.settings.noteSet.contains(semitone);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => c.toggleNote(semitone),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: on ? p.accentSoft : p.surface,
          border: Border.all(color: on ? p.accent : p.line),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          pitchClassLabels[semitone],
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
            color: on ? p.accent : p.muted,
          ),
        ),
      ),
    );
  }

  Widget _stepper(Palette p, GameController c) {
    final s = c.settings;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(p, '−', s.measures > 1,
              () => c.updateSettings(s.copyWith(measures: s.measures - 1))),
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border.symmetric(
                  vertical: BorderSide(color: p.line)),
            ),
            alignment: Alignment.center,
            child: Text('${s.measures}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: p.ink)),
          ),
          _stepBtn(p, '+', s.measures < 4,
              () => c.updateSettings(s.copyWith(measures: s.measures + 1))),
        ],
      ),
    );
  }

  Widget _stepBtn(Palette p, String label, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 38,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 16, color: enabled ? p.accent : p.line)),
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
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(values[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: values[i] == selected ? p.accentSoft : p.surface,
                    border: i > 0
                        ? Border(left: BorderSide(color: p.line))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label(values[i]),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: values[i] == selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color:
                          values[i] == selected ? p.accent : p.muted,
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
