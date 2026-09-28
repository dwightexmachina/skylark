import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:ear_trainer/models/note.dart';
import 'package:ear_trainer/models/round.dart';
import 'package:ear_trainer/models/settings.dart';
import 'package:ear_trainer/state/game_controller.dart';

GameController freshController() {
  web.window.localStorage.clear();
  final c = GameController();
  c.setMode(GameMode.perfectPitch);
  return c;
}

void main() {
  test('a PP round asks ppNotes mysteries drawn from the note set', () {
    final c = freshController();
    c.updateSettings(c.settings.copyWith(ppNotes: 4));
    c.playRound();
    expect(c.phase, Phase.performing);
    expect(c.judged.length, 4);
    for (final j in c.judged) {
      expect(c.settings.noteSet.contains(j.event.pitch!.semitone), isTrue);
      expect(j.revealed, isFalse);
    }
    expect(c.ppReplaysLeft, -1); // beginner: unlimited
  });

  test('answering every note right wins, logs a PP entry, bumps streak', () {
    final c = freshController();
    c.updateSettings(c.settings.copyWith(ppNotes: 3));
    c.playRound();
    final targets = [for (final j in c.judged) j.event.pitch!.semitone];
    for (final t in targets) {
      c.noteOn(t);
      c.noteOff(t);
    }
    expect(c.phase, Phase.summary);
    expect(c.roundPitchCorrect, 3);
    expect(c.streak, 1);
    expect(c.roundLog.length, 1);
    final e = c.roundLog.first;
    expect(e.perfectPitch, isTrue);
    expect(e.won, isTrue);
    expect(e.notes.length, 3);
    // Timing totals stay untouched by PP rounds.
    expect(c.totalTimedEvents, 0);
    expect(c.totalPitchEvents, 3);
  });

  test('a wrong answer records what was played and sets the teaching line',
      () {
    final c = freshController();
    c.updateSettings(c.settings.copyWith(ppNotes: 2));
    c.playRound();
    final t0 = c.judged[0].event.pitch!.semitone;
    // Deliberately answer with a different in-set note.
    final wrong =
        c.settings.noteSet.firstWhere((s) => s != t0, orElse: () => t0);
    c.noteOn(wrong);
    c.noteOff(wrong);
    if (wrong != t0) {
      expect(c.judged[0].verdict, Verdict.wrongPitch);
      expect(c.judged[0].played, Pitch(wrong));
      expect(c.ppFeedback, contains('it was'));
    }
    // Answer the second note correctly and finish.
    final t1 = c.judged[1].event.pitch!.semitone;
    c.noteOn(t1);
    c.noteOff(t1);
    expect(c.phase, Phase.summary);
    expect(c.roundLog.first.won, wrong == t0);
  });

  test('replay budget follows difficulty and hard means none', () {
    final c = freshController();
    c.updateSettings(c.settings
        .withDifficulty(Difficulty.hard)
        .copyWith(ppNotes: 2));
    c.playRound();
    expect(c.ppReplaysLeft, 0);
    c.ppHearAgain(); // must be a no-op
    expect(c.ppReplaysLeft, 0);
  });

  test('skipped PP rounds do not reach the log', () {
    final c = freshController();
    c.playRound();
    c.skip();
    expect(c.phase, Phase.summary);
    expect(c.roundLog, isEmpty);
  });

  test('switching modes resets the board', () {
    final c = freshController();
    c.playRound();
    c.setMode(GameMode.training);
    expect(c.phase, Phase.idle);
    expect(c.judged, isEmpty);
    expect(c.perfectPitch, isFalse);
  });
}
