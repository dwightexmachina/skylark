import 'dart:math' as math;

const List<String> pitchClassLabels = [
  'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B',
];

const Set<int> blackSemitones = {1, 3, 6, 8, 10};

/// Semitones from C4; the octave key C5 (12) tops the playable range.
const int semitoneCount = 13;

/// Diatonic letter index (0 = C4 … 7 = C5) and sharp flag for each semitone.
const List<(int, bool)> _diatonic = [
  (0, false), (0, true), (1, false), (1, true), (2, false), (3, false),
  (3, true), (4, false), (4, true), (5, false), (5, true), (6, false),
  (7, false),
];

/// A pitch in the app's playable range, C4–C5.
class Pitch {
  final int semitone; // 0 = C4 … 12 = C5

  const Pitch(this.semitone)
      : assert(semitone >= 0 && semitone < semitoneCount);

  int get midi => 60 + semitone;
  double get frequency => 440.0 * math.pow(2, (midi - 69) / 12);
  String get label => '${pitchClassLabels[semitone % 12]}${4 + semitone ~/ 12}';
  bool get isBlack => blackSemitones.contains(semitone % 12);

  /// Diatonic letter (0 = C4 … 7 = C5) for staff placement.
  int get letter => _diatonic[semitone].$1;
  bool get isSharp => _diatonic[semitone].$2;

  @override
  bool operator ==(Object other) => other is Pitch && other.semitone == semitone;
  @override
  int get hashCode => semitone;
}

/// One notated event: a pitched note or a rest.
class NoteEvent {
  final double startBeat; // from the start of the melody
  final double durationBeats; // 0.5 = eighth, 1 = quarter, 2 = half
  final Pitch? pitch; // null = rest
  final bool beamWithNext; // first eighth of a beamed pair

  const NoteEvent({
    required this.startBeat,
    required this.durationBeats,
    this.pitch,
    this.beamWithNext = false,
  });

  bool get isRest => pitch == null;
}

class Melody {
  final List<NoteEvent> events;
  final int measures;

  const Melody(this.events, this.measures);

  double get totalBeats => measures * 4.0;
  Iterable<NoteEvent> get pitchEvents => events.where((e) => !e.isRest);
}
