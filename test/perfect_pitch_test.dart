import 'package:fake_async/fake_async.dart';
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

/// Answer the current mystery note, then let the next one arrive.
void answer(FakeAsync async, GameController c, int semitone) {
  c.noteOn(semitone);
  c.noteOff(semitone);
  async.elapse(const Duration(milliseconds: 2000));
}

void main() {
  test('the stream serves one mystery note at a time from the note set', () {
    fakeAsync((async) {
      final c = freshController();
      c.playRound();
      expect(c.phase, Phase.performing);
      expect(c.judged.length, 1);
      final j = c.judged.single;
      expect(c.settings.noteSet.contains(j.event.pitch!.semitone), isTrue);
      expect(j.revealed, isFalse);
      expect(c.ppReplaysLeft, -1); // beginner: unlimited
    });
  });

  test('right answers bump the per-note streak and batch into the log', () {
    fakeAsync((async) {
      final c = freshController();
      c.updateSettings(c.settings.copyWith(ppNotes: 3));
      c.playRound();
      for (var i = 0; i < 3; i++) {
        answer(async, c, c.judged.last.event.pitch!.semitone);
      }
      // The stream keeps going — a new pending note, no summary.
      expect(c.phase, Phase.performing);
      expect(c.judged.last.verdict, Verdict.pending);
      expect(c.streak, 3);
      expect(c.ppAnswered, 3);
      expect(c.roundLog.length, 1);
      final e = c.roundLog.first;
      expect(e.perfectPitch, isTrue);
      expect(e.won, isTrue);
      expect(e.notes.length, 3);
      // Timing totals stay untouched by Perfect Pitch.
      expect(c.totalTimedEvents, 0);
      expect(c.totalPitchEvents, 3);
      c.dispose();
    });
  });

  test('a wrong answer records what was played and resets the streak', () {
    fakeAsync((async) {
      final c = freshController();
      c.updateSettings(c.settings.copyWith(ppNotes: 2));
      c.playRound();
      answer(async, c, c.judged.last.event.pitch!.semitone);
      expect(c.streak, 1);
      final t = c.judged.last.event.pitch!.semitone;
      final wrong = c.settings.noteSet.firstWhere((s) => s != t);
      answer(async, c, wrong);
      final judged = c.judged[1];
      expect(judged.verdict, Verdict.wrongPitch);
      expect(judged.played, Pitch(wrong));
      expect(c.ppFeedback, contains('it was'));
      expect(c.streak, 0);
      expect(c.roundLog.single.won, isFalse);
      c.dispose();
    });
  });

  test('keys stay silent between mystery notes', () {
    fakeAsync((async) {
      final c = freshController();
      c.playRound();
      final t = c.judged.last.event.pitch!.semitone;
      c.noteOn(t);
      c.noteOff(t);
      // Before the next note arrives, presses neither sound nor judge.
      c.noteOn(t);
      expect(c.heldSemitones, isEmpty);
      expect(c.ppAnswered, 1);
      c.dispose();
    });
  });

  test('replay budget follows difficulty and hard means none', () {
    fakeAsync((async) {
      final c = freshController();
      c.updateSettings(c.settings.withDifficulty(Difficulty.hard));
      c.playRound();
      expect(c.ppReplaysLeft, 0);
      c.ppHearAgain(); // must be a no-op
      expect(c.ppReplaysLeft, 0);
      c.dispose();
    });
  });

  test('stopping mid-batch logs the partial set, drops the pending note', () {
    fakeAsync((async) {
      final c = freshController();
      c.updateSettings(c.settings.copyWith(ppNotes: 5));
      c.playRound();
      answer(async, c, c.judged.last.event.pitch!.semitone);
      answer(async, c, c.judged.last.event.pitch!.semitone);
      c.stopPP();
      expect(c.phase, Phase.idle);
      expect(c.judged.length, 2); // unanswered note gone, no miss penalty
      expect(c.streak, 2);
      final e = c.roundLog.single;
      expect(e.pitchTotal, 2);
      expect(e.won, isTrue);
      c.dispose();
    });
  });

  test('stopping with nothing answered logs nothing', () {
    fakeAsync((async) {
      final c = freshController();
      c.playRound();
      c.stopPP();
      expect(c.phase, Phase.idle);
      expect(c.roundLog, isEmpty);
      c.dispose();
    });
  });

  test('switching modes commits the partial batch and resets the board', () {
    fakeAsync((async) {
      final c = freshController();
      c.playRound();
      answer(async, c, c.judged.last.event.pitch!.semitone);
      c.setMode(GameMode.training);
      expect(c.phase, Phase.idle);
      expect(c.judged, isEmpty);
      expect(c.perfectPitch, isFalse);
      expect(c.streak, 0);
      expect(c.roundLog.single.pitchTotal, 1);
      c.dispose();
    });
  });
}
