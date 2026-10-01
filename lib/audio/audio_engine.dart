import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

enum Tone {
  pure('Pure'),
  warm('Warm'),
  organ('Organ'),
  salamander('Salamander'),
  fluid('FluidR3');

  final String label;
  const Tone(this.label);

  /// Sampled pianos play recorded buffers instead of oscillators.
  bool get sampled => this == salamander || this == fluid;
}

/// FluidR3 ships one recording per semitone, C4 through C5.
const List<String> _fluidFiles = [
  'C4', 'Db4', 'D4', 'Eb4', 'E4', 'F4',
  'Gb4', 'G4', 'Ab4', 'A4', 'Bb4', 'B4', 'C5',
];

/// Salamander is sampled every minor third; in-between notes are
/// pitch-shifted from the nearest anchor via playbackRate.
const List<(int, String)> _salamanderAnchors = [
  (0, 'C4'), (3, 'Ds4'), (6, 'Fs4'), (9, 'A4'), (12, 'C5'),
];

/// A sounding note that can be released early (mouse-up on a key).
class Voice {
  final web.AudioContext _ctx;
  final web.GainNode _gain;
  final List<web.AudioScheduledSourceNode> _sources;
  bool _released = false;

  Voice._(this._ctx, this._gain, this._sources);

  /// Sampled voices attach their source once the buffer is decoded,
  /// which may land after [release] on a very first press.
  void _addSource(web.AudioScheduledSourceNode source) {
    _sources.add(source);
    if (_released) source.stop(_ctx.currentTime + 0.1);
  }

  void release() {
    if (_released) return;
    _released = true;
    final t = _ctx.currentTime;
    _gain.gain.cancelScheduledValues(t);
    _gain.gain.setValueAtTime(_gain.gain.value, t);
    _gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.08);
    for (final s in _sources) {
      s.stop(t + 0.1);
    }
  }
}

/// Thin wrapper over the browser's Web Audio API. All timing in the game is
/// anchored to [now] (AudioContext.currentTime) for sample-accurate judging.
class AudioEngine {
  web.AudioContext? _context;
  final List<web.AudioScheduledSourceNode> _scheduled = [];
  final Map<String, web.AudioBuffer> _buffers = {};
  final Map<String, Future<web.AudioBuffer>> _loads = {};

  web.AudioContext get _ctx => _context ??= web.AudioContext();

  double get now => _ctx.currentTime;

  bool _paused = false;

  /// Suspend the context: freezes [now] and everything scheduled, in place.
  void pause() {
    _paused = true;
    _ctx.suspend();
  }

  /// Resume from exactly where [pause] left off.
  void unpause() {
    _paused = false;
    _ctx.resume();
  }

  /// Browsers require a user gesture before audio may start.
  void unlock() {
    if (_paused) return; // an explicit pause is not the autoplay lock
    if (_ctx.state == 'suspended') _ctx.resume();
  }

  /// Cancel everything scheduled but not yet (or currently) playing.
  void stopAll() {
    for (final s in _scheduled) {
      try {
        s.stop();
      } catch (_) {
        // Already stopped; fine.
      }
    }
    _scheduled.clear();
  }

  // ----------------------------------------------------------------- samples

  (String, double) _sampleFor(Tone tone, int semitone) {
    if (tone == Tone.fluid) {
      return ('piano/fluid/${_fluidFiles[semitone]}.mp3', 1);
    }
    var best = _salamanderAnchors.first;
    for (final a in _salamanderAnchors) {
      if ((a.$1 - semitone).abs() < (best.$1 - semitone).abs()) best = a;
    }
    return (
      'piano/salamander/${best.$2}.mp3',
      math.pow(2, (semitone - best.$1) / 12).toDouble(),
    );
  }

  int _semitoneOf(double freq) =>
      (12 * math.log(freq / 440) / math.ln2 + 9).round().clamp(0, 12);

  Future<web.AudioBuffer> _load(String url) =>
      _loads.putIfAbsent(url, () async {
        try {
          final response = await web.window.fetch(url.toJS).toDart;
          final bytes = await response.arrayBuffer().toDart;
          final buffer = await _ctx.decodeAudioData(bytes).toDart;
          _buffers[url] = buffer;
          return buffer;
        } catch (_) {
          // Drop the failed future so a later press can retry the fetch.
          _loads.remove(url);
          rethrow;
        }
      });

