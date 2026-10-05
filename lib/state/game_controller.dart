import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../logic/generator.dart';
import '../logic/songs.dart';
import '../models/note.dart';
import '../models/round.dart';
import '../models/settings.dart';

class GameController extends ChangeNotifier {
  final AudioEngine engine = AudioEngine();
  final Random _rng = Random();

  Settings settings = const Settings();

  GameController() {
    engine.preload(settings.tone); // default tone is sampled; fetch it early
  }

  Phase phase = Phase.idle;
  int roundNumber = 0;
  Melody? melody;
  List<JudgedEvent> judged = [];

  // Aggregate stats across rounds.
  int totalPitchEvents = 0;
  int totalPitchCorrect = 0;
  int totalOnTime = 0;
  int totalTimedEvents = 0; // training only: Echo streaming has no timing
  int streak = 0;

  // Last finished round, for the summary line.
  int roundPitchCorrect = 0;
  int roundOnTime = 0;
  int roundPitchTotal = 0;
  bool lastRoundSkipped = false; // skipped rounds don't get a result pop
  int attempt = 0; // increments every started timeline (incl. replays)

  /// Session log of completed training rounds, newest first.
  /// Lives in memory only: a page refresh starts it fresh.
  final List<RoundLogEntry> roundLog = [];
  int get roundsWon => roundLog.where((e) => e.won).length;

  // Timeline (beats from _t0 at AudioContext time).
  double _t0 = 0;
  double _spb = 0.75; // seconds per beat
  double _tonicBeats = 0;
  double _listenStart = 0;
  double _userCountStart = 0;
  double _userStart = 0;
  double _endBeat = 0;

  /// Anacrusis of the melody in play. [_listenStart] and [_userStart] mark
  /// melody beat 0 — the first sounding note — so the downbeat, which is what
  /// the metronome accents, sits this many beats later.
  double _pickupBeats = 0;

  Timer? _ticker;

  // Transient UI state.
  int? activeBeat; // 0–3 metronome lamp, null when not ticking
  int? flashSemitone; // key flashing a verdict after a judged click
  Verdict? flashVerdict;
  double _flashUntilBeat = 0;

  // Held notes (mouse or computer keyboard), semitone → sounding voice.
  final Map<int, Voice> _held = {};
  Set<int> get heldSemitones => _held.keys.toSet();

  /// Paused: the audio context is suspended, freezing the round timeline,
  /// scheduled notes, and metronome exactly in place.
  bool paused = false;

  // Mode: training (dictation), echo (mystery-note streaming), songs (canned
  // tunes through the training timeline), or free play.
  GameMode mode = GameMode.echo;

  /// The note set in force outside Songs mode. Songs overrides the keyboard
  /// with [kSongsNoteSet] so every tune is playable; this remembers what the
  /// player had picked so Training and Echo get it back on the way out.
  Set<int>? _noteSetBeforeSongs;

  /// Playing surface: piano keys or guitar fingerboard. Kept coherent with
  /// the tone: guitar tones show the fingerboard, everything else the keys.
  Instrument instrument = Instrument.piano;

  // Each instrument remembers its last tone so toggling swaps sounds too.
  Tone _lastPianoTone = const Settings().tone;
  Tone _lastGuitarTone = Tone.guitarClean;

  void setInstrument(Instrument value) {
    if (instrument == value) return;
    instrument = value;
    // Mid-round this is a no-op, like every settings change: the board
    // swaps now, the sound at the next round.
    updateSettings(settings.copyWith(
        tone: value == Instrument.guitar ? _lastGuitarTone : _lastPianoTone));
    notifyListeners();
  }
  bool get freePlay => mode == GameMode.freePlay;
  // Named echoMode, not echo: `echo` below is Free Play's echoed-note list.
  bool get echoMode => mode == GameMode.echo;
  bool get songsMode => mode == GameMode.songs;

  /// The selected tune. Clamped, so a shrunken library can't strand the index.
  Song get song => kSongs[settings.songIndex.clamp(0, kSongs.length - 1)];
  final List<Pitch> echo = []; // notes echoed onto the staff (Free Play)
  bool metronomeOn = false;
  Timer? _metroTimer;
  double _metroStart = 0;
  double _nextClick = 0;

