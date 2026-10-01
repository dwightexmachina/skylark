import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../audio/audio_engine.dart';
import '../logic/generator.dart';
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
  int totalTimedEvents = 0; // training only: Perfect Pitch has no timing
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

  // Mode: training (dictation), perfect pitch, or free play.
  GameMode mode = GameMode.perfectPitch;
  bool get freePlay => mode == GameMode.freePlay;
  bool get perfectPitch => mode == GameMode.perfectPitch;
  final List<Pitch> echo = []; // notes echoed onto the staff
  bool metronomeOn = false;
  Timer? _metroTimer;
  double _metroStart = 0;
  double _nextClick = 0;

  // Perfect Pitch stream state. Gameplay is a continuous stream of mystery
  // notes; answered notes are still batched into [Settings.ppNotes]-sized
  // log entries behind the scenes.
  int ppReplaysLeft = 0; // -1 = unlimited; per mystery note
  int ppAnswered = 0; // notes answered this stream
  String? ppFeedback; // teaching line after a wrong guess
  Timer? _ppTimer; // schedules the next mystery note
  Timer? _flashTimer; // clears key flashes (no ticker in this mode)
  final List<JudgedEvent> _ppBatch = []; // answered notes awaiting a log entry
  bool get ppStreaming => perfectPitch && phase == Phase.performing;

  double get _pos => (engine.now - _t0) / _spb;

  /// Playhead position in melody beats during the user's turn (or listening).
  double? get playheadBeat {
    if (perfectPitch) return null; // no pulse, no playhead
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
    if (perfectPitch) {
      _startPPStream();
      return;
    }
    roundNumber++;
    melody = generateMelody(settings, _rng);
    _startTimeline();
  }

  void replay() {
    if (freePlay || perfectPitch || melody == null) return;
    engine.stopAll();
    _startTimeline();
  }

  void togglePause() {
    if (perfectPitch) return; // nothing to freeze: no timeline
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
    if (perfectPitch) {
      stopPP();
      return;
    }
    if (!phase.isActiveRound) return;
    _clearPause();
    lastRoundSkipped = true;
    _finish();
  }

  // ------------------------------------------------------------ perfect pitch

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
    ppAnswered = 0;
    ppFeedback = null;
    phase = Phase.performing;
    activeBeat = null;
    flashSemitone = null;
    _ticker?.cancel();
    _ticker = null;
    _nextMystery();
    notifyListeners();
  }

  void _nextMystery() {
    final pool = settings.noteSet.toList();
    judged.add(JudgedEvent(NoteEvent(
        startBeat: judged.length.toDouble(),
        durationBeats: 1,
        pitch: Pitch(pool[_rng.nextInt(pool.length)]))));
    ppReplaysLeft = switch (settings.difficulty) {
      Difficulty.beginner => -1,
      Difficulty.easy => 2,
      Difficulty.standard || Difficulty.custom => 1,
      Difficulty.hard => 0,
    };
    _playMystery();
  }

  void _playMystery() {
    final target = judged.last.event.pitch!;
    engine.scheduleNote(
        target.frequency, settings.tone, engine.now + 0.15, 0.9);
  }

  void ppHearAgain() {
    if (!ppStreaming ||
        ppReplaysLeft == 0 ||
        judged.last.verdict != Verdict.pending) {
      return;
    }
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
    if (_ppBatch.length >= settings.ppNotes) _commitPPBatch();
    _ppTimer?.cancel();
    _ppTimer = Timer(Duration(milliseconds: good ? 1100 : 1800), () {
      if (!ppStreaming) return;
      _nextMystery();
      notifyListeners();
    });
  }

  /// Freeze the answered notes gathered so far into one session-log entry.
  /// The log keeps Perfect Pitch results grouped in [Settings.ppNotes]-sized
  /// sets even though gameplay streams continuously.
  void _commitPPBatch() {
    if (_ppBatch.isEmpty) return;
    final correct = _ppBatch.where((j) => j.verdict == Verdict.good).length;
    roundLog.insert(
      0,
      RoundLogEntry(
        number: roundLog.length + 1,
        won: correct == _ppBatch.length,
        perfectPitch: true,
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

  /// End the stream. The unanswered mystery note is dropped — stopping is
  /// not a wrong answer — and any partial batch goes to the log.
  void stopPP() {
    if (!ppStreaming) return;
    _ppTimer?.cancel();
    _ppTimer = null;
    if (judged.isNotEmpty && judged.last.verdict == Verdict.pending) {
      judged.removeLast();
    }
    _commitPPBatch();
    phase = Phase.idle;
    notifyListeners();
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
    for (var b = countStart; b < _endBeat; b++) {
      final inListen = b >= _listenStart && b < _userCountStart;
      final inPerform = b >= _userStart;
      final accent = b == countStart ||
          b == _userCountStart ||
          (inListen && (b - _listenStart) % 4 == 0) ||
          (inPerform && (b - _userStart) % 4 == 0);
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
    activeBeat = switch (phase) {
      Phase.tonic => null,
      Phase.countIn => ((pos - _tonicBeats).floor()) % 4,
      Phase.listening => ((pos - _listenStart).floor()) % 4,
      Phase.userCount => ((pos - _userCountStart).floor()) % 4,
      Phase.performing => ((pos - _userStart).floor()) % 4,
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
    // be a reference pitch, which Perfect Pitch forbids.
    if (ppStreaming && judged.last.verdict != Verdict.pending) return;
    engine.unlock();
    final pitch = Pitch(semitone);
    _held[semitone] = engine.startNote(pitch.frequency, settings.tone);

    if (freePlay) {
      if (echo.length >= settings.measures * 4) echo.clear();
      echo.add(pitch);
    } else if (perfectPitch) {
      if (ppStreaming) _ppAnswer(pitch);
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
    streak = 0; // means per-round in training, per-note in Perfect Pitch
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
    }
    settings = next;
    notifyListeners();
  }

  void toggleNote(int semitone) {
    final set = {...settings.noteSet};
    if (set.contains(semitone)) {
      if (set.length <= 2) return; // keep at least two
      set.remove(semitone);
    } else {
      set.add(semitone);
    }
    updateSettings(settings.copyWith(noteSet: set));
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