  /// Fetch and decode a sampled tone's full C4–C5 set ahead of playing, so
  /// the first round on a piano tone doesn't start with silent notes.
  Future<void> preload(Tone tone) async {
    if (!tone.sampled) return;
    await Future.wait([
      for (var st = 0; st <= 12; st++)
        _load(_sampleFor(tone, st).$1).then((_) {}, onError: (_) {}),
    ]);
  }

  // ------------------------------------------------------------------ voices

  List<(double, double, String)> _partials(Tone tone) => switch (tone) {
        Tone.pure => [(1.0, 1.0, 'sine')],
        Tone.warm => [(1.0, 1.0, 'triangle')],
        Tone.organ => [(1.0, 0.65, 'sine'), (2.0, 0.35, 'sine'), (3.0, 0.18, 'sine')],
        Tone.salamander || Tone.fluid => throw StateError('sampled tone'),
      };

  Voice _spawn(double freq, Tone tone, double t0, double? duration, double peak) {
    if (tone.sampled) return _spawnSampled(freq, tone, t0, duration, peak);
    final g = _ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + 0.015);
    g.connect(_ctx.destination);
    final oscs = <web.AudioScheduledSourceNode>[];
    for (final (mult, amp, type) in _partials(tone)) {
      final osc = _ctx.createOscillator();
      osc.type = type;
      osc.frequency.value = freq * mult;
      final partGain = _ctx.createGain();
      partGain.gain.value = amp;
      osc.connect(partGain);
      partGain.connect(g);
      osc.start(t0);
      if (duration != null) osc.stop(t0 + duration + 0.1);
      oscs.add(osc);
      _scheduled.add(osc);
    }
    if (duration != null) {
      final end = t0 + duration;
      final sustainEnd = (end - 0.05) > (t0 + 0.02) ? end - 0.05 : t0 + 0.02;
      g.gain.setValueAtTime(peak, sustainEnd);
      g.gain.exponentialRampToValueAtTime(0.0001, end + 0.05);
    }
    return Voice._(_ctx, g, oscs);
  }

  /// Play a recorded piano note. The sample carries its own attack and
  /// natural decay; only the tail is shaped so melody notes don't smear.
  Voice _spawnSampled(
      double freq, Tone tone, double t0, double? duration, double peak) {
    final (url, rate) = _sampleFor(tone, _semitoneOf(freq));
    final g = _ctx.createGain();
    // Samples are mastered far quieter than a raw oscillator at the same
    // gain; scale so pianos sit at the synth tones' loudness.
    final level = (peak * 5.5).clamp(0.0, 1.0);
    g.gain.setValueAtTime(level, t0);
    if (duration != null) {
      final end = t0 + duration;
      final sustainEnd = (end - 0.04) > t0 ? end - 0.04 : t0;
      g.gain.setValueAtTime(level, sustainEnd);
      g.gain.exponentialRampToValueAtTime(0.0001, end + 0.15);
    }
    g.connect(_ctx.destination);
    final voice = Voice._(_ctx, g, []);

    void attach(web.AudioBuffer buffer) {
      final src = _ctx.createBufferSource();
      src.buffer = buffer;
      src.playbackRate.value = rate;
      src.connect(g);
      src.start(t0 > _ctx.currentTime ? t0 : _ctx.currentTime);
      if (duration != null) src.stop(t0 + duration + 0.25);
      _scheduled.add(src);
      voice._addSource(src);
    }

    final cached = _buffers[url];
    if (cached != null) {
      attach(cached);
    } else {
      // A failed load means one silent note; the next press retries.
      _load(url).then(attach, onError: (_) {});
    }
    return voice;
  }

  /// Start a note immediately and keep it sounding until [Voice.release].
  Voice startNote(double freq, Tone tone, {double gain = 0.16}) =>
      _spawn(freq, tone, now, null, gain);

  /// Schedule a note at an absolute AudioContext time.
  void scheduleNote(double freq, Tone tone, double startTime, double duration,
          {double gain = 0.16}) =>
      _spawn(freq, tone, startTime, duration, gain);

  /// Schedule a short metronome click. Accented clicks are higher and louder.
  void scheduleClick(double startTime, {bool accent = false}) {
    final osc = _ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = accent ? 1760 : 1175;
    final g = _ctx.createGain();
    final peak = accent ? 0.22 : 0.13;
    g.gain.setValueAtTime(0.0001, startTime);
    g.gain.exponentialRampToValueAtTime(peak, startTime + 0.004);
    g.gain.exponentialRampToValueAtTime(0.0001, startTime + 0.05);
    osc.connect(g);
    g.connect(_ctx.destination);
    osc.start(startTime);
    osc.stop(startTime + 0.07);
    _scheduled.add(osc);
  }
}
