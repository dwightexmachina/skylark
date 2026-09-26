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

enum Phase { idle, tonic, countIn, listening, userCount, performing, summary }

extension PhaseX on Phase {
  bool get isActiveRound =>
      this != Phase.idle && this != Phase.summary;
}
