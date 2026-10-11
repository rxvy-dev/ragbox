import 'dart:math' as math;
import 'dart:ui';

import '../engine/physics.dart';

enum FxKind { blood, spark, smoke, fire, debris, shell, glass, ember, steam, gib, dust, water }

class FxParticle {
  double x, y, vx, vy;
  double life, maxLife;
  double size;
  Color color;
  FxKind kind;
  double rot = 0, spin = 0;
  FxParticle(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, this.kind)
      : maxLife = life;
}

class Tracer {
  double x1, y1, x2, y2, life, maxLife, width;
  Color color;
  Tracer(this.x1, this.y1, this.x2, this.y2, this.life, this.width, this.color) : maxLife = life;
}

class Flash {
  double x, y, r, life, maxLife;
  Color color;
  bool ring;
  Flash(this.x, this.y, this.r, this.life, this.color, {this.ring = false}) : maxLife = life;
}

class Decal {
  double x, y, r;
  Color color;
  Decal(this.x, this.y, this.r, this.color);
}

class Arc {
  List<Offset> pts;
  double life;
  Color color;
  Arc(this.pts, this.life, this.color);
}

/// Cosmetic effects: blood, sparks, smoke, flashes, tracers and decals.
class FxSystem {
  final List<FxParticle> parts = [];
  final List<Tracer> tracers = [];
  final List<Flash> flashes = [];
  final List<Decal> decals = [];
  final List<Arc> arcs = [];
  final math.Random rng = math.Random();
  List<Shape> statics = [];
  double gravity = 980;
  int maxParts = 1400;
  int maxDecals = 900;
  bool gore = true;
  double screenShake = 0;

  double _r(double a, double b) => a + rng.nextDouble() * (b - a);

  void _add(FxParticle p) {
    if (parts.length >= maxParts) parts.removeAt(0);
    parts.add(p);
  }

  void blood(double x, double y, double dx, double dy, int count, Color color,
      {double speed = 300}) {
    if (!gore) return;
    for (var i = 0; i < count; i++) {
      final a = math.atan2(dy, dx) + _r(-0.7, 0.7);
      final s = _r(0.2, 1.0) * speed;
      _add(FxParticle(x, y, math.cos(a) * s, math.sin(a) * s, _r(0.6, 1.6), _r(1.5, 3.8),
          color, FxKind.blood));
    }
  }

  void sparks(double x, double y, double nx, double ny, int count,
      {Color color = const Color(0xFFFFD166)}) {
    for (var i = 0; i < count; i++) {
      final a = math.atan2(ny, nx) + _r(-1.0, 1.0);
      final s = _r(150, 700);
      _add(FxParticle(x, y, math.cos(a) * s, math.sin(a) * s, _r(0.15, 0.45), _r(1, 2.2), color,
          FxKind.spark));
    }
  }

  void smoke(double x, double y, int count, {double size = 10, Color? color}) {
    for (var i = 0; i < count; i++) {
      _add(FxParticle(x + _r(-6, 6), y + _r(-6, 6), _r(-30, 30), _r(-80, -20), _r(0.8, 2.2),
          size * _r(0.6, 1.4), color ?? const Color(0x88555555), FxKind.smoke));
    }
  }

  void fire(double x, double y, int count, {double size = 7}) {
    for (var i = 0; i < count; i++) {
      _add(FxParticle(x + _r(-5, 5), y + _r(-5, 5), _r(-25, 25), _r(-160, -60), _r(0.25, 0.6),
          size * _r(0.6, 1.3), const Color(0xFFFF8A1F), FxKind.fire));
    }
  }

  void debris(double x, double y, int count, Color color, {double speed = 400, double size = 4}) {
    for (var i = 0; i < count; i++) {
      final a = _r(0, math.pi * 2);
      final s = _r(0.3, 1) * speed;
      final p = FxParticle(x, y, math.cos(a) * s, math.sin(a) * s - 120, _r(1.0, 2.5),
          size * _r(0.5, 1.4), color, FxKind.debris)
        ..spin = _r(-12, 12);
      _add(p);
    }
  }

