import 'package:flutter/material.dart';

import '../models/note.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';
import 'cloud_card.dart';

/// "Notes Frequency": a cloud pop-up with one slider per enabled note,
/// setting the weighted-random odds Echo's generator draws from. A note's
/// chance of being picked is its value over the sum of every value shown —
/// dragging any slider changes everyone else's share, so every percentage
/// updates live. Lives entirely off [Settings.noteWeights]; no widget state.
class NotesFrequencyPopup extends StatelessWidget {
  final GameController controller;
  final VoidCallback onDismiss;

  const NotesFrequencyPopup(
      {super.key, required this.controller, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: ColoredBox(
                color: p.isNight
                    ? const Color(0xFF06091C).withValues(alpha: 0.5)
                    : const Color(0xFF1E325A).withValues(alpha: 0.35)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.of(context).size.height * 0.86,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomPaint(
                painter:
                    CloudCardPainter(fill: p.surface, shadow: p.cardShadow),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      24, CloudCardPainter.bandVisible + 12, 24, 20),
                  child: _content(p),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _content(Palette p) {
    final s = controller.settings;
    final notes = s.noteSet.toList()..sort();
    final weights = [for (final n in notes) s.noteWeights[n] ?? 5];
    final total = weights.fold(0, (a, b) => a + b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notes Frequency',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
                const SizedBox(height: 3),
                Text(
                  'Drag a note\'s slider up to hear it more often, down to '
                  'hear it less. Only enabled notes are listed.',
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text('✕',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: p.muted)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _shareBar(p, weights, total),
        const SizedBox(height: 4),
        Text('Relative share, left to right — same order as the rows below.',
            style: TextStyle(fontSize: 10.5, color: p.muted)),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < notes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _row(p, notes[i], weights[i], total),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Each note\'s chance = its value ÷ the total of every value '
                'shown ($total here).',
                style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => controller
                  .updateSettings(s.copyWith(noteWeights: const {})),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: p.soft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Reset to equal',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: p.ink)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shareBar(Palette p, List<int> weights, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 9,
        child: Row(
          children: [
            for (var i = 0; i < weights.length; i++)
              Expanded(
                flex: weights[i],
                child: Container(
                    color: i.isEven ? p.accent : p.tonic,
                    margin: EdgeInsets.only(right: i == weights.length - 1 ? 0 : 1)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(Palette p, int semitone, int weight, int total) {
    final pct = total == 0 ? 0 : (100 * weight / total).round();
    return Row(children: [
      SizedBox(
        width: 42,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(Pitch(semitone).label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: p.ink)),
        ),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: p.tonicSoft,
            inactiveTrackColor: p.soft,
            thumbColor: p.accent,
            overlayColor: p.accentSoft.withValues(alpha: 0.5),
            trackHeight: 6,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            value: weight.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => controller.updateSettings(
              controller.settings.copyWith(noteWeights: {
                ...controller.settings.noteWeights,
                semitone: v.round(),
              }),
            ),
          ),
        ),
      ),
      SizedBox(
        width: 18,
        child: Text('$weight',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: p.muted)),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 38,
        child: Text('$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: p.tonic)),
      ),
    ]);
  }
}
