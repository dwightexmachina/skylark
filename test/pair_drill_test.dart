import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:ear_trainer/models/round.dart';
import 'package:ear_trainer/models/settings.dart';
import 'package:ear_trainer/state/game_controller.dart';

GameController freshPairDrillController({Set<int> focusPair = const {4, 5}}) {
  web.window.localStorage.clear();
  final c = GameController();
  c.setMode(GameMode.pairDrill);
  c.updateSettings(c.settings.copyWith(focusPair: focusPair));
  return c;
}

/// Answer the current mystery note, then let the next one arrive.
void answer(FakeAsync async, GameController c, int semitone) {
  c.noteOn(semitone);
  c.noteOff(semitone);
  async.elapse(const Duration(milliseconds: 2000));
}

void main() {
  test('playRound refuses to start without exactly two focus notes', () {
    final c = GameController();
    c.setMode(GameMode.pairDrill);
    c.updateSettings(c.settings.copyWith(focusPair: const {})); // E4/F4 is the app default
    c.playRound();
    expect(c.phase, Phase.idle);
    c.updateSettings(c.settings.copyWith(focusPair: {4}));
    c.playRound();
    expect(c.phase, Phase.idle);
    c.dispose();
  });

  test('toggleFocusPair selects up to two and locks the rest', () {
    final c = GameController();
    c.setMode(GameMode.pairDrill);
    c.updateSettings(c.settings.copyWith(focusPair: const {}));
    expect(c.settings.focusPair, isEmpty);
    c.toggleFocusPair(0); // C4
    c.toggleFocusPair(4); // E4
    expect(c.settings.focusPair, {0, 4});
    c.toggleFocusPair(5); // F4 — locked, pair already full
    expect(c.settings.focusPair, {0, 4});
    c.toggleFocusPair(4); // deselect E4
    expect(c.settings.focusPair, {0});
    c.toggleFocusPair(5); // now selectable again
    expect(c.settings.focusPair, {0, 5});
    c.dispose();
  });

  test('toggleFocusPair ignores notes not enabled in the note set', () {
    final c = GameController();
    c.setMode(GameMode.pairDrill);
    c.updateSettings(c.settings.copyWith(focusPair: const {}));
    expect(c.settings.noteSet.contains(9), isFalse); // A4 off by default
    c.toggleFocusPair(9);
    expect(c.settings.focusPair, isEmpty);
    c.dispose();
  });

  test('disabling a focus note cascades it out of the pair', () {
    final c = GameController();
    c.setMode(GameMode.pairDrill);
    c.updateSettings(c.settings.copyWith(focusPair: const {}));
    c.toggleFocusPair(4); // E4
    c.toggleFocusPair(5); // F4
    expect(c.settings.focusPair, {4, 5});
    c.toggleNote(4); // disable E4 in Notes in play
    expect(c.settings.noteSet.contains(4), isFalse);
    expect(c.settings.focusPair, {5});
    c.dispose();
  });

  test('Pair Drill enforces a floor of three enabled notes', () {
    final c = GameController();
    c.setMode(GameMode.pairDrill);
    // Default note set has 6 notes; strip down to exactly 3.
    for (final s in [5, 7, 12]) {
      c.toggleNote(s);
    }
    expect(c.settings.noteSet.length, 3);
    final before = {...c.settings.noteSet};
    c.toggleNote(c.settings.noteSet.first); // would drop to 2 — refused
    expect(c.settings.noteSet, before);
    c.dispose();
  });

  test('the generator never plays the focus pair back-to-back', () {
    fakeAsync((async) {
      final c = freshPairDrillController(focusPair: const {4, 5}); // E4, F4
      c.playRound();
      var previous = c.judged.last.event.pitch!.semitone;
      for (var i = 0; i < 200; i++) {
        answer(async, c, previous);
        final next = c.judged.last.event.pitch!.semitone;
        final bothPairAdjacent = previous != next &&
            {previous, next}.containsAll({4, 5});
        expect(bothPairAdjacent, isFalse,
            reason: 'E4 and F4 played back-to-back at step $i');
        previous = next;
      }
      c.stopPP();
      c.dispose();
    });
  });

  test('higher focus intensity plays the pair more often', () {
    fakeAsync((async) {
      final c = freshPairDrillController(focusPair: const {4, 5});
      c.updateSettings(
          c.settings.copyWith(focusIntensity: FocusIntensity.high));
      c.playRound();
      var pairHits = 0;
      const n = 300;
      for (var i = 0; i < n; i++) {
        final semitone = c.judged.last.event.pitch!.semitone;
        if (semitone == 4 || semitone == 5) pairHits++;
        answer(async, c, semitone);
      }
      // High intensity targets 80% combined; allow statistical slack.
      expect(pairHits / n, greaterThan(0.6));
      c.stopPP();
      c.dispose();
    });
  });

  test('replay budget follows the dedicated Replays setting', () {
    fakeAsync((async) {
      final c = freshPairDrillController();
      c.updateSettings(c.settings.copyWith(pairReplays: ReplayBudget.none));
      c.playRound();
      expect(c.ppReplaysLeft, 0);
      c.ppHearAgain(); // must be a no-op
      expect(c.ppReplaysLeft, 0);
      c.dispose();
    });
  });

  test('batches commit with pair-specific accuracy on the log entry', () {
    fakeAsync((async) {
      final c = freshPairDrillController(focusPair: const {4, 5}); // E4, F4
      c.updateSettings(c.settings.copyWith(ppNotes: 3));
      c.playRound();
      for (var i = 0; i < 3; i++) {
        final semitone = c.judged.last.event.pitch!.semitone;
        answer(async, c, semitone); // always answer correctly
      }
      final e = c.roundLog.single;
      expect(e.pairDrill, isTrue);
      expect(e.perfectPitch, isFalse);
      expect(e.focusPairLabels.toSet(), {'E4', 'F4'});
      final expectedPairTotal =
          e.notes.where((n) => e.focusPairLabels.contains(n.target)).length;
      expect(e.pairTotal, expectedPairTotal);
      expect(e.pairCorrect, e.pairTotal); // answered everything correctly
      c.dispose();
    });
  });

  test('stopping mid-batch still records partial pair accuracy', () {
    fakeAsync((async) {
      final c = freshPairDrillController(focusPair: const {4, 5});
      c.updateSettings(c.settings.copyWith(ppNotes: 5));
      c.playRound();
      answer(async, c, c.judged.last.event.pitch!.semitone);
      c.stopPP();
      expect(c.phase, Phase.idle);
      final e = c.roundLog.single;
      expect(e.pairDrill, isTrue);
      expect(e.pitchTotal, 1);
      c.dispose();
    });
  });

  test('switching away from Pair Drill commits the partial batch', () {
    fakeAsync((async) {
      final c = freshPairDrillController(focusPair: const {4, 5});
      c.playRound();
      answer(async, c, c.judged.last.event.pitch!.semitone);
      c.setMode(GameMode.training);
      expect(c.phase, Phase.idle);
      expect(c.pairDrill, isFalse);
      expect(c.roundLog.single.pairDrill, isTrue);
      c.dispose();
    });
  });
}
