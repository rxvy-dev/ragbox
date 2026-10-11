import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'native.dart';

/// Procedurally synthesised sound effects. Every sound in the game is
/// generated here from noise and oscillators on first launch, written to
/// local WAV files and played through Android's SoundPool. No sound assets
/// are bundled, so there are no licensing questions at all.
class Sfx {
  static const int rate = 22050;
  static final Map<String, int> _ids = {};
  static final Map<String, double> _last = {};
  static double volume = 0.8;
  static bool enabled = true;
  static final Stopwatch _clock = Stopwatch()..start();

  static Future<void> init(String dir) async {
    final sfxDir = Directory('$dir/sfx_v1');
    if (!sfxDir.existsSync()) sfxDir.createSync(recursive: true);
    for (final entry in _generators.entries) {
      final f = File('${sfxDir.path}/${entry.key}.wav');
      if (!f.existsSync()) {
        final samples = entry.value(math.Random(entry.key.hashCode));
        f.writeAsBytesSync(_wav(samples));
      }
      final id = await Native.loadSound(f.path);
      if (id >= 0) _ids[entry.key] = id;
    }
  }

  static void play(String name, {double vol = 1, double rate = 1}) {
    if (!enabled || volume <= 0) return;
    final id = _ids[name];
    if (id == null) return;
    final now = _clock.elapsedMilliseconds / 1000.0;
    final last = _last[name] ?? -1;
    if (now - last < 0.035) return; // avoid machine-gun stacking of one sound
    _last[name] = now;
    Native.playSound(id, (vol * volume).clamp(0.0, 1.0), rate.clamp(0.5, 2.0));
  }

