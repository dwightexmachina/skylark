import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:ear_trainer/models/round.dart';
import 'package:ear_trainer/models/settings.dart';
import 'package:ear_trainer/state/game_controller.dart';

GameController freshEchoController(
    {int echoNotes = 1, Map<int, int> noteWeights = const {}}) {
  web.window.localStorage.clear();
  final c = GameController();
  c.setMode(GameMode.echo);
  c.updateSettings(
      c.settings.copyWith(echoNotes: echoNotes, noteWeights: noteWeights));
  return c;
}

/// Answer the current mystery note (Echo at one note per round degenerates
/// to exactly this Perfect-Pitch-style flow), then let the next one arrive.
void answer(FakeAsync async, GameController c, int semitone) {
  c.noteOn(semitone);
  c.noteOff(semitone);
  async.elapse(const Duration(milliseconds: 2000));
}

/// Press a run of notes back-to-back with no gap — used once a multi-note
/// Echo round has already finished playing and is waiting on the full
/// sequence of answers.
void pressNotes(GameController c, List<int> semitones) {
  for (final s in semitones) {
    c.noteOn(s);
    c.noteOff(s);
  }
}

/// Let a multi-note Echo round finish playing (or a completed round's
/// inter-round pause elapse and the next round start playing) — generous
/// enough to cover any note count 1-5 plus the longest inter-round delay.
void settle(FakeAsync async) => async.elapse(const Duration(milliseconds: 5000));

