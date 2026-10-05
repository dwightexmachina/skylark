import '../models/note.dart';

/// Skylark's canned tunes: Songs mode feeds one of these to the Training
/// timeline instead of a generated melody, so the whole round flow (tonic,
/// count-in, listen, count-in, play it back in time, pitch + timing judging)
/// is the existing one — only the melody's origin changes.
///
/// Every song here is boxed in by what the app can actually express:
///
///  * 4/4 only — [Melody.totalBeats] is `measures * 4`, and the metronome
///    accents every fourth beat. That rules out everything in 3/4 or 6/8
///    (Happy Birthday, Amazing Grace, Pop Goes the Weasel, most carols).
///  * No pickup bar — a melody starts at beat 0, on a note. That rules out
///    When the Saints, Oh Susanna, and friends.
///  * Pitches inside C4–C5, since [Pitch] asserts `0 ≤ semitone < 13`, so
///    nothing may dip below the tonic however you voice it.
///  * Durations only 0.5, 1 and 2 beats. No dotted notes, no ties, and a
///    rest must be exactly one beat because the staff draws every rest as a
///    quarter rest.
///
/// Several tunes here carry a dotted figure in their canonical form. Each is
/// written in the even-note version used by beginner method books, and the
/// spot is called out in a comment — the melody stays recognizable, which is
/// the whole point of the mode.
///
/// The list is ordered easiest first, by how many distinct pitches the tune
/// asks you to tell apart (3 → 8), and the picker shows it in that order. A
/// test enforces the ordering, so insert new songs in the right band.
class Song {
  final String name;
  final int measures;
  final List<NoteEvent> events;

  const Song(this.name, this.measures, this.events);

  Melody get melody => Melody(events, measures);

  /// The distinct semitones the tune uses, low to high.
  List<int> get semitones {
    final set = {
      for (final e in events)
        if (!e.isRest) e.pitch!.semitone,
    };
    return set.toList()..sort();
  }

  /// Note names for the picker's "notes you'll need" line, e.g. `C D E G`.
  String get noteLabels => [
        for (final s in semitones)
          s < 12 ? pitchClassLabels[s] : Pitch(s).label,
      ].join(' ');
}

/// Marks a rest in the compact `(semitone, beats)` song data below.
const int _rest = -1;

/// Lays out a bar-by-bar `(semitone, beats)` list into [NoteEvent]s, filling
/// in each `startBeat` and beaming on-beat eighth pairs — the only beaming
/// the staff renderer draws.
List<NoteEvent> _layout(List<(int, double)> notes) {
  final events = <NoteEvent>[];
  var beat = 0.0;
  for (var i = 0; i < notes.length; i++) {
    final (semitone, duration) = notes[i];
    final beam = duration == 0.5 &&
        beat == beat.floorToDouble() &&
        i + 1 < notes.length &&
        notes[i + 1].$2 == 0.5;
    events.add(NoteEvent(
      startBeat: beat,
      durationBeats: duration,
      pitch: semitone == _rest ? null : Pitch(semitone),
      beamWithNext: beam,
    ));
    beat += duration;
  }
  return events;
}

// Semitones from C4: C 0 · D 2 · E 4 · F 5 · G 7 · A 9 · B 11 · C5 12.