  void glass(double x, double y, int count) {
    for (var i = 0; i < count; i++) {
      final a = _r(0, math.pi * 2);
      final s = _r(80, 450);
      _add(FxParticle(x + _r(-10, 10), y + _r(-10, 10), math.cos(a) * s, math.sin(a) * s - 100,
          _r(0.8, 2.0), _r(2, 5), const Color(0xCCBFE9FF), FxKind.glass)
        ..spin = _r(-15, 15));
    }
  }

  void shell(double x, double y, double dirX) {
    _add(FxParticle(x, y, -dirX * _r(60, 140) + _r(-20, 20), _r(-260, -160), 1.6, 2.4,
        const Color(0xFFD4A537), FxKind.shell)
      ..spin = _r(-20, 20));
  }

  void water(double x, double y, double vx, double vy) {
    _add(FxParticle(x, y, vx, vy, 1.2, _r(2, 3.5), const Color(0xCC4FC3F7), FxKind.water));
  }

  void tracer(double x1, double y1, double x2, double y2,
      {Color color = const Color(0xFFFFE08A), double width = 1.6, double life = 0.07}) {
    tracers.add(Tracer(x1, y1, x2, y2, life, width, color));
    if (tracers.length > 200) tracers.removeAt(0);
  }

  void flash(double x, double y, double r, {Color color = const Color(0xFFFFE6A0), double life = 0.06}) {
    flashes.add(Flash(x, y, r, life, color));
  }

  void explosion(double x, double y, double radius) {
    flashes.add(Flash(x, y, radius * 0.9, 0.18, const Color(0xFFFFF1B8)));
    flashes.add(Flash(x, y, radius * 1.3, 0.35, const Color(0xFFFFFFFF), ring: true));
    fire(x, y, (radius / 6).round().clamp(8, 60), size: radius / 8);
    smoke(x, y, (radius / 8).round().clamp(6, 40), size: radius / 5, color: const Color(0x99333333));
    sparks(x, y, 0, -1, (radius / 6).round().clamp(6, 40));
    screenShake = math.max(screenShake, radius / 25);
  }

  void arc(double x1, double y1, double x2, double y2, {Color color = const Color(0xFF9FE7FF)}) {
    final pts = <Offset>[Offset(x1, y1)];
    const n = 8;
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    final nx = len > 0 ? -dy / len : 0.0, ny = len > 0 ? dx / len : 0.0;
    for (var i = 1; i < n; i++) {
      final t = i / n;
      final off = _r(-1, 1) * len * 0.12;
      pts.add(Offset(x1 + dx * t + nx * off, y1 + dy * t + ny * off));
    }
    pts.add(Offset(x2, y2));
    arcs.add(Arc(pts, 0.12, color));
  }

  void stain(double x, double y, double r, Color c) {
    if (!gore) return;
    decals.add(Decal(x, y, r, c));
    if (decals.length > maxDecals) decals.removeAt(0);
  }

  void update(double dt) {
    screenShake *= math.pow(0.02, dt).toDouble();
    for (var i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      switch (p.kind) {
        case FxKind.smoke:
        case FxKind.steam:
          p.vx *= 0.98;
          p.vy = p.vy * 0.98 - 20 * dt;
          p.size += dt * 14;
          break;
        case FxKind.fire:
        case FxKind.ember:
          p.vy -= 120 * dt;
          p.size *= 0.985;
          break;
        case FxKind.spark:
          p.vy += gravity * 0.6 * dt;
          break;
        default:
          p.vy += gravity * dt;
          p.vx *= 0.995;
          break;
      }
      final nx = p.x + p.vx * dt, ny = p.y + p.vy * dt;
      p.rot += p.spin * dt;
      if (p.kind == FxKind.blood || p.kind == FxKind.debris || p.kind == FxKind.shell ||
          p.kind == FxKind.glass || p.kind == FxKind.gib || p.kind == FxKind.water) {
        Shape? hit;
        for (final s in statics) {
          if (nx < s.minX || nx > s.maxX || ny < s.minY || ny > s.maxY) continue;
          if (s.containsPoint(nx, ny, 0.5)) {
            hit = s;
            break;
          }
        }
        if (hit != null) {
          if (p.kind == FxKind.blood) {
            stain(p.x, p.y, p.size * 1.3, p.color);
            parts.removeAt(i);
            continue;
          }
          if (p.kind == FxKind.water) {
            parts.removeAt(i);
            continue;
          }
          // bounce/settle
          p.vy = -p.vy * 0.3;
          p.vx *= 0.6;
          p.spin *= 0.5;
          if (p.vy.abs() < 40) p.vy = 0;
          continue;
        }
      }
      p.x = nx;
      p.y = ny;
    }
    for (var i = tracers.length - 1; i >= 0; i--) {
      tracers[i].life -= dt;
      if (tracers[i].life <= 0) tracers.removeAt(i);
    }
    for (var i = flashes.length - 1; i >= 0; i--) {
      flashes[i].life -= dt;
      if (flashes[i].life <= 0) flashes.removeAt(i);
    }
    for (var i = arcs.length - 1; i >= 0; i--) {
      arcs[i].life -= dt;
      if (arcs[i].life <= 0) arcs.removeAt(i);
    }
  }

