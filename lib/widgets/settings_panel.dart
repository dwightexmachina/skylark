import 'package:flutter/material.dart';

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
            else if (c.pairDrill)
              ..._pairDrillSections(p, c, s)
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
            _head(p, c.perfectPitch ? 'Log grouping' : 'Length'),
            const SizedBox(height: 8),
            _stepper(p, c),
            const SizedBox(height: 6),
            _sub(
                p,
                c.perfectPitch
                    ? 'The Log groups your results into sets of this many notes (1–10).'
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
            // ---------- More settings (Perfect Pitch has none: no rhythm,
            // no timing, no tonic — and tones live next to the instrument).
            if (!c.perfectPitch) ...[
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
            ],
            const SizedBox(height: 16),
            _sub(p,
                'Sounds: Salamander Grand Piano by Alexander Holm (CC-BY 3.0) · FluidR3 soundfont (MIT).'),
          ],
        ),
      ),
    );
  }

  /// Pair Drill's whole sidebar: deliberately separate from the
  /// Training/Perfect Pitch block above — its settings share nothing with
  /// either (no difficulty preset, no tempo, a live pair picker instead).
  List<Widget> _pairDrillSections(Palette p, GameController c, Settings s) {
    return [
      _head(p, 'Notes in play'),
      const SizedBox(height: 8),
      _noteChips(p, c),
      const SizedBox(height: 6),
      _sub(p,
          '${s.noteSet.length} of $semitoneCount selected. At least 3 required for Pair Drill, so there\'s always a decoy.'),
      const SizedBox(height: 20),
      _head(p, 'Choose your pair'),
      const SizedBox(height: 8),
      _pairPicker(p, c),
      const SizedBox(height: 8),
      _pairStatus(p, c),
      const SizedBox(height: 6),
      _sub(p,
          'One button per note enabled above — tap any two to select them, tap a selected one again to drop it. These two come up most often, but never directly next to each other.'),
      const SizedBox(height: 20),
      _head(p, 'Focus intensity'),
      const SizedBox(height: 8),
      _segmented<FocusIntensity>(
        p,
        values: FocusIntensity.values,
        selected: s.focusIntensity,
        label: (f) => f.label,
        onTap: (f) => c.updateSettings(s.copyWith(focusIntensity: f)),
      ),
      const SizedBox(height: 6),
      _sub(p,
          '${s.focusIntensity.label} — about ${(s.focusIntensity.weight * 10).round()} in 10 notes played are your focus pair.'),
      const SizedBox(height: 20),
      _head(p, 'Replays'),
      const SizedBox(height: 8),
      _segmented<ReplayBudget>(
        p,
        values: ReplayBudget.values,
        selected: s.pairReplays,
        label: (r) => r.label,
        onTap: (r) => c.updateSettings(s.copyWith(pairReplays: r)),
      ),
      const SizedBox(height: 6),
      _sub(p, switch (s.pairReplays) {
        ReplayBudget.unlimited => 'Replay the mystery note as often as you like.',
        ReplayBudget.two => 'Two replays per mystery note.',
        ReplayBudget.one => 'One replay per mystery note.',
        ReplayBudget.none => 'One listen only — no replays.',
      }),
      const SizedBox(height: 20),
      _head(p, 'Log grouping'),
      const SizedBox(height: 8),
      _stepper(p, c),
      const SizedBox(height: 6),
      _sub(p, 'The Log groups your results into sets of this many notes (1–10).'),
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

  /// One button per currently-enabled note — the set shrinks and grows
  /// live as "Notes in play" changes, rather than snapshotting a picker.
  Widget _pairPicker(Palette p, GameController c) {
    final notes = c.settings.noteSet.toList()..sort();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [for (final semitone in notes) _pairPill(p, c, semitone)],
    );
  }

  Widget _pairPill(Palette p, GameController c, int semitone) {
    final focus = c.settings.focusPair;
    final selected = focus.contains(semitone);
    final locked = !selected && focus.length >= 2;
    final bg = selected ? p.tonicSoft : p.surface;
    final border = selected ? p.tonic : p.line;
    final fg = selected ? p.tonic : p.muted;
    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: InkWell(
        onTap: locked ? null : () => c.toggleFocusPair(semitone),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            semitone < 12 ? pitchClassLabels[semitone] : Pitch(semitone).label,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ),
    );
  }

  Widget _pairStatus(Palette p, GameController c) {
    final focus = c.settings.focusPair;
    if (focus.length == 2) {
      final labels = focus.map((s) => Pitch(s).label).join(' and ');
      return Row(children: [
        Icon(Icons.check_circle, size: 15, color: p.good),
        const SizedBox(width: 6),
        Expanded(
          child: Text('$labels — ready to play',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: p.good)),
        ),
      ]);
    }
    final msg = focus.isEmpty
        ? 'Pick two notes you mix up — exactly two required'
        : 'Pick one more note — exactly two required';
    return Row(children: [
      Icon(Icons.circle, size: 9, color: p.warn),
      const SizedBox(width: 8),
      Expanded(
        child: Text(msg,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: p.warn)),
      ),
    ]);
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
    final pp = c.perfectPitch || c.pairDrill;
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
