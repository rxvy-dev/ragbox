import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/physics.dart';
import '../game/entity.dart';
import '../game/human.dart';
import '../game/maps.dart';
import '../game/sandbox.dart';

class Camera {
  double x = 0, y = -250, zoom = 0.75;

  double toWorldX(double sx, Size size) => (sx - size.width / 2) / zoom + x;
  double toWorldY(double sy, Size size) => (sy - size.height / 2) / zoom + y;
  double toScreenX(double wx, Size size) => (wx - x) * zoom + size.width / 2;
  double toScreenY(double wy, Size size) => (wy - y) * zoom + size.height / 2;
}

final RenderCtx _rc = RenderCtx();

void paintSky(Canvas c, Size size, GameMap map, Camera cam) {
  final rect = Offset.zero & size;
  c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [map.skyTop, map.skyBottom],
        ).createShader(rect));
  final px = cam.x * 0.15, py = cam.y * 0.08;
  switch (map.deco) {
    case 1: // hills
      for (var layer = 0; layer < 2; layer++) {
        final col = Color.lerp(map.skyBottom, map.groundColor, 0.35 + layer * 0.25)!;
        final path = Path()..moveTo(0, size.height);
        for (var sx = 0.0; sx <= size.width + 20; sx += 20) {
          final wx = sx + px * (layer + 1);
          final y = size.height * (0.55 + layer * 0.1) -
              math.sin(wx / (180 + layer * 90)) * 30 -
              math.sin(wx / 77 + layer) * 12 -
              py * (layer + 1);
          path.lineTo(sx, y);
        }
        path.lineTo(size.width, size.height);
        path.close();
        c.drawPath(path, Paint()..color = col);
      }
      break;
    case 2: // stars
      final p = Paint()..color = const Color(0xCCFFFFFF);
      final rng = math.Random(7);
      for (var i = 0; i < 120; i++) {
        final x = (rng.nextDouble() * size.width * 2 - px * 0.3) % size.width;
        final y = (rng.nextDouble() * size.height - py * 0.3) % size.height;
        c.drawCircle(Offset(x, y), rng.nextDouble() * 1.4 + 0.3, p);
      }
      break;
    case 3: // skyline
      final rng = math.Random(3);
      final col = Color.lerp(map.skyBottom, const Color(0xFF000000), 0.5)!;
      final win = Paint()..color = const Color(0x55FFD54F);
      var x = -((px * 0.8) % 80) - 80;
      while (x < size.width + 80) {
        final w = 50 + rng.nextDouble() * 70;
        final h = 80 + rng.nextDouble() * size.height * 0.45;
        final top = size.height * 0.85 - h - py;
        c.drawRect(Rect.fromLTWH(x, top, w - 6, size.height), Paint()..color = col);
        for (var wy = top + 10; wy < size.height * 0.85; wy += 18) {
          for (var wx = x + 6; wx < x + w - 14; wx += 14) {
            if (rng.nextDouble() < 0.35) c.drawRect(Rect.fromLTWH(wx, wy, 6, 8), win);
          }
        }
        x += w;
      }
      break;
    case 4: // lab grid
      final gp = Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1;
      const step = 60.0;
      final ox = -(cam.x * cam.zoom) % step, oy = -(cam.y * cam.zoom) % step;
      for (var x = ox; x < size.width; x += step) {
        c.drawLine(Offset(x, 0), Offset(x, size.height), gp);
      }
      for (var y = oy; y < size.height; y += step) {
        c.drawLine(Offset(0, y), Offset(size.width, y), gp);
      }
      break;
    default: // jagged red mountains
      final col = Color.lerp(map.skyBottom, const Color(0xFF000000), 0.35)!;
      final path = Path()..moveTo(0, size.height);
      final rng = math.Random(11);
      final pts = List.generate(40, (i) => rng.nextDouble());
      for (var sx = 0.0; sx <= size.width + 40; sx += 40) {
        final wx = sx + px;
        final i = (wx / 40).floor();
        final h = pts[i % 40];
        path.lineTo(sx - (wx % 40), size.height * 0.62 - h * size.height * 0.18 - py);
      }
      path.lineTo(size.width, size.height);
      path.close();
      c.drawPath(path, Paint()..color = col);
  }
}

/// Paints the whole scene. [overlay] is called in world space after entities.
void paintWorld(Canvas c, Size size, Sandbox sb, Camera cam,
    {void Function(Canvas c)? overlay, bool showWires = true, bool sky = true}) {
  if (sky) paintSky(c, size, sb.map, cam);
  final shake = sb.fx.screenShake;
  c.save();
  c.translate(size.width / 2, size.height / 2);
  if (shake > 0.05) {
    c.translate((sb.rng.nextDouble() - 0.5) * shake * 2, (sb.rng.nextDouble() - 0.5) * shake * 2);
  }
  c.scale(cam.zoom);
  c.translate(-cam.x, -cam.y);

  final vw = size.width / 2 / cam.zoom + 400, vh = size.height / 2 / cam.zoom + 400;
  bool visible(Entity e) {
    if (e.particles.isEmpty) return false;
    final p = e.particles.first;
    return (p.x - cam.x).abs() < vw + 300 && (p.y - cam.y).abs() < vh + 300;
  }

  _rc.zoom = cam.zoom;
  _rc.time = sb.time;
  _rc.lowDetail = cam.zoom < 0.35;

  sb.mapEntity?.render(c, _rc);
  sb.fx.renderDecals(c);

  final held = <Entity>{};
  for (final e in sb.entities) {
    if (e is Human && e.held != null) held.add(e.held!);
  }
  for (final e in sb.entities) {
    if (e is MapEntity || e is Human || held.contains(e)) continue;
    if (!visible(e)) continue;
    _rc.selected = identical(e, sb.selected);
    _safeRender(c, e);
  }
  for (final e in sb.entities) {
    if (e is! Human || !visible(e)) continue;
    _rc.selected = identical(e, sb.selected);
    _safeRender(c, e);
  }
  for (final e in held) {
    _rc.selected = identical(e, sb.selected);
    _safeRender(c, e);
  }
  _rc.selected = false;

  _paintJoints(c, sb, cam.zoom);
  if (showWires) _paintWires(c, sb, cam.zoom);
  sb.fx.render(c);
  overlay?.call(c);
  c.restore();
}

