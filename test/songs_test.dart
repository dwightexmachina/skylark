import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import 'package:ear_trainer/logic/songs.dart';
import 'package:ear_trainer/models/note.dart';
import 'package:ear_trainer/models/round.dart';
import 'package:ear_trainer/state/game_controller.dart';
import 'package:ear_trainer/widgets/result_pop.dart';
import 'package:ear_trainer/widgets/round_log_pop.dart';
import 'package:ear_trainer/widgets/settings_panel.dart';
import 'package:ear_trainer/widgets/staff.dart';

GameController freshController() {
  web.window.localStorage.clear();
  return GameController();
}

void main() {
  // ------------------------------------------------------------ song data
  // Songs ride the Training timeline, whose notation and audio only handle a
  // narrow slice of music. These guard that slice: a song that violates one
  // of them would render or sound wrong rather than throw, so the data is
  // where it has to be caught.

  group('every song fits what the app can express', () {
    for (final song in kSongs) {
      test('${song.name}: bars are full and contiguous', () {
        var beat = 0.0;
        for (final e in song.events) {
          expect(e.startBeat, beat,
              reason: 'a gap or overlap before ${e.startBeat}');
          beat += e.durationBeats;
        }
        // 4/4 only, plus any anacrusis: anything short would leave the
        // metronome running past the last note.
        expect(beat, song.measures * 4.0 + song.pickupBeats);
        expect(beat, song.melody.totalBeats);
      });

      test('${song.name}: the pickup is a whole number of beats', () {
        // The metronome accents on `(beat - pickup) % 4`, so a fractional
        // pickup would drift the downbeat off the click.
        expect(song.pickupBeats, song.pickupBeats.roundToDouble());
        expect(song.pickupBeats, lessThan(4));
        expect(song.pickupBeats, greaterThanOrEqualTo(0));
      });

      test('${song.name}: only eighths, quarters and halves', () {
        for (final e in song.events) {
          expect([0.5, 1.0, 2.0], contains(e.durationBeats));
          // The staff draws every rest as a quarter rest regardless of
          // length, so a rest of any other duration would notate a lie.
          if (e.isRest) expect(e.durationBeats, 1.0);
        }
      });

      test('${song.name}: stays inside C4–C5 and starts on beat 1', () {
        for (final e in song.events) {
          if (e.isRest) continue;
          expect(e.pitch!.semitone, inInclusiveRange(0, semitoneCount - 1));
        }
        // Event beats run from the first sounding note — the pickup when
        // there is one — so beat 0 is always a note, never a rest or a gap.
        expect(song.events.first.startBeat, 0.0);
        expect(song.events.first.isRest, isFalse);
        expect(song.melody.pitchEvents.length, greaterThanOrEqualTo(2));
      });

      test('${song.name}: eighths come in on-beat beamed pairs', () {
        final events = song.events;
        for (var i = 0; i < events.length; i++) {
          final e = events[i];
          if (e.durationBeats != 0.5) {
            expect(e.beamWithNext, isFalse,
                reason: 'only eighths beam');
            continue;
          }
          final onBeat = e.startBeat == e.startBeat.floorToDouble();
          if (onBeat) {
            // First of a pair: must be beamed to an eighth that follows.
            expect(e.beamWithNext, isTrue);
            expect(events[i + 1].durationBeats, 0.5);
          } else {
            // Second of a pair: never beams onward.
            expect(e.beamWithNext, isFalse);
            expect(events[i - 1].durationBeats, 0.5);
          }
        }
      });

      test('${song.name}: playable on the forced keyboard', () {
        expect(kSongsNoteSet.containsAll(song.semitones), isTrue,
            reason: 'needs ${song.noteLabels}, keyboard has $kSongsNoteSet');
      });
    }
  });

  test('the library is ordered easiest first by note count', () {
    final counts = [for (final s in kSongs) s.semitones.length];
    for (var i = 1; i < counts.length; i++) {
      expect(counts[i], greaterThanOrEqualTo(counts[i - 1]),
          reason: '${kSongs[i].name} uses fewer notes than the song before it');
    }
  });

  test('the forced keyboard is exactly what the library needs', () {
    // Derived, not hardcoded. The library reaches the full C major octave.
    expect(kSongsNoteSet, {0, 2, 4, 5, 7, 9, 11, 12});
  });

  test('every song is diatonic C major — no accidentals anywhere', () {
    const blackKeys = {1, 3, 6, 8, 10};
    for (final song in kSongs) {
      for (final s in song.semitones) {
        expect(blackKeys.contains(s), isFalse,
            reason: '${song.name} uses ${Pitch(s).label}, which is not in C');
      }
    }
  });

  // ------------------------------------------------------------ controller

  test('Songs takes over the keyboard and gives it back on the way out', () {
    final c = freshController();
    final before = c.settings.noteSet;
    expect(before, isNot(kSongsNoteSet)); // the Echo default lacks A

    c.setMode(GameMode.songs);
    expect(c.settings.noteSet, kSongsNoteSet);

    // The tune decides the keys while Songs is selected.
    c.toggleNote(1);
    expect(c.settings.noteSet, kSongsNoteSet);

    c.setMode(GameMode.training);
    expect(c.settings.noteSet, before);
    c.dispose();
  });

  test('a round plays the selected tune, not a generated melody', () {
    final c = freshController();
    c.setMode(GameMode.songs);
    c.updateSettings(c.settings.copyWith(songIndex: 2));
    final song = kSongs[2];
    expect(c.song.name, song.name);

    c.playRound();
    expect(c.melody!.events, song.events);
    expect(c.melody!.measures, song.measures);
    expect(c.roundPitchTotal, song.melody.pitchEvents.length);
    c.dispose();
  });

  test('replaying a song round keeps the same tune', () {
    final c = freshController();
    c.setMode(GameMode.songs);
    c.playRound();
    final first = c.melody!.events;
    c.replay();
    expect(c.melody!.events, first);
    c.dispose();
  });

  test('an out-of-range song index clamps instead of throwing', () {
    final c = freshController();
    c.setMode(GameMode.songs);
    c.updateSettings(c.settings.copyWith(songIndex: 99));
    expect(c.song, kSongs.last);
    c.dispose();
  });

  test('picking a different song clears the finished one off the board', () {
    final c = freshController();
    c.setMode(GameMode.songs);
    c.playRound();
    expect(c.melody, isNotNull);
    c.skip(); // stand in for the round running to its end
    expect(c.phase, Phase.summary);

    c.updateSettings(c.settings.copyWith(songIndex: 3));
    expect(c.song, kSongs[3]);
    expect(c.phase, Phase.idle);
    expect(c.melody, isNull, reason: 'stale notes would sit under a new title');
    expect(c.judged, isEmpty);
    c.dispose();
  });

  test('re-picking the song already selected leaves the board alone', () {
    final c = freshController();
    c.setMode(GameMode.songs);
    c.playRound();
    c.skip();
    c.updateSettings(c.settings.copyWith(bpm: 96)); // same songIndex
    expect(c.phase, Phase.summary);
    expect(c.melody, isNotNull);
    c.dispose();
  });

  // --------------------------------------------------------------- pickups

  test('pickup support is actually exercised by the library', () {
    final withPickup = kSongs.where((s) => s.pickupBeats > 0).toList();
    expect(withPickup, isNotEmpty);
    for (final s in withPickup) {
      // The lead-in events must exactly fill the anacrusis — a note straddling
      // the downbeat would put the barline through the middle of it.
      var beat = 0.0;
      var landsOnDownbeat = false;
      for (final e in s.events) {
        if (beat == s.pickupBeats) landsOnDownbeat = true;
        beat += e.durationBeats;
      }
      expect(landsOnDownbeat, isTrue,
          reason: '${s.name} has no event starting on the downbeat');
    }
  });

  test('a pickup song carries its anacrusis into the round', () {
    final c = freshController();
    c.setMode(GameMode.songs);
    final i = kSongs.indexWhere((s) => s.pickupBeats > 0);
    c.updateSettings(c.settings.copyWith(songIndex: i));
    c.playRound();
    expect(c.melody!.pickupBeats, kSongs[i].pickupBeats);
    // Timeline offsets derive from totalBeats, so the pickup must be in it.
    expect(c.melody!.totalBeats, kSongs[i].measures * 4 + kSongs[i].pickupBeats);
    c.dispose();
  });

  test('a song without a pickup is unchanged', () {
    final plain = kSongs.firstWhere((s) => s.pickupBeats == 0);
    expect(plain.melody.pickupBeats, 0);
    expect(plain.melody.totalBeats, plain.measures * 4.0);
  });

  testWidgets('the staff renders a pickup melody', (tester) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final song = kSongs.firstWhere((s) => s.pickupBeats > 0);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StaffView(
          judged: [
            for (final e in song.events) JudgedEvent(e)..revealed = true,
          ],
          measures: song.measures,
          playheadBeat: null,
          secondsPerBeat: 0.75,
          pickupBeats: song.pickupBeats,
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  // ----------------------------------------------------------- song picker

  testWidgets('the picker lists every song, scrolls, and shows no note count',
      (tester) async {
    tester.view.physicalSize = const Size(340, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = freshController();
    c.setMode(GameMode.songs);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 306,
          child: SettingsPanel(controller: c, onOpenNotesFrequency: () {}),
        ),
      ),
    ));

    expect(find.text(kSongs.first.name), findsOneWidget);
    // The count badge is gone; the "Notes you'll need" line is not a count.
    expect(find.textContaining(RegExp(r'\d+ notes')), findsNothing);

    // The library outruns its box, so the tail is only reachable by scrolling.
    await tester.scrollUntilVisible(find.text(kSongs.last.name), 80);
    expect(find.text(kSongs.last.name), findsOneWidget);
    c.dispose();
  });

  testWidgets('tapping a song in the picker selects it', (tester) async {
    tester.view.physicalSize = const Size(340, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = freshController();
    c.setMode(GameMode.songs);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 306,
          child: SettingsPanel(controller: c, onOpenNotesFrequency: () {}),
        ),
      ),
    ));

    // Deliberately a song past the fold: proves scroll-then-pick works.
    await tester.scrollUntilVisible(find.text('Ode to Joy'), 80);
    await tester.tap(find.text('Ode to Joy'));
    await tester.pump();
    expect(c.song.name, 'Ode to Joy');
    c.dispose();
  });

  // -------------------------------------------------------------- result pop

  testWidgets('a click passes through the result pop to what is behind it',
      (tester) async {
    // This is what makes picking another song from the result one click
    // instead of two: the pop dims and listens, but never absorbs.
    var dismissed = 0, behind = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Align(
            alignment: Alignment.topLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => behind++,
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
          Positioned.fill(
            child: ResultPop(
              // Single-button tier: the two-button rows overflow the card
              // under the test font, which would fail on an unrelated error.
              tier: ResultTier.perfect,
              pitchCorrect: 4,
              onTime: 4,
              pitchTotal: 4,
              streak: 1,
              songs: true,
              onDismiss: () => dismissed++,
              onNext: () {},
              onReplay: () {},
            ),
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tapAt(const Offset(40, 20)); // over the widget behind
    await tester.pump();
    expect(dismissed, 1);
    expect(behind, 1, reason: 'the press must still reach the control behind');
  });

  testWidgets('the result card itself absorbs clicks', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(children: [
          Positioned.fill(
            child: ResultPop(
              tier: ResultTier.perfect,
              pitchCorrect: 4,
              onTime: 4,
              pitchTotal: 4,
              streak: 1,
              songs: true,
              onDismiss: () => dismissed++,
              onNext: () {},
              onReplay: () {},
            ),
          ),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Perfect!')); // Songs wording, on the card
    await tester.pump();
    expect(dismissed, 0);
  });

  // ------------------------------------------------------------------- log

  testWidgets('a song round is badged with its name in the log',
      (tester) async {
    final c = freshController();
    c.roundLog.insert(
      0,
      const RoundLogEntry(
        number: 1,
        won: true,
        songName: 'Hot Cross Buns',
        notes: [
          LoggedNote(target: 'E4', verdict: Verdict.good),
          LoggedNote(target: 'D4', verdict: Verdict.good),
        ],
        pitchCorrect: 2,
        onTime: 2,
        pitchTotal: 2,
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RoundLogPop(controller: c, onDismiss: () {})),
    ));
    expect(find.text('♫ Hot Cross Buns'), findsOneWidget);
    c.dispose();
  });
}
