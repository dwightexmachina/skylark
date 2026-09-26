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

  Phase phase = Phase.idle;
  int roundNumber = 0;
  Melody? melody;
  List<JudgedEvent> judged = [];

  // Aggregate stats across rounds.
  int totalPitchEvents = 0;
  int totalPitchCorrect = 0;
  int totalOnTime = 0;
  int streak = 0;

  // Last finished round, for the summary line.
  int roundPitchCorrect = 0;
  int roundOnTime = 0;
  int roundPitchTotal = 0;

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

  // Free play mode.
  bool freePlay = false;
  final List<Pitch> echo = []; // notes echoed onto the staff
  bool metronomeOn = false;
  Timer? _metroTimer;
  double _metroStart = 0;
  double _nextClick = 0;

  double get _pos => (engine.now - _t0) / _spb;

  /// Playhead position in melody beats during the user's turn (or listening).
  double? get playheadBeat {
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
    melody = generateMelody(settings, _rng);
    roundNumber++;
    _startTimeline();
  }

  void replay() {
    if (freePlay || melody == null) return;
    engine.stopAll();
    _startTimeline();
  }

  void skip() {
    if (!phase.isActiveRound) return;
    _finish();
  }

  void hearTonic() {
    engine.unlock();
    engine.scheduleNote(
        const Pitch(0).frequency, settings.tone, engine.now + 0.02, 1.0);
  }

  void _startTimeline() {
    engine.unlock();
    _stopMetronome();
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
    streak = allGood && roundPitchTotal > 0 ? streak + 1 : 0;

    phase = Phase.summary;
    activeBeat = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------- input

  /// Note-on from mouse or computer keyboard. Sounds until [noteOff].
  void noteOn(int semitone) {
    if (_held.containsKey(semitone)) return; // key auto-repeat / double press
    if (!settings.noteSet.contains(semitone)) return;
    if (!freePlay && !keysActive) return;
    engine.unlock();
    final pitch = Pitch(semitone);
    _held[semitone] = engine.startNote(pitch.frequency, settings.tone);

    if (freePlay) {
      if (echo.length >= settings.measures * 4) echo.clear();
      echo.add(pitch);
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

  void setFreePlay(bool value) {
    if (freePlay == value) return;
    freePlay = value;
    _ticker?.cancel();
    _ticker = null;
    engine.stopAll();
    _stopMetronome();
    phase = Phase.idle;
    echo.clear();
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
    for (final v in _held.values) {
      v.release();
    }
    engine.stopAll();
    super.dispose();
  }
}
