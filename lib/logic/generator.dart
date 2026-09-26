import 'dart:math';

import '../models/note.dart';
import '../models/settings.dart';

/// Generates a melody in 4/4 from the selected note set.
/// Rhythmic vocabulary: half notes, quarter notes, beamed eighth pairs,
/// and quarter rests. Eighths always start on the beat, so beaming is trivial.
Melody generateMelody(Settings settings, Random rng) {
  final pool = settings.noteSet.toList()..sort();
  assert(pool.length >= 2, 'Need at least two selected notes');

  for (var attempt = 0; attempt < 20; attempt++) {
    final events = <NoteEvent>[];
    var beat = 0.0;
    int? prevSemitone;
    var lastWasRest = false;

    Pitch nextPitch() {
      var s = pool[rng.nextInt(pool.length)];
      // Discourage (but don't forbid) immediate repeats.
      if (s == prevSemitone && rng.nextDouble() < 0.6) {
        s = pool[rng.nextInt(pool.length)];
      }
      prevSemitone = s;
      return Pitch(s);
    }

    for (var m = 0; m < settings.measures; m++) {
      var remaining = 4.0;
      while (remaining > 0) {
        final isFirstEvent = events.isEmpty;
        final hard = settings.difficulty == Difficulty.hard;
        // (weight, builder) choices valid right now.
        final choices = <(double, void Function())>[
          (3.0, () {
            events.add(NoteEvent(
                startBeat: beat, durationBeats: 1, pitch: nextPitch()));
            beat += 1;
            remaining -= 1;
            lastWasRest = false;
          }),
          if (settings.allowEighths)
            (hard ? 3.5 : 2.0, () {
              events.add(NoteEvent(
                  startBeat: beat,
                  durationBeats: 0.5,
                  pitch: nextPitch(),
                  beamWithNext: true));
              events.add(NoteEvent(
                  startBeat: beat + 0.5,
                  durationBeats: 0.5,
                  pitch: nextPitch()));
              beat += 1;
              remaining -= 1;
              lastWasRest = false;
            }),
          if (settings.allowHalves && remaining >= 2)
            (1.5, () {
              events.add(NoteEvent(
                  startBeat: beat, durationBeats: 2, pitch: nextPitch()));
              beat += 2;
              remaining -= 2;
              lastWasRest = false;
            }),
          if (settings.allowRests && !isFirstEvent && !lastWasRest)
            (hard ? 2.2 : 1.5, () {
              events.add(NoteEvent(startBeat: beat, durationBeats: 1));
              beat += 1;
              remaining -= 1;
              lastWasRest = true;
            }),
        ];
        final total = choices.fold(0.0, (a, c) => a + c.$1);
        var roll = rng.nextDouble() * total;
        for (final (w, build) in choices) {
          roll -= w;
          if (roll <= 0) {
            build();
            break;
          }
        }
      }
    }

    // A round should ask for at least two pitches and not end on a rest.
    final melody = Melody(events, settings.measures);
    if (melody.pitchEvents.length >= 2 && !events.last.isRest) return melody;
  }

  // Fallback (practically unreachable): a plain quarter-note melody.
  final events = [
    for (var b = 0; b < settings.measures * 4; b++)
      NoteEvent(
          startBeat: b.toDouble(),
          durationBeats: 1,
          pitch: Pitch(pool[rng.nextInt(pool.length)])),
  ];
  return Melody(events, settings.measures);
}