void main() {
  test('Echo defaults', () {
    final c = GameController();
    expect(c.settings.echoNotes, 1);
    expect(c.settings.noteWeights, isEmpty);
    expect(c.settings.echoReplays, ReplayBudget.one);
    expect(c.settings.echoNoteLag, 0.5);
    c.dispose();
  });

  test('echoNoteLag paces round playback: keys stay silent until it elapses',
      () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 2);
      c.updateSettings(c.settings.copyWith(echoNoteLag: 1.5));
      c.playRound();
      // Default pacing (0.5s lag) would easily have finished a 2-note round
      // by now; a 1.5s lag should not have. Each note is held for the full
      // 1.5s lag, so total playback is ~3.15s (0.15s lead-in + 2 * 1.5s).
      async.elapse(const Duration(milliseconds: 900));
      expect(c.echoListening, isTrue);
      async.elapse(const Duration(milliseconds: 2500));
      expect(c.echoListening, isFalse);
      c.stopPP();
      c.dispose();
    });
  });

  test('toggleNote cascades a disabled note out of noteWeights', () {
    final c = GameController();
    c.setMode(GameMode.echo);
    c.updateSettings(
        c.settings.copyWith(noteWeights: const {0: 8, 2: 3, 4: 9}));
    c.toggleNote(0); // disable C4
    expect(c.settings.noteSet.contains(0), isFalse);
    expect(c.settings.noteWeights.containsKey(0), isFalse);
    expect(c.settings.noteWeights[2], 3); // untouched
    expect(c.settings.noteWeights[4], 9); // untouched
    c.dispose();
  });

  test('the weighted generator favors notes with higher Notes Frequency values',
      () {
    fakeAsync((async) {
      final c = freshEchoController(
          echoNotes: 1, noteWeights: const {0: 40}); // others default to 5
      c.playRound();
      var hits = 0;
      const n = 300;
      for (var i = 0; i < n; i++) {
        final semitone = c.judged.last.event.pitch!.semitone;
        if (semitone == 0) hits++;
        answer(async, c, semitone);
      }
      // total weight = 40 + 5*5 = 65; expected share for note 0 is ~0.615.
      expect(hits / n, greaterThan(0.45));
      c.stopPP();
      c.dispose();
    });
  });

  test('a swapped pair scores both positions wrong, never partial credit', () {
    fakeAsync((async) {
      GameController? c;
      List<int> targets = const [];
      for (var attempt = 0; attempt < 30; attempt++) {
        c?.dispose();
        c = freshEchoController(echoNotes: 3);
        c.playRound();
        settle(async);
        targets = [for (var i = 0; i < 3; i++) c.judged[i].event.pitch!.semitone];
        if (targets[0] != targets[1]) break;
        c.stopPP();
      }
      expect(targets[0], isNot(targets[1]),
          reason: 'could not find a round with distinct first two targets');

      // Swap positions 0 and 1; answer position 2 correctly.
      pressNotes(c!, [targets[1], targets[0], targets[2]]);

      final e = c.roundLog.single;
      expect(e.echoRounds!.single.length, 3);
      expect(e.notes[0].verdict, Verdict.wrongPitch);
      expect(e.notes[1].verdict, Verdict.wrongPitch);
      expect(e.notes[2].verdict, Verdict.good);
      c.dispose();
    });
  });

  test('batches at one note per round: 5 answered notes commit one flat log entry',
      () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 1);
      c.playRound();
      for (var i = 0; i < 5; i++) {
        answer(async, c, c.judged.last.event.pitch!.semitone);
      }
      final e = c.roundLog.single;
      expect(e.echo, isTrue);
      expect(e.echoNoteCount, 1);
      expect(e.echoRounds, isNull); // flat rendering, exactly like PP
      expect(e.pitchTotal, 5);
      c.stopPP();
      c.dispose();
    });
  });

  test('batches two rounds per log entry at two notes per round', () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 2);
      c.playRound();
      settle(async);
      pressNotes(c, [
        c.judged[0].event.pitch!.semitone,
        c.judged[1].event.pitch!.semitone,
      ]);
      expect(c.roundLog, isEmpty); // only 1 of 2 rounds done — not yet committed
      settle(async);
      pressNotes(c, [
        c.judged[2].event.pitch!.semitone,
        c.judged[3].event.pitch!.semitone,
      ]);
      final e = c.roundLog.single;
      expect(e.echoRounds!.length, 2);
      expect(e.notes.length, 4);
      c.dispose();
    });
  });

  test('batches one round per log entry at three or more notes per round', () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 3);
      c.playRound();
      settle(async);
      pressNotes(c, [
        c.judged[0].event.pitch!.semitone,
        c.judged[1].event.pitch!.semitone,
        c.judged[2].event.pitch!.semitone,
      ]);
      final e = c.roundLog.single;
      expect(e.echoRounds!.length, 1);
      expect(e.notes.length, 3);
      c.dispose();
    });
  });

  test('stopping mid-round discards the incomplete round but keeps completed ones',
      () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 2);
      c.playRound();
      settle(async);
      pressNotes(c, [
        c.judged[0].event.pitch!.semitone,
        c.judged[1].event.pitch!.semitone,
      ]); // round 1 complete
      settle(async); // round 2 starts and finishes playing
      final secondRoundFirstTarget = c.judged[2].event.pitch!.semitone;
      c.noteOn(secondRoundFirstTarget);
      c.noteOff(secondRoundFirstTarget); // round 2 left incomplete
      c.stopPP();
      expect(c.phase, Phase.idle);
      final e = c.roundLog.single;
      expect(e.echoRounds!.length, 1); // only the completed round survives
      expect(e.notes.length, 2);
      c.dispose();
    });
  });

  test('hear-again replays the whole round when called before the first answer',
      () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 3);
      c.updateSettings(c.settings.copyWith(echoReplays: ReplayBudget.one));
      c.playRound();
      settle(async);
      expect(c.ppReplaysLeft, 1);
      c.ppHearAgain();
      expect(c.ppReplaysLeft, 0);
      expect(c.echoListening, isTrue); // mid-replay
      c.dispose();
    });
  });

  test('hear-again is a no-op once the round has a first answer', () {
    fakeAsync((async) {
      final c = freshEchoController(echoNotes: 3);
      c.updateSettings(c.settings.copyWith(echoReplays: ReplayBudget.unlimited));
      c.playRound();
      settle(async);
      final target0 = c.judged[0].event.pitch!.semitone;
      c.noteOn(target0);
      c.noteOff(target0);
      expect(c.echoAnsweredInRound, 1);
      c.ppHearAgain();
      expect(c.echoListening, isFalse); // guard blocked the replay
      c.dispose();
    });
  });
}