  // Echo (one note per round) stream state. Gameplay is a continuous stream
  // of mystery notes; answered notes are still batched into
  // [_echoRoundsPerBatch]-sized log entries behind the scenes.
  int ppReplaysLeft = 0; // -1 = unlimited; per mystery note
  int ppAnswered = 0; // notes answered this stream
  String? ppFeedback; // teaching line after a wrong guess
  Timer? _ppTimer; // schedules the next mystery note
  Timer? _flashTimer; // clears key flashes (no ticker in this mode)
  final List<JudgedEvent> _ppBatch = []; // answered notes awaiting a log entry

  // Echo stream state (notes-per-round >= 2 only; at 1 note per round, Echo
  // reuses the fields and methods above directly).
  int echoAnsweredInRound = 0; // how many of the current round answered so far
  bool echoListening = false; // true while the round's notes are still playing
  int _echoRoundStart = 0; // index into `judged` of the current round's start
  final List<List<JudgedEvent>> _echoBatch = []; // completed rounds awaiting a log entry

  /// True while Echo's mystery-note stream is actively taking answers.
  bool get ppStreaming => echoMode && phase == Phase.performing;

  double get _pos => (engine.now - _t0) / _spb;

  /// Playhead position in melody beats during the user's turn (or listening).
  double? get playheadBeat {
    if (echoMode) return null; // no pulse, no playhead
    if (phase == Phase.listening) return _pos - _listenStart;
    if (phase == Phase.performing) return _pos - _userStart;
    return null;
  }

  bool get keysActive =>
      phase == Phase.idle ||
      phase == Phase.summary ||
      phase == Phase.performing ||
      (phase == Phase.userCount && _pos >= _userStart - 0.9);

  // ---------------------------------------------------------------- round flow

  void playRound() {
    if (freePlay || phase.isActiveRound) return;
    if (echoMode) {
      _startPPStream();
      return;
    }
    roundNumber++;
    // Songs differ from Training in exactly one way: a fixed melody off the
    // shelf instead of a generated one. Everything downstream is shared.
    melody = songsMode ? song.melody : generateMelody(settings, _rng);
    _startTimeline();
  }

  void replay() {
    if (freePlay || echoMode || melody == null) {
      return;
    }
    engine.stopAll();
    _startTimeline();
  }

  void togglePause() {
    if (echoMode) return; // nothing to freeze: no timeline
    if (!paused && !phase.isActiveRound) return;
    paused = !paused;
    if (paused) {
      engine.pause();
    } else {
      engine.unpause();
    }
    notifyListeners();
  }

  void _clearPause() {
    if (paused) {
      paused = false;
      engine.unpause();
    }
  }

  void skip() {
    if (echoMode) {
      stopPP();
      return;
    }
    if (!phase.isActiveRound) return;
    _clearPause();
    lastRoundSkipped = true;
    _finish();
  }

  // -------------------------------------------------------------------- echo

  /// A continuous stream of mystery notes. Each plays with no tonic, no
  /// count-in and no metronome; the user's first key press is the answer,
  /// and the next mystery note follows until the user presses Stop.
  void _startPPStream() {
    _clearPause();
    engine.unlock();
    _stopMetronome();
    lastRoundSkipped = false;
    attempt++;
    melody = null;
    judged = [];
    _ppBatch.clear();
    _echoBatch.clear();
    echoAnsweredInRound = 0;
    _echoRoundStart = 0;
    echoListening = false;
    ppAnswered = 0;
    ppFeedback = null;
    phase = Phase.performing;
    activeBeat = null;
    flashSemitone = null;
    _ticker?.cancel();
    _ticker = null;
    (echoMode && settings.echoNotes > 1) ? _startEchoRound() : _nextMystery();
    notifyListeners();
  }

  void _nextMystery() {
    final semitone = _pickWeightedSemitone();
    judged.add(JudgedEvent(NoteEvent(
        startBeat: judged.length.toDouble(),
        durationBeats: 1,
        pitch: Pitch(semitone))));
    ppReplaysLeft = settings.echoReplays.count;
    _playMystery();
  }

