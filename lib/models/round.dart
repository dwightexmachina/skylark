import 'note.dart';

enum Verdict { pending, good, offTime, wrongPitch, missed }

class JudgedEvent {
  final NoteEvent event;
  Verdict verdict = Verdict.pending;
  Pitch? played; // what the user actually clicked (for wrongPitch)
  double? deltaBeats; // click time minus expected time, in beats
  bool revealed = false;

  /// Echo (notes-per-round >= 2): true once answered but before the whole
  /// round is in, so the staff shows a pitch-neutral marker instead of the
  /// real note — revealing one position's correctness early would let the
  /// player use it to infer the rest of the sequence before finishing it.
  bool placeholder = false;

  JudgedEvent(this.event);

  bool get isRest => event.isRest;
}

/// One pitch event of a completed round, frozen for the session log.
class LoggedNote {
  final String target; // what Skylark played, e.g. 'C4'
  final Verdict verdict;
  final String? played; // what the user played, when it was a wrong pitch
  const LoggedNote(
      {required this.target, required this.verdict, this.played});
}

/// A completed training round in the session log (in memory only).
class RoundLogEntry {
  final int number; // 1-based, in the order rounds were completed
  final bool won; // perfect round: every note right and on time
  final bool echo; // true when this was an Echo round
  final int echoNoteCount; // Echo: notes per round (the ×N badge)
  /// Echo: one inner list per batched round, in order, when notes-per-round
  /// is 2 or more. Null means "render flat" — either a non-Echo entry, or
  /// Echo at 1 note per round, which degenerates to a flat row of
  /// independent 1-note rounds with no position to track.
  final List<List<LoggedNote>>? echoRounds;
  /// Songs: the tune this round asked for. Null for every other mode.
  final String? songName;
  final List<LoggedNote> notes;
  final int pitchCorrect, onTime, pitchTotal;
  const RoundLogEntry({
    required this.number,
    required this.won,
    this.echo = false,
    this.echoNoteCount = 0,
    this.echoRounds,
    this.songName,
    required this.notes,
    required this.pitchCorrect,
    required this.onTime,
    required this.pitchTotal,
  });
}

enum Phase { idle, tonic, countIn, listening, userCount, performing, summary }

/// The four ways to use Skylark.
enum GameMode { training, freePlay, echo, songs }

/// Which playing surface is shown: piano keys or a guitar fingerboard.
/// Purely visual — notes, computer keys, and audio are identical.
enum Instrument { piano, guitar }

extension PhaseX on Phase {
  bool get isActiveRound =>
      this != Phase.idle && this != Phase.summary;
}
