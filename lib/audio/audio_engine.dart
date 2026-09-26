import 'package:web/web.dart' as web;

enum Tone {
  pure('Pure'),
  warm('Warm'),
  organ('Organ');

  final String label;
  const Tone(this.label);
}

/// A sounding note that can be released early (mouse-up on a key).
class Voice {
  final web.AudioContext _ctx;
  final web.GainNode _gain;
  final List<web.OscillatorNode> _oscs;
  bool _released = false;

  Voice._(this._ctx, this._gain, this._oscs);

  void release() {
    if (_released) return;
    _released = true;
    final t = _ctx.currentTime;
    _gain.gain.cancelScheduledValues(t);
    _gain.gain.setValueAtTime(_gain.gain.value, t);
    _gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.08);
    for (final o in _oscs) {
      o.stop(t + 0.1);
    }
  }
}

/// Thin wrapper over the browser's Web Audio API. All timing in the game is
/// anchored to [now] (AudioContext.currentTime) for sample-accurate judging.
class AudioEngine {
  web.AudioContext? _context;
  final List<web.OscillatorNode> _scheduled = [];

  web.AudioContext get _ctx => _context ??= web.AudioContext();

  double get now => _ctx.currentTime;

  /// Browsers require a user gesture before audio may start.
  void unlock() {
    if (_ctx.state == 'suspended') _ctx.resume();
  }

  /// Cancel everything scheduled but not yet (or currently) playing.
  void stopAll() {
    for (final o in _scheduled) {
      try {
        o.stop();
      } catch (_) {
        // Already stopped; fine.
      }
    }
    _scheduled.clear();
  }

  List<(double, double, String)> _partials(Tone tone) => switch (tone) {
        Tone.pure => [(1.0, 1.0, 'sine')],
        Tone.warm => [(1.0, 1.0, 'triangle')],
        Tone.organ => [(1.0, 0.65, 'sine'), (2.0, 0.35, 'sine'), (3.0, 0.18, 'sine')],
      };

  Voice _spawn(double freq, Tone tone, double t0, double? duration, double peak) {
    final g = _ctx.createGain();
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + 0.015);
    g.connect(_ctx.destination);
    final oscs = <web.OscillatorNode>[];
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
