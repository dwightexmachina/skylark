import 'note.dart';

enum Verdict { pending, good, offTime, wrongPitch, missed }

class JudgedEvent {
  final NoteEvent event;
  Verdict verdict = Verdict.pending;
  Pitch? played; // what the user actually clicked (for wrongPitch)
  double? deltaBeats; // click time minus expected time, in beats
  bool revealed = false;

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
  final bool perfectPitch; // true when this was a Perfect Pitch round
  final List<LoggedNote> notes;
  final int pitchCorrect, onTime, pitchTotal;
  const RoundLogEntry({
    required this.number,
    required this.won,
    this.perfectPitch = false,
    required this.notes,
    required this.pitchCorrect,
    required this.onTime,
    required this.pitchTotal,
  });
}

enum Phase { idle, tonic, countIn, listening, userCount, performing, summary }

/// The three ways to use Skylark.
enum GameMode { training, perfectPitch, freePlay }

/// Which playing surface is shown: piano keys or a guitar fingerboard.
/// Purely visual — notes, computer keys, and audio are identical.
enum Instrument { piano, guitar }

extension PhaseX on Phase {
  bool get isActiveRound =>
      this != Phase.idle && this != Phase.summary;
}