  // ---------------------------------------------------------------- synthesis
  static Uint8List _wav(Float32List s) {
    final n = s.length;
    final b = ByteData(44 + n * 2);
    void str(int o, String t) {
      for (var i = 0; i < t.length; i++) {
        b.setUint8(o + i, t.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + n * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, rate, Endian.little);
    b.setUint32(28, rate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, n * 2, Endian.little);
    // normalise
    var peak = 1e-6;
    for (var i = 0; i < n; i++) {
      peak = math.max(peak, s[i].abs());
    }
    final g = 0.9 / peak;
    for (var i = 0; i < n; i++) {
      final v = (s[i] * g).clamp(-1.0, 1.0);
      b.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return b.buffer.asUint8List();
  }

  static Float32List _buf(double secs) => Float32List((secs * rate).round());

  /// Noise burst through a sweeping one-pole low-pass filter.
  static Float32List _noise(math.Random r, double secs,
      {double decay = 0.1, double f0 = 4000, double f1 = 400, double attack = 0.002}) {
    final out = _buf(secs);
    var lp = 0.0;
    for (var i = 0; i < out.length; i++) {
      final t = i / rate;
      final f = f0 + (f1 - f0) * (t / secs);
      final a = 1 - math.exp(-2 * math.pi * f / rate);
      lp += ((r.nextDouble() * 2 - 1) - lp) * a;
      final env = (t < attack ? t / attack : 1.0) * math.exp(-t / decay);
      out[i] = lp * env;
    }
    return out;
  }

  static Float32List _tone(double secs, double f0, double f1,
      {double decay = 0.2, String wave = 'sine', double vib = 0, double vibF = 6}) {
    final out = _buf(secs);
    var ph = 0.0;
    for (var i = 0; i < out.length; i++) {
      final t = i / rate;
      var f = f0 * math.pow(f1 / f0, t / secs).toDouble();
      if (vib > 0) f *= 1 + vib * math.sin(2 * math.pi * vibF * t);
      ph += f / rate;
      final p = ph % 1.0;
      double v;
      switch (wave) {
        case 'square':
          v = p < 0.5 ? 1.0 : -1.0;
          break;
        case 'saw':
          v = p * 2 - 1;
          break;
        case 'tri':
          v = p < 0.5 ? p * 4 - 1 : 3 - p * 4;
          break;
        default:
          v = math.sin(2 * math.pi * p);
      }
      out[i] = v * math.exp(-t / decay) * math.min(1.0, t / 0.003);
    }
    return out;
  }

  static Float32List _mix(List<Float32List> parts, [List<double>? gains]) {
    var n = 0;
    for (final p in parts) {
      n = math.max(n, p.length);
    }
    final out = Float32List(n);
    for (var k = 0; k < parts.length; k++) {
      final g = gains == null ? 1.0 : gains[k];
      final p = parts[k];
      for (var i = 0; i < p.length; i++) {
        out[i] += p[i] * g;
      }
    }
    return out;
  }

  static Float32List _lowpass(Float32List s, double f) {
    final a = 1 - math.exp(-2 * math.pi * f / rate);
    var lp = 0.0;
    final out = Float32List(s.length);
    for (var i = 0; i < s.length; i++) {
      lp += (s[i] - lp) * a;
      out[i] = lp;
    }
    return out;
  }

  static Float32List _echo(Float32List s, double delay, double fb, double extra) {
    final d = (delay * rate).round();
    final out = Float32List(s.length + (extra * rate).round());
    for (var i = 0; i < out.length; i++) {
      var v = i < s.length ? s[i] : 0.0;
      if (i >= d) v += out[i - d] * fb;
      out[i] = v;
    }
    return out;
  }

  static final Map<String, Float32List Function(math.Random)> _generators = {
    'pistol': (r) => _mix([
          _noise(r, 0.25, decay: 0.035, f0: 6000, f1: 900),
          _tone(0.2, 160, 60, decay: 0.05)
        ], [1, 0.8]),
    'heavy': (r) => _echo(
        _mix([_noise(r, 0.4, decay: 0.06, f0: 4000, f1: 500), _tone(0.3, 120, 40, decay: 0.08)], [1, 1]),
        0.09, 0.3, 0.3),
    'rifle': (r) => _mix([
          _noise(r, 0.3, decay: 0.045, f0: 7000, f1: 700),
          _tone(0.2, 140, 50, decay: 0.05)
        ], [1, 0.7]),
    'smg': (r) => _mix([_noise(r, 0.14, decay: 0.025, f0: 6000, f1: 1200), _tone(0.1, 180, 80, decay: 0.03)],
        [1, 0.6]),
    'sniper': (r) => _echo(
        _mix([_noise(r, 0.5, decay: 0.08, f0: 8000, f1: 400), _tone(0.4, 110, 35, decay: 0.12)], [1, 1]),
        0.16, 0.35, 0.6),
    'shotgun': (r) => _echo(
        _mix([_noise(r, 0.5, decay: 0.09, f0: 3000, f1: 300), _tone(0.3, 90, 35, decay: 0.1)], [1, 1.2]),
        0.11, 0.25, 0.3),
    'boom': (r) => _mix([
          _noise(r, 1.4, decay: 0.35, f0: 1500, f1: 80, attack: 0.004),
          _tone(1.0, 70, 25, decay: 0.3)
        ], [1, 1.2]),
    'boom_big': (r) => _echo(
        _mix([_noise(r, 2.4, decay: 0.7, f0: 900, f1: 40, attack: 0.01), _tone(1.8, 50, 18, decay: 0.6)],
            [1, 1.4]),
        0.25, 0.3, 0.8),
    'thud': (r) => _mix([_tone(0.18, 110, 50, decay: 0.05), _noise(r, 0.12, decay: 0.03, f0: 900, f1: 200)],
        [1, 0.6]),
    'clang': (r) => _mix([
          _tone(0.6, 523, 520, decay: 0.18),
          _tone(0.6, 1347, 1340, decay: 0.12),
          _tone(0.6, 2210, 2200, decay: 0.08),
          _noise(r, 0.05, decay: 0.01, f0: 8000, f1: 4000)
        ], [1, 0.6, 0.4, 0.5]),
    'glass': (r) {
      final parts = <Float32List>[_noise(r, 0.5, decay: 0.12, f0: 9000, f1: 5000)];
      for (var i = 0; i < 6; i++) {
        final f = 2500 + r.nextDouble() * 3500;
        final t = _tone(0.5, f, f * 0.98, decay: 0.08 + r.nextDouble() * 0.1);
        final shifted = Float32List(t.length + (i * 0.04 * rate).round());
        shifted.setRange(shifted.length - t.length, shifted.length, t);
        parts.add(shifted);
      }
      return _mix(parts, [0.8, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3]);
    },
    'squish': (r) => _lowpass(
        _mix([_noise(r, 0.28, decay: 0.08, f0: 1400, f1: 300), _tone(0.25, 180, 70, decay: 0.07, vib: 0.3, vibF: 30)],
            [1, 0.5]),
        1600),
    'pop': (r) => _tone(0.08, 700, 200, decay: 0.03),
    'click': (r) => _mix([_noise(r, 0.03, decay: 0.005, f0: 6000, f1: 3000), _tone(0.03, 1800, 1500, decay: 0.008)]),
    'laser': (r) => _tone(0.28, 1800, 260, decay: 0.12, wave: 'square'),
    'rail': (r) => _mix([
          _tone(0.6, 200, 2400, decay: 0.3, wave: 'saw'),
          _noise(r, 0.6, decay: 0.2, f0: 8000, f1: 2000)
        ], [0.6, 0.6]),
    'zap': (r) {
      final n = _noise(r, 0.35, decay: 0.12, f0: 8000, f1: 3000);
      for (var i = 0; i < n.length; i++) {
        final t = i / rate;
        n[i] *= (math.sin(2 * math.pi * 55 * t) > 0 ? 1.0 : 0.25);
      }
      return n;
    },
    'flame': (r) => _noise(r, 0.6, decay: 0.3, f0: 1200, f1: 600, attack: 0.05),
    'rocket': (r) => _noise(r, 0.7, decay: 0.4, f0: 600, f1: 2200, attack: 0.03),
    'thump': (r) => _mix([_tone(0.25, 90, 45, decay: 0.08), _noise(r, 0.15, decay: 0.03, f0: 1500, f1: 300)],
        [1, 0.5]),
    'bow': (r) => _tone(0.3, 240, 200, decay: 0.08, wave: 'tri', vib: 0.04, vibF: 25),
    'heal': (r) => _mix([_tone(0.35, 880, 880, decay: 0.15), _tone(0.35, 1320, 1320, decay: 0.12)], [0.6, 0.4]),
    'saw': (r) => _lowpass(
        _mix([_tone(0.35, 150, 160, decay: 0.3, wave: 'saw', vib: 0.05, vibF: 40), _noise(r, 0.35, decay: 0.3, f0: 5000, f1: 5000)],
            [0.7, 0.3]),
        3000),
    'engine': (r) => _lowpass(_tone(0.7, 45, 70, decay: 0.5, wave: 'saw', vib: 0.15, vibF: 18), 600),
    'groan': (r) => _lowpass(_tone(0.8, 120, 75, decay: 0.5, wave: 'saw', vib: 0.03, vibF: 5), 700),
    'yell': (r) => _lowpass(_tone(0.45, 330, 260, decay: 0.3, wave: 'saw', vib: 0.06, vibF: 7), 1400),
    'beep': (r) => _tone(0.15, 1000, 1000, decay: 0.2, wave: 'square'),
    'ui': (r) => _tone(0.04, 1200, 900, decay: 0.012),
  };
}
