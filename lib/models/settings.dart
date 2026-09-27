import '../audio/audio_engine.dart' show Tone;

enum TimingWindow {
  loose(0.5, 'Loose'),
  standard(0.25, 'Standard'),
  tight(0.125, 'Tight');

  final double beats; // allowed deviation either side of the beat
  final String label;
  const TimingWindow(this.beats, this.label);
}

enum Difficulty {
  beginner('Beginner'),
  easy('Easy'),
  standard('Standard'),
  hard('Hard'),
  custom('Custom');

  final String label;
  const Difficulty(this.label);
}

class Settings {
  /// Selected pitch classes as semitones from C (0–11).
  final Set<int> noteSet;
  final int measures; // 1–4
  final int bpm; // 40–140
  final TimingWindow window;
  final bool tonicFirst;
  final Tone tone;

  /// Rhythm vocabulary. Quarter notes are always in play.
  final Difficulty difficulty;
  final bool allowHalves;
  final bool allowEighths;
  final bool allowRests;

  const Settings({
    this.noteSet = const {0, 4, 7}, // C major triad
    this.measures = 1,
    this.bpm = 80,
    this.window = TimingWindow.loose, // matches the Beginner default

    this.tonicFirst = true,
    this.tone = Tone.warm,
    this.difficulty = Difficulty.beginner,
    this.allowHalves = false,
    this.allowEighths = false,
    this.allowRests = false,
  });

  Settings copyWith({
    Set<int>? noteSet,
    int? measures,
    int? bpm,
    TimingWindow? window,
    bool? tonicFirst,
    Tone? tone,
    Difficulty? difficulty,
    bool? allowHalves,
    bool? allowEighths,
    bool? allowRests,
  }) {
    return Settings(
      noteSet: noteSet ?? this.noteSet,
      measures: measures ?? this.measures,
      bpm: bpm ?? this.bpm,
      window: window ?? this.window,
      tonicFirst: tonicFirst ?? this.tonicFirst,
      tone: tone ?? this.tone,
      difficulty: difficulty ?? this.difficulty,
      allowHalves: allowHalves ?? this.allowHalves,
      allowEighths: allowEighths ?? this.allowEighths,
      allowRests: allowRests ?? this.allowRests,
    );
  }

  /// Apply a preset: sets the rhythm vocabulary and timing window in one click.
  Settings withDifficulty(Difficulty d) => switch (d) {
        Difficulty.beginner => copyWith(
            difficulty: d,
            allowHalves: false,
            allowEighths: false,
            allowRests: false,
            window: TimingWindow.loose),
        Difficulty.easy => copyWith(
            difficulty: d,
            allowHalves: true,
            allowEighths: false,
            allowRests: false,
            window: TimingWindow.standard),
        Difficulty.standard => copyWith(
            difficulty: d,
            allowHalves: true,
            allowEighths: true,
            allowRests: true,
            window: TimingWindow.standard),
        Difficulty.hard => copyWith(
            difficulty: d,
            allowHalves: true,
            allowEighths: true,
            allowRests: true,
            window: TimingWindow.tight),
        Difficulty.custom => copyWith(difficulty: d),
      };
}
