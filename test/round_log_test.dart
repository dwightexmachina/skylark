import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ear_trainer/models/round.dart';
import 'package:ear_trainer/state/game_controller.dart';
import 'package:ear_trainer/state/theme_controller.dart';
import 'package:ear_trainer/widgets/round_log_pop.dart';

RoundLogEntry entry(int n, bool won,
    {List<LoggedNote>? notes, int correct = 4, int onTime = 4}) {
  return RoundLogEntry(
    number: n,
    won: won,
    notes: notes ??
        const [
          LoggedNote(target: 'C4', verdict: Verdict.good),
          LoggedNote(target: 'E4', verdict: Verdict.offTime),
          LoggedNote(target: 'G4', verdict: Verdict.wrongPitch, played: 'E4'),
          LoggedNote(target: 'E4', verdict: Verdict.missed),
        ],
    pitchCorrect: correct,
    onTime: onTime,
    pitchTotal: 4,
  );
}

Widget host(GameController c, {VoidCallback? onDismiss}) => MaterialApp(
      home: Scaffold(
        body: RoundLogPop(controller: c, onDismiss: onDismiss ?? () {}),
      ),
    );

void main() {
  testWidgets('empty log shows the friendly empty state', (tester) async {
    final c = GameController();
    await tester.pumpWidget(host(c));
    expect(find.textContaining('No rounds yet'), findsOneWidget);
    expect(find.text('Perfect'), findsNothing);
  });

  testWidgets('rows show result badges, chips, and the aggregate',
      (tester) async {
    final c = GameController();
    c.roundLog.insert(0, entry(1, true, notes: const [
      LoggedNote(target: 'C4', verdict: Verdict.good),
      LoggedNote(target: 'E4', verdict: Verdict.good),
      LoggedNote(target: 'G4', verdict: Verdict.good),
      LoggedNote(target: 'E4', verdict: Verdict.good),
    ]));
    c.roundLog.insert(0, entry(2, false, correct: 2, onTime: 1));
    await tester.pumpWidget(host(c));

    // Result badges: one Perfect, one Lost.
    expect(find.text('Perfect'), findsOneWidget);
    expect(find.text('Lost'), findsOneWidget);
    // Aggregate: 1 of 2 rounds won; note totals summed over entries.
    expect(find.text('1 / 2', findRichText: true), findsOneWidget);
    expect(find.textContaining('6/8', findRichText: true),
        findsOneWidget); // right pitch
    expect(find.textContaining('5/8', findRichText: true),
        findsOneWidget); // on time
    expect(find.textContaining('Clears when you refresh'), findsOneWidget);
    // The wrong-pitch chip shows what the user actually played,
    // and the missed note renders as a dash.
    expect(find.text('–'), findsOneWidget);
    // Chips shrink-wrap: everything in a row sits on one line.
    final c4 = tester.getCenter(find.text('C4').first);
    final dash = tester.getCenter(find.text('–').first);
    expect((c4.dy - dash.dy).abs(), lessThan(1.0),
        reason: 'target and played chips should share one line');
    expect(tester.getSize(find.text('C4').first).width, lessThan(30));
  });

  testWidgets('tapping the scrim dismisses', (tester) async {
    final c = GameController();
    var dismissed = false;
    await tester.pumpWidget(host(c, onDismiss: () => dismissed = true));
    await tester.tapAt(const Offset(5, 5));
    expect(dismissed, isTrue);
  });

  testWidgets('renders in night mode without contrast-losing crashes',
      (tester) async {
    ThemeController.instance.setNight(true);
    addTearDown(() => ThemeController.instance.setNight(false));
    final c = GameController();
    c.roundLog.insert(0, entry(1, false, correct: 2, onTime: 1));
    await tester.pumpWidget(host(c));
    expect(find.text('Lost'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