  final Paint _p = Paint()..isAntiAlias = true;
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  void renderDecals(Canvas c) {
    for (final d in decals) {
      _p.color = d.color.withValues(alpha: 0.85);
      c.drawCircle(Offset(d.x, d.y), d.r, _p);
    }
  }

  void render(Canvas c) {
    for (final p in parts) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      switch (p.kind) {
        case FxKind.smoke:
        case FxKind.steam:
          _p.color = p.color.withValues(alpha: p.color.a * t);
          c.drawCircle(Offset(p.x, p.y), p.size, _p);
          break;
        case FxKind.fire:
        case FxKind.ember:
          _p.color = Color.lerp(const Color(0xFFB3261E), const Color(0xFFFFE08A), t)!
              .withValues(alpha: 0.9 * t + 0.1);
          c.drawCircle(Offset(p.x, p.y), p.size * (0.4 + t * 0.6), _p);
          break;
        case FxKind.spark:
          _s
            ..color = p.color.withValues(alpha: t)
            ..strokeWidth = p.size;
          c.drawLine(Offset(p.x, p.y), Offset(p.x - p.vx * 0.02, p.y - p.vy * 0.02), _s);
          break;
        case FxKind.debris:
        case FxKind.shell:
        case FxKind.glass:
        case FxKind.gib:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          _p.color = p.color.withValues(alpha: math.min(1.0, t * 3) * p.color.a);
          c.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size * 1.6, height: p.size), _p);
          c.restore();
          break;
        default:
          _p.color = p.color;
          c.drawCircle(Offset(p.x, p.y), p.size * 0.6, _p);
      }
    }
    for (final tr in tracers) {
      final t = tr.life / tr.maxLife;
      _s
        ..color = tr.color.withValues(alpha: t)
        ..strokeWidth = tr.width;
      c.drawLine(Offset(tr.x1, tr.y1), Offset(tr.x2, tr.y2), _s);
    }
    for (final a in arcs) {
      final path = Path()..moveTo(a.pts[0].dx, a.pts[0].dy);
      for (var i = 1; i < a.pts.length; i++) {
        path.lineTo(a.pts[i].dx, a.pts[i].dy);
      }
      _s
        ..color = a.color.withValues(alpha: 0.35)
        ..strokeWidth = 6;
      c.drawPath(path, _s);
      _s
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 1.6;
      c.drawPath(path, _s);
    }
    for (final f in flashes) {
      final t = f.life / f.maxLife;
      if (f.ring) {
        _s
          ..color = f.color.withValues(alpha: t * 0.6)
          ..strokeWidth = 4 * t + 1;
        c.drawCircle(Offset(f.x, f.y), f.r * (1.2 - t), _s);
      } else {
        _p.color = f.color.withValues(alpha: t);
        c.drawCircle(Offset(f.x, f.y), f.r * (0.6 + 0.4 * t), _p);
      }
    }
  }

  void clear() {
    parts.clear();
    tracers.clear();
    flashes.clear();
    decals.clear();
    arcs.clear();
  }
}
