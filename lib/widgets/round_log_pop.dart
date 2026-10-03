import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/round.dart';
import '../state/game_controller.dart';
import '../ui/palette.dart';
import 'cloud_card.dart';

/// "This session's rounds": a cloud pop-up listing every completed training
/// round with the target melody, what the user played, and the result.
/// Lives in memory only — a page refresh clears it.
class RoundLogPop extends StatelessWidget {
  final GameController controller;
  final VoidCallback onDismiss;

  const RoundLogPop(
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
              maxWidth: 740,
              maxHeight: MediaQuery.of(context).size.height * 0.82,
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
    final log = controller.roundLog;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text("This session's rounds",
                style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: p.ink)),
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
        const SizedBox(height: 10),
        _aggregate(p),
        const SizedBox(height: 12),
        if (log.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: Text(
              'No rounds yet — press Play round and give one a try!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: p.muted),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: log.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) => _row(p, log[i]),
            ),
          ),
      ],
    );
  }

  Widget _aggregate(Palette p) {
    final log = controller.roundLog;
    final pitchTotal = log.fold(0, (a, e) => a + e.pitchTotal);
    final pitchCorrect = log.fold(0, (a, e) => a + e.pitchCorrect);
    final onTime = log.fold(0, (a, e) => a + e.onTime);
    final pairEntries = log.where((e) => e.pairDrill);
    final pairTotal = pairEntries.fold(0, (a, e) => a + e.pairTotal);
    final pairCorrect = pairEntries.fold(0, (a, e) => a + e.pairCorrect);
    final focus = controller.settings.focusPair;
    final pairLabel = focus.length == 2
        ? focus.map((s) => Pitch(s).label).join(' ↔ ')
        : (pairEntries.isNotEmpty
            ? pairEntries.first.focusPairLabels.join(' ↔ ')
            : '');
    TextStyle cap() => TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: p.muted);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ROUNDS WON', style: cap()),
          const SizedBox(height: 2),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: '${controller.roundsWon}',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: p.ink)),
            TextSpan(
                text: ' / ${log.length}',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.muted)),
          ])),
        ]),
        Container(
            width: 2,
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: p.line),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('NOTES', style: cap()),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '$pitchCorrect/$pitchTotal',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.good)),
              TextSpan(text: ' right pitch  ·  '),
              TextSpan(
                  text: '$onTime/$pitchTotal',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.warn)),
              TextSpan(text: ' on time'),
            ], style: TextStyle(fontSize: 12.5, color: p.ink))),
            const SizedBox(height: 1),
            Text('Clears when you refresh the page.',
                style: TextStyle(fontSize: 11, color: p.muted)),
          ]),
        ),
        if (pairTotal > 0) ...[
          Container(
              width: 2,
              height: 38,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: p.line),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$pairLabel ACCURACY', style: cap().copyWith(color: p.tonic)),
            const SizedBox(height: 2),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '$pairCorrect',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: p.tonic)),
              TextSpan(
                  text: ' / $pairTotal',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.muted)),
            ])),
          ]),
        ],
      ]),
    );
  }

  Widget _row(Palette p, RoundLogEntry e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.soft.withValues(alpha: p.isNight ? 0.55 : 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(
          width: 24,
          child: Text('${e.number}',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: p.muted)),
        ),
        const SizedBox(width: 9),
        Container(
          width: 74,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: e.won ? p.goodSoft : p.badSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Text(e.won ? 'Perfect' : 'Lost',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: e.won ? p.good : p.bad)),
        ),
        if (e.perfectPitch) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Perfect Pitch round',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: p.tonicSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('PP',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: p.tonic)),
            ),
          ),
        ],
        if (e.pairDrill) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Pair Drill round',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: p.tonicSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_compactPair(e.focusPairLabels),
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: p.tonic)),
            ),
          ),
        ],
        if (e.echo) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: 'Echo round',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: p.tonicSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('×${e.echoNoteCount}',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: p.tonic)),
            ),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: e.echoRounds == null
              ? Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final n in e.notes)
                      _chip(p, n.target, _ChipKind.target,
                          ringed: e.focusPairLabels.contains(n.target)),
                    Text('→',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.muted)),
                    for (final n in e.notes)
                      _playedChip(p, n,
                          ringed: e.focusPairLabels.contains(n.target)),
                  ],
                )
              : _echoGroups(p, e.echoRounds!),
        ),
      ]),
    );
  }

  /// Echo's grouped layout: one cluster of position-numbered chip-pairs per
  /// round in the batch, with a thin divider between consecutive rounds.
  Widget _echoGroups(Palette p, List<List<LoggedNote>> rounds) {
    final children = <Widget>[];
    for (var g = 0; g < rounds.length; g++) {
      if (g > 0) {
        children.add(Container(width: 1.5, height: 42, color: p.line));
      }
      children.add(Wrap(
        spacing: 6,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < rounds[g].length; i++)
            _echoPosition(p, rounds[g][i], i + 1),
        ],
      ));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _echoPosition(Palette p, LoggedNote n, int position) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _chip(p, n.target, _ChipKind.target),
        const SizedBox(height: 3),
        _playedChip(p, n),
        const SizedBox(height: 2),
        Text('$position',
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: p.muted)),
      ],
    );
  }

  /// "E4"/"F4" → "E⇄F": compact enough for the round badge, sharps kept
  /// since they're the whole point of a confusable pair.
  String _compactPair(List<String> labels) =>
      labels.map((l) => l.replaceAll(RegExp(r'[0-9]'), '')).join('⇄');

  Widget _playedChip(Palette p, LoggedNote n, {bool ringed = false}) =>
      switch (n.verdict) {
        Verdict.good => _chip(p, n.target, _ChipKind.good, ringed: ringed),
        Verdict.offTime => _chip(p, n.target, _ChipKind.late, ringed: ringed),
        Verdict.wrongPitch =>
          _chip(p, n.played ?? '?', _ChipKind.wrong, ringed: ringed),
        _ => _chip(p, '–', _ChipKind.missed, ringed: ringed),
      };

  Widget _chip(Palette p, String label, _ChipKind kind, {bool ringed = false}) {
    final (bg, fg, border) = switch (kind) {
      _ChipKind.target => (
          p.isNight ? p.skyMid : p.soft,
          p.staffInk,
          p.isNight ? null : p.line
        ),
      _ChipKind.good => (p.goodSoft, p.good, null),
      _ChipKind.late => (p.warnSoft, p.warn, null),
      _ChipKind.wrong => (p.badSoft, p.bad, null),
      _ChipKind.missed => (Colors.transparent, p.muted, p.line),
    };
    final resolvedBorder = ringed
        ? Border.all(color: p.tonic, width: 2)
        : (border != null ? Border.all(color: border, width: 1.5) : null);
    return Container(
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: resolvedBorder,
      ),
      // Center vertically but shrink-wrap horizontally; a Container with
      // `alignment` would balloon to Wrap's full width instead.
      child: Center(
        widthFactor: 1,
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}

enum _ChipKind { target, good, late, wrong, missed }