  /// Weighted pick for Echo: a note's odds are its [Settings.noteWeights]
  /// value over the sum of all enabled notes' values (absent = default 5).
  /// No exclusion logic — repeats within a round are fine, since Echo tests
  /// sequence memory rather than disambiguating two specific notes.
  int _pickWeightedSemitone() {
    final pool = settings.noteSet.toList();
    final weights = [
      for (final s in pool) (settings.noteWeights[s] ?? 5).toDouble(),
    ];
    final total = weights.fold(0.0, (a, b) => a + b);
    var r = _rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      if (r < weights[i]) return pool[i];
      r -= weights[i];
    }
    return pool.last; // floating-point fallback
  }

  void _playMystery() {
    final target = judged.last.event.pitch!;
    engine.scheduleNote(
        target.frequency, settings.tone, engine.now + 0.15, 0.9);
  }

  void ppHearAgain() {
    if (!ppStreaming || ppReplaysLeft == 0) return;
    if (echoMode && settings.echoNotes > 1) {
      // Replays the whole round from the top — only offered before the
      // round's first note is answered, to avoid any ambiguity about
      // whether a later replay would resume mid-round or start over.
      if (echoAnsweredInRound > 0) return;
      if (ppReplaysLeft > 0) ppReplaysLeft--;
      _playEchoRound();
      notifyListeners();
      return;
    }
    if (judged.last.verdict != Verdict.pending) return;
    if (ppReplaysLeft > 0) ppReplaysLeft--;
    _playMystery();
    notifyListeners();
  }

  void _ppAnswer(Pitch played) {
    final j = judged.last;
    final target = j.event.pitch!;
    j.played = played;
    j.revealed = true;
    final good = played == target;
    j.verdict = good ? Verdict.good : Verdict.wrongPitch;
    flashSemitone = played.semitone;
    flashVerdict = j.verdict;
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 650), () {
      flashSemitone = null;
      flashVerdict = null;
      notifyListeners();
    });
    // Each mystery note sounds exactly once — no reveal tone after a miss.
    // The staff dyad (guess in red, answer in amber) carries the correction.
    ppFeedback = good
        ? null
        : 'You played ${played.label} — it was ${target.label}.';
    ppAnswered++;
    totalPitchEvents++;
    if (good) totalPitchCorrect++;
    streak = good ? streak + 1 : 0;
    _ppBatch.add(j);
    if (_ppBatch.length >= _echoRoundsPerBatch) _commitPPBatch();
    _ppTimer?.cancel();
    _ppTimer = Timer(Duration(milliseconds: good ? 1100 : 1800), () {
      if (!ppStreaming) return;
      _nextMystery();
      notifyListeners();
    });
  }

  /// Freeze the answered notes gathered so far into one session-log entry.
  /// The log keeps results grouped in [_echoRoundsPerBatch]-sized sets even
  /// though gameplay streams continuously.
  void _commitPPBatch() {
    if (_ppBatch.isEmpty) return;
    final correct = _ppBatch.where((j) => j.verdict == Verdict.good).length;
    roundLog.insert(
      0,
      RoundLogEntry(
        number: roundLog.length + 1,
        won: correct == _ppBatch.length,
        // echoRounds stays null here: at one note per round, Echo degenerates
        // to a flat batch of independent 1-note rounds, no position to track.
        echo: true,
        echoNoteCount: settings.echoNotes,
        notes: [
          for (final j in _ppBatch)
            LoggedNote(
              target: j.event.pitch!.label,
              verdict: j.verdict,
              played: j.played?.label,
            ),
        ],
        pitchCorrect: correct,
        // Timing is meaningless here; mirror pitch so the log line reads
        // sensibly, but leave the timed totals untouched.
        onTime: correct,
        pitchTotal: _ppBatch.length,
      ),
    );
    _ppBatch.clear();
  }

  /// End the stream. An unanswered note (or, in Echo, a not-yet-fully-
  /// answered round) is dropped — stopping is not a wrong answer — and
  /// whatever's already complete in the batch goes to the log.
  void stopPP() {
    if (!ppStreaming) return;
    _ppTimer?.cancel();
    _ppTimer = null;
    if (echoMode && settings.echoNotes > 1) {
      if (echoAnsweredInRound < settings.echoNotes) {
        judged.removeRange(_echoRoundStart, judged.length);
      }
      _commitEchoBatch();
    } else {
      if (judged.isNotEmpty && judged.last.verdict == Verdict.pending) {
        judged.removeLast();
      }
      _commitPPBatch();
    }
    phase = Phase.idle;
    notifyListeners();
  }

  // --------------------------------------------------------------- echo rounds
  // Echo at notes-per-round >= 2 needs its own round engine: at one note per
  // round there's always exactly one pending note at a time, but at two or
  // more Echo plays a whole round's worth before any answering starts, then judges
  // each key press against the matching position in that round — a swapped
  // pair of notes scores two wrongs, never "right notes, wrong order" credit.
  // At exactly one note per round, Echo never reaches these methods at all;
  // it reuses `_nextMystery`/`_ppAnswer`/`_commitPPBatch` above untouched.

  int get _echoRoundsPerBatch => max(1, (5 / settings.echoNotes).floor());

  void _startEchoRound() {
    _echoRoundStart = judged.length;
    for (var i = 0; i < settings.echoNotes; i++) {
      judged.add(JudgedEvent(NoteEvent(
          startBeat: judged.length.toDouble(),
          durationBeats: 1,
          pitch: Pitch(_pickWeightedSemitone()))));
    }
    echoAnsweredInRound = 0;
    ppReplaysLeft = settings.echoReplays.count;
    _playEchoRound();
  }

  /// Plays the current round's notes back-to-back, spaced by
  /// [Settings.echoNoteLag]. Echo has no tonic or metronome of its own to
  /// anchor a tempo to, so this is deliberately independent of
  /// [Settings.bpm] (a Training-only slider Echo's sidebar doesn't expose).
  void _playEchoRound() {
    final onsetGap = settings.echoNoteLag;
    final noteDuration = onsetGap; // held until the next note fires
    echoListening = true;
    for (var i = 0; i < settings.echoNotes; i++) {
      final target = judged[_echoRoundStart + i].event.pitch!;
      engine.scheduleNote(target.frequency, settings.tone,
          engine.now + 0.15 + i * onsetGap, noteDuration);
    }
    final totalMs =
        ((0.15 + (settings.echoNotes - 1) * onsetGap + noteDuration) * 1000)
            .round();
    _ppTimer?.cancel();
    _ppTimer = Timer(Duration(milliseconds: totalMs), () {
      echoListening = false;
      notifyListeners();
    });
  }

  void _echoAnswer(Pitch played) {
    final j = judged[_echoRoundStart + echoAnsweredInRound];
    // The press is recorded immediately, but judging (and the piano-key
    // flash) waits for the whole round — revealing one position's verdict
    // early would let the player use it to infer the rest of the sequence
    // before they've finished playing it back.
    j.played = played;
    j.revealed = true;
    j.placeholder = true;
    echoAnsweredInRound++;
    if (echoAnsweredInRound < settings.echoNotes) return; // more to answer

    // Round complete — judge every position at once, then fold stats in
    // bulk rather than per note, so a mid-round Stop never has to unwind
    // partial counters (stopPP just discards the whole in-progress round
    // instead).
    final round = judged.sublist(_echoRoundStart);
    for (final ev in round) {
      ev.verdict = ev.played == ev.event.pitch ? Verdict.good : Verdict.wrongPitch;
      ev.placeholder = false;
    }
    final allGood = round.every((e) => e.verdict == Verdict.good);
    flashSemitone = played.semitone;
    flashVerdict = round.last.verdict;
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 650), () {
      flashSemitone = null;
      flashVerdict = null;
      notifyListeners();
    });
    ppAnswered += round.length;
    totalPitchEvents += round.length;
    totalPitchCorrect += round.where((e) => e.verdict == Verdict.good).length;
    streak = allGood ? streak + 1 : 0;
    _echoBatch.add(round);
    if (_echoBatch.length >= _echoRoundsPerBatch) _commitEchoBatch();
    _ppTimer?.cancel();
    _ppTimer = Timer(Duration(milliseconds: allGood ? 900 : 1500), () {
      if (!ppStreaming) return;
      _startEchoRound();
      notifyListeners();
    });
  }

  /// Freeze the rounds gathered so far into one session-log entry. Each
  /// inner list in [RoundLogEntry.echoRounds] is one full round, which is
  /// what lets the log UI draw a divider between batched rounds and number
  /// positions within each — no per-note-count special-casing needed there.
  void _commitEchoBatch() {
    if (_echoBatch.isEmpty) return;
    final flat = _echoBatch.expand((r) => r).toList();
    final correct = flat.where((j) => j.verdict == Verdict.good).length;
    roundLog.insert(
      0,
      RoundLogEntry(
        number: roundLog.length + 1,
        won: correct == flat.length,
        echo: true,
        echoNoteCount: settings.echoNotes,
        echoRounds: [
          for (final r in _echoBatch)
            [
              for (final j in r)
                LoggedNote(
                  target: j.event.pitch!.label,
                  verdict: j.verdict,
                  played: j.played?.label,
                ),
            ],
        ],
        notes: [
          for (final j in flat)
            LoggedNote(
              target: j.event.pitch!.label,
              verdict: j.verdict,
              played: j.played?.label,
            ),
        ],
        pitchCorrect: correct,
        onTime: correct,
        pitchTotal: flat.length,
      ),
    );
    _echoBatch.clear();
  }

  void _startTimeline() {
    _clearPause();
    engine.unlock();
    _stopMetronome();
    lastRoundSkipped = false;
    attempt++;
    final m = melody!;
    judged = [for (final e in m.events) JudgedEvent(e)];
    roundPitchTotal = m.pitchEvents.length;
    _pickupBeats = m.pickupBeats;

    _spb = 60.0 / settings.bpm;
    _tonicBeats = settings.tonicFirst ? 2 : 0;
    final countStart = _tonicBeats;
    _listenStart = countStart + 4;
    _userCountStart = _listenStart + m.totalBeats;
    _userStart = _userCountStart + 4;
    _endBeat = _userStart + m.totalBeats;

    _t0 = engine.now + 0.2;
    double timeOf(double beat) => _t0 + beat * _spb;

    if (settings.tonicFirst) {
      engine.scheduleNote(
          const Pitch(0).frequency, settings.tone, timeOf(0), 1.5 * _spb);
    }
    // Metronome through count-in, listening, user count-in and the user's turn.
    // Accents mark the downbeat, which a pickup pushes past melody beat 0 —
    // the anacrusis sounds over the beats between the count-in and bar 1.
    for (var b = countStart; b < _endBeat; b++) {
      final inListen = b >= _listenStart && b < _userCountStart;
      final inPerform = b >= _userStart;
      final accent = b == countStart ||
          b == _userCountStart ||
          (inListen && (b - _listenStart - _pickupBeats) % 4 == 0) ||
          (inPerform && (b - _userStart - _pickupBeats) % 4 == 0);
      engine.scheduleClick(timeOf(b), accent: accent);
    }
    for (final e in m.events) {
      if (e.isRest) continue;
      engine.scheduleNote(e.pitch!.frequency, settings.tone,
          timeOf(_listenStart + e.startBeat), e.durationBeats * _spb * 0.92);
    }

    phase = settings.tonicFirst ? Phase.tonic : Phase.countIn;
    flashSemitone = null;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 25), (_) => _tick());
    notifyListeners();
  }

  void _tick() {
    final pos = _pos;

    if (pos >= _endBeat + 1) {
      _finish();
      return;
    }

    phase = switch (pos) {
      _ when pos < _tonicBeats => Phase.tonic,
      _ when pos < _listenStart => Phase.countIn,
      _ when pos < _userCountStart => Phase.listening,
      _ when pos < _userStart => Phase.userCount,
      _ => Phase.performing,
    };

    // Metronome lamp.
    // Lamp 0 is the downbeat, so it stays in step with the accented click.
    activeBeat = switch (phase) {
      Phase.tonic => null,
      Phase.countIn => ((pos - _tonicBeats).floor()) % 4,
      Phase.listening => ((pos - _listenStart - _pickupBeats).floor()) % 4,
      Phase.userCount => ((pos - _userCountStart).floor()) % 4,
      Phase.performing => ((pos - _userStart - _pickupBeats).floor()) % 4,
      _ => null,
    };

    // Keys deliberately do NOT light during playback — that would reveal
    // the answer. Dictation is by ear only.

    if (phase == Phase.performing) {
      final local = pos - _userStart;
      final missCutoff = settings.window.beats + 0.5;
      for (final j in judged) {
        if (j.isRest) {
          if (!j.revealed && local > j.event.startBeat) j.revealed = true;
        } else if (j.verdict == Verdict.pending &&
            local > j.event.startBeat + missCutoff) {
          j.verdict = Verdict.missed;
          j.revealed = true;
        }
      }
    }

    if (flashSemitone != null && pos > _flashUntilBeat) {
      flashSemitone = null;
      flashVerdict = null;
    }

    notifyListeners();
  }

  void _finish() {
    _ticker?.cancel();
    _ticker = null;
    engine.stopAll();

    var allGood = true;
    roundPitchCorrect = 0;
    roundOnTime = 0;
    for (final j in judged) {
      if (!j.isRest && j.verdict == Verdict.pending) j.verdict = Verdict.missed;
      j.revealed = true;
      if (j.isRest) continue;
      switch (j.verdict) {
        case Verdict.good:
          roundPitchCorrect++;
          roundOnTime++;
        case Verdict.offTime:
          roundPitchCorrect++;
          allGood = false;
        default:
          allGood = false;
      }
    }
    totalPitchEvents += roundPitchTotal;
    totalPitchCorrect += roundPitchCorrect;
    totalOnTime += roundOnTime;
    totalTimedEvents += roundPitchTotal;
    streak = allGood && roundPitchTotal > 0 ? streak + 1 : 0;

    if (!freePlay && !lastRoundSkipped && roundPitchTotal > 0) {
      roundLog.insert(
        0,
        RoundLogEntry(
          number: roundLog.length + 1,
          won: allGood,
          songName: songsMode ? song.name : null,
          notes: [
            for (final j in judged)
              if (!j.isRest)
                LoggedNote(
                  target: j.event.pitch!.label,
                  verdict: j.verdict,
                  played: j.played?.label,
                ),
          ],
          pitchCorrect: roundPitchCorrect,
          onTime: roundOnTime,
          pitchTotal: roundPitchTotal,
        ),
      );
    }

    phase = Phase.summary;
    activeBeat = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------- input

  /// Note-on from mouse or computer keyboard. Sounds until [noteOff].
  void noteOn(int semitone) {
    if (paused) return;
    if (_held.containsKey(semitone)) return; // key auto-repeat / double press
    if (!settings.noteSet.contains(semitone)) return;
    if (!freePlay && !keysActive) return;
    // Between mystery notes the keys stay silent — a free tone there would
    // be a reference pitch, which Echo forbids. An Echo round's own notes
    // playing back are silenced the same way.
    final multiNoteEcho = echoMode && settings.echoNotes > 1;
    if (ppStreaming &&
        ((multiNoteEcho && echoListening) ||
            judged.last.verdict != Verdict.pending)) {
      return;
    }
    engine.unlock();
    final pitch = Pitch(semitone);
    _held[semitone] = engine.startNote(pitch.frequency, settings.tone);

    if (freePlay) {
      if (echo.length >= settings.measures * 4) echo.clear();
      echo.add(pitch);
    } else if (echoMode) {
      if (ppStreaming) {
        multiNoteEcho ? _echoAnswer(pitch) : _ppAnswer(pitch);
      }
    } else {
      final judging = phase == Phase.performing ||
          (phase == Phase.userCount && _pos >= _userStart - 0.9);
      if (judging) _judge(pitch);
    }
    notifyListeners();
  }

  void noteOff(int semitone) {
    final voice = _held.remove(semitone);
    if (voice == null) return;
    voice.release();
    notifyListeners();
  }

  // --------------------------------------------------------------- free play

  void setMode(GameMode value) {
    if (mode == value) return;
    _clearPause();
    if (ppStreaming) stopPP(); // commits any partial batch to the log
    mode = value;
    // Songs owns the keyboard while it's selected: a tune the player can't
    // physically play back would be unanswerable, since `noteOn` ignores
    // anything outside the note set. Assigned directly rather than through
    // `updateSettings` — only the note set moves, so there's no tone to
    // preload and no active round to guard against.
    if (value == GameMode.songs) {
      _noteSetBeforeSongs ??= settings.noteSet;
      settings = settings.copyWith(noteSet: kSongsNoteSet);
    } else if (_noteSetBeforeSongs != null) {
      settings = settings.copyWith(noteSet: _noteSetBeforeSongs);
      _noteSetBeforeSongs = null;
    }
    _ticker?.cancel();
    _ticker = null;
    _ppTimer?.cancel();
    _ppTimer = null;
    engine.stopAll();
    _stopMetronome();
    phase = Phase.idle;
    echo.clear();
    judged = [];
    melody = null;
    ppFeedback = null;
    ppAnswered = 0;
    streak = 0; // means per-round in training, per-note (or per-round) in Echo
    activeBeat = null;
    flashSemitone = null;
    notifyListeners();
  }

  void clearEcho() {
    echo.clear();
    notifyListeners();
  }

  void toggleMetronome() {
    if (!freePlay) return;
    _clearPause();
    if (metronomeOn) {
      _stopMetronome();
    } else {
      engine.unlock();
      metronomeOn = true;
      _metroStart = engine.now + 0.15;
      _nextClick = _metroStart;
      _metroTimer =
          Timer.periodic(const Duration(milliseconds: 50), (_) => _metroTick());
    }
    notifyListeners();
  }

  void _metroTick() {
    final spb = 60.0 / settings.bpm;
    // Look-ahead scheduling keeps clicks sample-accurate despite timer jitter.
    while (_nextClick < engine.now + 0.6) {
      final beatIndex = ((_nextClick - _metroStart) / spb).round();
      engine.scheduleClick(_nextClick, accent: beatIndex % 4 == 0);
      _nextClick += spb;
    }
    final elapsed = engine.now - _metroStart;
    final lamp = elapsed < 0 ? null : (elapsed / spb).floor() % 4;
    if (lamp != activeBeat) {
      activeBeat = lamp;
      notifyListeners();
    }
  }

  void _stopMetronome() {
    _metroTimer?.cancel();
    _metroTimer = null;
    metronomeOn = false;
    activeBeat = null;
  }

  void _judge(Pitch played) {
    JudgedEvent? next;
    for (final j in judged) {
      if (!j.isRest && j.verdict == Verdict.pending) {
        next = j;
        break;
      }
    }
    if (next == null) return;

    final local = _pos - _userStart;
    final delta = local - next.event.startBeat;
    next.played = played;
    next.deltaBeats = delta;
    next.revealed = true;
    if (played != next.event.pitch) {
      next.verdict = Verdict.wrongPitch;
    } else if (delta.abs() <= settings.window.beats) {
      next.verdict = Verdict.good;
    } else {
      next.verdict = Verdict.offTime;
    }
    flashSemitone = played.semitone;
    flashVerdict = next.verdict;
    _flashUntilBeat = _pos + 0.6;
  }

  // ---------------------------------------------------------------- settings

  void updateSettings(Settings next) {
    if (phase.isActiveRound) return;
    if (next.tone != settings.tone) {
      engine.preload(next.tone); // fire-and-forget; sampled tones only
      instrument = next.tone.isGuitar ? Instrument.guitar : Instrument.piano;
      if (next.tone.isGuitar) {
        _lastGuitarTone = next.tone;
      } else {
        _lastPianoTone = next.tone;
      }
    }
    // Picking a different song clears the board. Without this the staff would
    // keep showing the finished tune's notes under a header naming the new
    // one. Safe to reset here: an active round already returned above, so
    // this only ever fires from idle or the post-round summary.
    if (songsMode && next.songIndex != settings.songIndex) {
      engine.stopAll();
      melody = null;
      judged = [];
      phase = Phase.idle;
      roundPitchCorrect = 0;
      roundOnTime = 0;
      roundPitchTotal = 0;
    }
    settings = next;
    notifyListeners();
  }

  void toggleNote(int semitone) {
    if (songsMode) return; // the tune decides which keys are live
    final set = {...settings.noteSet};
    final weights = {...settings.noteWeights};
    if (set.contains(semitone)) {
      if (set.length <= 2) return;
      set.remove(semitone);
      weights.remove(semitone); // a disabled note can't keep a weight
    } else {
      set.add(semitone);
    }
    updateSettings(settings.copyWith(noteSet: set, noteWeights: weights));
  }

  double get secondsPerBeat => _spb;

  @override
  void dispose() {
    _ticker?.cancel();
    _metroTimer?.cancel();
    _ppTimer?.cancel();
    _flashTimer?.cancel();
    for (final v in _held.values) {
      v.release();
    }
    engine.stopAll();
    super.dispose();
  }
}