final List<Song> kSongs = [
  // ----------------------------------------------------------- three notes

  // C C C D | E– D– | C E D D | C– (two quarter rests close the bar, which
  // notates correctly where a four-beat note would draw as a half note).
  Song('Au Clair de la Lune', 4, _layout(const [
    (0, 1), (0, 1), (0, 1), (2, 1),
    (4, 2), (2, 2),
    (0, 1), (4, 1), (2, 1), (2, 1),
    (0, 2), (_rest, 1), (_rest, 1),
  ])),

  // E D C– | E D C– | CC CC DD DD | E D C–
  Song('Hot Cross Buns', 4, _layout(const [
    (4, 1), (2, 1), (0, 2),
    (4, 1), (2, 1), (0, 2),
    (0, 0.5), (0, 0.5), (0, 0.5), (0, 0.5),
    (2, 0.5), (2, 0.5), (2, 0.5), (2, 0.5),
    (4, 1), (2, 1), (0, 2),
  ])),

  // C C D E | C E D– | C C D E | D– C–
  Song('Yankee Doodle', 4, _layout(const [
    (0, 1), (0, 1), (2, 1), (4, 1),
    (0, 1), (4, 1), (2, 2),
    (0, 1), (0, 1), (2, 1), (4, 1),
    (2, 2), (0, 2),
  ])),

  // ------------------------------------------------------------ four notes

  // E D C D | E E E– | D D D– | E G G–
  Song('Mary Had a Little Lamb', 4, _layout(const [
    (4, 1), (2, 1), (0, 1), (2, 1),
    (4, 1), (4, 1), (4, 2),
    (2, 1), (2, 1), (2, 2),
    (4, 1), (7, 1), (7, 2),
  ])),

  // E E E– | E E E– | E G C D | E–
  // Bar 3 ("jingle all the way") is evened out: the canonical line dots the
  // C and shortens the D.
  Song('Jingle Bells', 4, _layout(const [
    (4, 1), (4, 1), (4, 2),
    (4, 1), (4, 1), (4, 2),
    (4, 1), (7, 1), (0, 1), (2, 1),
    (4, 2), (_rest, 1), (_rest, 1),
  ])),

  // ------------------------------------------------------------ five notes

  // G E E– | F D D– | C D E F | G G G–
  // The closing bar is the one transcription here I'd check by ear against a
  // lead sheet; the rest are unambiguous.
  Song('Lightly Row', 4, _layout(const [
    (7, 1), (4, 1), (4, 2),
    (5, 1), (2, 1), (2, 2),
    (0, 1), (2, 1), (4, 1), (5, 1),
    (7, 1), (7, 1), (7, 2),
  ])),

  // C D E C | C D E C | E F G– | E F G–
  Song('Frère Jacques', 4, _layout(const [
    (0, 1), (2, 1), (4, 1), (0, 1),
    (0, 1), (2, 1), (4, 1), (0, 1),
    (4, 1), (5, 1), (7, 2),
    (4, 1), (5, 1), (7, 2),
  ])),

  // C C CD E | ED EF G–  (two bars; the tune turns to triplets after this,
  // which the notation can't express, so it stops on the half cadence.)
  Song('Row, Row, Row Your Boat', 2, _layout(const [
    (0, 1), (0, 1), (0, 0.5), (2, 0.5), (4, 1),
    (4, 0.5), (2, 0.5), (4, 0.5), (5, 0.5), (7, 2),
  ])),

  // E E F G | G F E D | C C D E | E D D–
  // Bar 4 is evened out: Beethoven dots the first E and shortens the D.
  Song('Ode to Joy', 4, _layout(const [
    (4, 1), (4, 1), (5, 1), (7, 1),
    (7, 1), (5, 1), (4, 1), (2, 1),
    (0, 1), (0, 1), (2, 1), (4, 1),
    (4, 1), (2, 1), (2, 2),
  ])),

  // E D C– | E D C– | G F F E | G F F E
  // "See how they run" is evened out from its dotted original.
  Song('Three Blind Mice', 4, _layout(const [
    (4, 1), (2, 1), (0, 2),
    (4, 1), (2, 1), (0, 2),
    (7, 1), (5, 1), (5, 1), (4, 1),
    (7, 1), (5, 1), (5, 1), (4, 1),
  ])),

  // C C C G | A A G– | E E D D | C–
  Song('Old MacDonald Had a Farm', 4, _layout(const [
    (0, 1), (0, 1), (0, 1), (7, 1),
    (9, 1), (9, 1), (7, 2),
    (4, 1), (4, 1), (2, 1), (2, 1),
    (0, 2), (_rest, 1), (_rest, 1),
  ])),

  // G A G F | E F G– | D E F– | E F G–
  // Pitches are the standard contour; the lilting rhythm is evened out.
  // Ends on the half cadence, where the first half of the tune lands.
  Song('London Bridge', 4, _layout(const [
    (7, 1), (9, 1), (7, 1), (5, 1),
    (4, 1), (5, 1), (7, 2),
    (2, 1), (4, 1), (5, 2),
    (4, 1), (5, 1), (7, 2),
  ])),

  // G E G– | G E G– | A G F E | D E F–
  Song('This Old Man', 4, _layout(const [
    (7, 1), (4, 1), (7, 2),
    (7, 1), (4, 1), (7, 2),
    (9, 1), (7, 1), (5, 1), (4, 1),
    (2, 1), (4, 1), (5, 2),
  ])),

  // ------------------------------------------------------------- six notes

  // C C G G | A A G– | F F E E | D D C–
  Song('Twinkle Twinkle Little Star', 4, _layout(const [
    (0, 1), (0, 1), (7, 1), (7, 1),
    (9, 1), (9, 1), (7, 2),
    (5, 1), (5, 1), (4, 1), (4, 1),
    (2, 1), (2, 1), (0, 2),
  ])),

  // C C C D | C C G– | A G A B | C5–
  // First to reach above the staff's comfort zone: B and the octave C.
  Song('Good King Wenceslas', 4, _layout(const [
    (0, 1), (0, 1), (0, 1), (2, 1),
    (0, 1), (0, 1), (7, 2),
    (9, 1), (7, 1), (9, 1), (11, 1),
    (12, 2), (_rest, 1), (_rest, 1),
  ])),

  // ----------------------------------------------------------- eight notes

  // C5 B A G | F E D C — the full descending scale, and the only tune here
  // that uses every note on the board. Evened out from its dotted original.
  Song('Joy to the World', 2, _layout(const [
    (12, 1), (11, 1), (9, 1), (7, 1),
    (5, 1), (4, 1), (2, 1), (0, 1),
  ])),
];

/// The keyboard Songs mode forces: every note any song in [kSongs] needs,
/// which across the library is the full C major octave, C4 through C5.
/// Derived rather than hardcoded, so a new tune's notes light up on their own.
///
/// Songs overrides the note set rather than narrowing it per song: a stable
/// keyboard between rounds beats one that reshapes itself, which would leak
/// how many distinct pitches the coming tune uses before you've heard it.
final Set<int> kSongsNoteSet = {
  for (final song in kSongs) ...song.semitones,
};