void _paintJoints(Canvas c, Sandbox sb, double zoom) {
  final rope = Paint()
    ..color = const Color(0xFFC8A165)
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;
  final spring = Paint()
    ..color = const Color(0xFF90A4AE)
    ..strokeWidth = 1.8
    ..style = PaintingStyle.stroke;
  final weld = Paint()..color = const Color(0xFFFF9100);
  final pin = Paint()..color = const Color(0xFFE53935);
  for (final j in sb.joints) {
    final a = j.pa, b = j.pb;
    if (b == null) continue;
    switch (j.type) {
      case JointType.rope:
        c.drawLine(Offset(a.x, a.y), Offset(b.x, b.y), rope);
        if (j.anchor != null) c.drawCircle(Offset(b.x, b.y), 4, pin);
        break;
      case JointType.spring:
        final dx = b.x - a.x, dy = b.y - a.y;
        final l = math.sqrt(dx * dx + dy * dy);
        if (l < 1) break;
        final nx = -dy / l * 6, ny = dx / l * 6;
        final path = Path()..moveTo(a.x, a.y);
        const n = 12;
        for (var i = 1; i < n; i++) {
          final t = i / n;
          final s = i.isEven ? 1.0 : -1.0;
          path.lineTo(a.x + dx * t + nx * s, a.y + dy * t + ny * s);
        }
        path.lineTo(b.x, b.y);
        c.drawPath(path, spring);
        if (j.anchor != null) c.drawCircle(Offset(b.x, b.y), 4, pin);
        break;
      case JointType.pin:
        c.drawCircle(Offset(b.x, b.y), 5, Paint()..color = outline);
        c.drawCircle(Offset(b.x, b.y), 3.5, pin);
        break;
      case JointType.weld:
        for (final s in j.sticks) {
          c.drawCircle(Offset((s.a.x + s.b.x) / 2, (s.a.y + s.b.y) / 2), 2.5, weld);
        }
        break;
      case JointType.grip:
      case JointType.nail:
        break;
    }
  }
}

void _paintWires(Canvas c, Sandbox sb, double zoom) {
  if (sb.links.isEmpty) return;
  final p = Paint()
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  for (final l in sb.links) {
    final live = l.a.powered || l.b.powered || (l.a.isPowerSource && l.a.sourceOn) || (l.b.isPowerSource && l.b.sourceOn);
    p.color = live ? const Color(0xFFFFD600) : const Color(0xFF5D4037);
    final ax = l.a.cx, ay = l.a.cy, bx = l.b.cx, by = l.b.cy;
    final mx = (ax + bx) / 2, my = math.max(ay, by) + 30;
    final path = Path()
      ..moveTo(ax, ay)
      ..quadraticBezierTo(mx, my, bx, by);
    c.drawPath(path, p);
    c.drawCircle(Offset(ax, ay), 3, Paint()..color = p.color);
    c.drawCircle(Offset(bx, by), 3, Paint()..color = p.color);
  }
}

/// Paints a single entity scaled to fit [size] (spawn menu icons, previews).
void paintEntityIcon(Canvas c, Size size, Entity e, {double pad = 6, double time = 0}) {
  var x0 = double.infinity, y0 = double.infinity, x1 = -double.infinity, y1 = -double.infinity;
  for (final s in e.shapes) {
    for (final p in s.pts) {
      x0 = math.min(x0, p.x - s.radius);
      y0 = math.min(y0, p.y - s.radius);
      x1 = math.max(x1, p.x + s.radius);
      y1 = math.max(y1, p.y + s.radius);
    }
  }
  for (final Particle p in e.particles) {
    x0 = math.min(x0, p.x);
    y0 = math.min(y0, p.y);
    x1 = math.max(x1, p.x);
    y1 = math.max(y1, p.y);
  }
  if (!x0.isFinite) return;
  if (e is Human) {
    y0 -= 12 * e.type.scale;
  }
  final w = math.max(1.0, x1 - x0), h = math.max(1.0, y1 - y0);
  final sc = math.min((size.width - pad * 2) / w, (size.height - pad * 2) / h).clamp(0.05, 4.0);
  c.save();
  c.translate(size.width / 2, size.height / 2);
  c.scale(sc);
  c.translate(-(x0 + x1) / 2, -(y0 + y1) / 2);
  final rc = RenderCtx()
    ..zoom = sc
    ..time = time;
  e.render(c, rc);
  c.restore();
}

void _safeRender(Canvas c, Entity e) {
  final n = c.getSaveCount();
  try {
    e.render(c, _rc);
  } catch (err) {
    c.restoreToCount(n);
    // draw a marker so the broken entity is still visible
    c.drawCircle(Offset(e.cx, e.cy), 12, Paint()..color = const Color(0xFFFF00FF));
  }
}
