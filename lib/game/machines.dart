import 'dart:math' as math;
import 'dart:ui';

import '../core/sfx.dart';
import '../engine/physics.dart';
import 'entity.dart';
import 'human.dart';
import 'sandbox.dart';
import 'weapons.dart';

// ---------------------------------------------------------------------------
// Vehicles

enum VehicleKind { car, truck, buggy, monster, bike, tank, cart, bus }

class Vehicle extends Entity {
  final VehicleKind kind;
  late List<Particle> chassis;
  final List<List<Particle>> wheels = []; // [hub, rim...]
  final List<double> wheelR = [];
  double w, h;
  double _cannonCd = 0;
  Color paint;

  Vehicle(this.kind, double x, double y, String defId, {Color? color})
      : w = _spec(kind)[0],
        h = _spec(kind)[1],
        paint = color ?? _color(kind),
        super(defId, material: Mat.metal) {
    final sp = _spec(kind);
    final mass = sp[2];
    final wr = sp[3];
    chassis = makeBox(x, y, w, h, mass);
    addPoly(chassis, friction: 0.6);
    final f = BoxFrame()..from(chassis);
    final positions = kind == VehicleKind.tank
        ? [-0.36, 0.0, 0.36]
        : (kind == VehicleKind.bus ? [-0.36, 0.34] : [-0.36, 0.36]);
    if (kind == VehicleKind.bike) positions
      ..clear()
      ..addAll([-0.42, 0.42]);
    for (final px in positions) {
      final lx = px * w, ly = h / 2 + wr * 0.6;
      final wx = f.wx(lx, ly), wy = f.wy(lx, ly);
      final wheel = makeWheel(wx, wy, wr, sp[4], wr > 30 ? 12 : 10);
      wheels.add(wheel);
      wheelR.add(wr);
      final hub = wheel[0];
      // suspension: hub tied to the two nearest bottom corners + a soft spring
      final c3 = chassis[3], c2 = chassis[2];
      addStick(hub, c3, stiffness: 0.6);
      addStick(hub, c2, stiffness: 0.6);
      final topNear = px < 0 ? chassis[0] : chassis[1];
      addStick(hub, topNear, stiffness: 0.25);
      addPoly(wheel.sublist(1), friction: 1.2);
    }
  }

  // [w, h, chassisMass, wheelRadius, wheelMass]
  static List<double> _spec(VehicleKind k) => switch (k) {
        VehicleKind.car => [190.0, 42.0, 120.0, 24.0, 10.0],
        VehicleKind.truck => [260.0, 56.0, 260.0, 30.0, 18.0],
        VehicleKind.buggy => [140.0, 26.0, 60.0, 26.0, 7.0],
        VehicleKind.monster => [230.0, 50.0, 220.0, 52.0, 30.0],
        VehicleKind.bike => [110.0, 16.0, 35.0, 22.0, 5.0],
        VehicleKind.tank => [250.0, 60.0, 600.0, 22.0, 25.0],
        VehicleKind.cart => [120.0, 24.0, 30.0, 16.0, 4.0],
        VehicleKind.bus => [380.0, 90.0, 500.0, 30.0, 25.0],
      };

  static Color _color(VehicleKind k) => switch (k) {
        VehicleKind.car => const Color(0xFFB3261E),
        VehicleKind.truck => const Color(0xFF2F4B7C),
        VehicleKind.buggy => const Color(0xFFF2A51F),
        VehicleKind.monster => const Color(0xFF6A1B9A),
        VehicleKind.bike => const Color(0xFF212121),
        VehicleKind.tank => const Color(0xFF4B5320),
        VehicleKind.cart => const Color(0xFF8A929C),
        VehicleKind.bus => const Color(0xFFF9A825),
      };

  @override
  String get name => switch (kind) {
        VehicleKind.car => 'Car',
        VehicleKind.truck => 'Truck',
        VehicleKind.buggy => 'Buggy',
        VehicleKind.monster => 'Monster Truck',
        VehicleKind.bike => 'Motorbike',
        VehicleKind.tank => 'Tank',
        VehicleKind.cart => 'Cart',
        VehicleKind.bus => 'Bus',
      };

  bool get hasEngine => kind != VehicleKind.cart;

  @override
  void use() {
    if (kind == VehicleKind.tank) {
      fireCannon();
      return;
    }
    if (hasEngine) {
      activated = !activated;
      Sfx.play(activated ? 'engine' : 'click', vol: 0.6);
    }
  }

  void fireCannon() {
    if (_cannonCd > 0 || !attached) return;
    _cannonCd = 1.2;
    final f = BoxFrame()..from(chassis);
    final hd = f.handed;
    final mx = f.wx(w * 0.62, -h * 0.75), my = f.wy(w * 0.62, -h * 0.75);
    final ang = math.atan2(f.uy, f.ux) - 0.05 * hd;
    final m = Missile(MissileKind.rocket, mx, my, ang);
    sb.add(m);
    m.launch(math.cos(ang) * 1400, math.sin(ang) * 1400);
    sb.fx.flash(mx, my, 30);
    sb.fx.smoke(mx, my, 10, size: 12);
    Sfx.play('heavy', vol: 1, rate: 0.6);
    final rk = 3000 * stepDt / totalMass;
    for (final p in chassis) {
      p.kick(-f.ux * rk * 4, -f.uy * rk * 4);
    }
  }

  @override
  void preStep(double dt) {
    final engine = (kind == VehicleKind.tank ? powered : on) && hasEngine;
    if (!engine) return;
    final f = BoxFrame()..from(chassis);
    final dir = f.handed;
    final torque = switch (kind) {
      VehicleKind.monster => 5200.0,
      VehicleKind.truck || VehicleKind.bus || VehicleKind.tank => 4200.0,
      VehicleKind.bike => 3800.0,
      _ => 3400.0,
    };
    for (var i = 0; i < wheels.length; i++) {
      final wh = wheels[i];
      final hub = wh[0];
      final r = wheelR[i];
      // angular speed estimate from the first rim particle
      final p0 = wh[1];
      final rx = p0.x - hub.x, ry = p0.y - hub.y;
      final rvx = (p0.x - p0.px) - (hub.x - hub.px), rvy = (p0.y - p0.py) - (hub.y - hub.py);
      final omega = (rx * rvy - ry * rvx) / (r * r) / dt; // rad/s
      final maxOmega = 28.0 * (30 / r);
      if (omega * dir > maxOmega) continue;
      for (var k = 1; k < wh.length; k++) {
        final p = wh[k];
        final dx = p.x - hub.x, dy = p.y - hub.y;
        final l = math.sqrt(dx * dx + dy * dy);
        if (l < 1e-6) continue;
        p.ax += -dy / l * torque * dir;
        p.ay += dx / l * torque * dir;
      }
    }
  }

  @override
  void update(double dt) {
    _cannonCd -= dt;
    if ((on && hasEngine && kind != VehicleKind.tank) && sb.rng.nextDouble() < 0.3) {
      final f = BoxFrame()..from(chassis);
      sb.fx.smoke(f.wx(-w / 2 - 4, h * 0.3), f.wy(-w / 2 - 4, h * 0.3), 1, size: 5, color: const Color(0x55777777));
    }
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    // vehicles hurt people they run into
    final o = other.owner;
    if (o is Human && speed > 350) {
      o.receiveHit(Hit(imp.x, imp.y, -imp.nx, -imp.ny, speed / 40, speed * 2, DmgType.blunt, shape: other, source: this));
    }
  }

  @override
  Map<String, dynamic> saveData() => {'c': paint.toARGB32()};

  @override
  void loadData(Map<String, dynamic> d) {
    final c = d['c'];
    if (c is num) paint = Color(c.toInt());
  }

  @override
  void render(Canvas c, RenderCtx r) {
    final col = darken(paint, charred);
    inBox(c, chassis, () {
      final hw = w / 2, hh = h / 2;
      final line = Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      switch (kind) {
        case VehicleKind.car:
        case VehicleKind.truck:
        case VehicleKind.monster:
        case VehicleKind.bus:
          final body = RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh, hw, hh), const Radius.circular(8));
          c.drawRRect(body, Paint()..color = col);
          c.drawRRect(body, line);
          if (kind == VehicleKind.bus) {
            final cab = RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh - 50, hw - 4, -hh + 2), const Radius.circular(8));
            c.drawRRect(cab, Paint()..color = col);
            c.drawRRect(cab, line);
            for (var x = -hw + 14; x < hw - 50; x += 46) {
              c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, -hh - 42, 36, 30), const Radius.circular(4)),
                  Paint()..color = const Color(0xFF9FD8F0));
            }
            break;
          }
          final cabX0 = kind == VehicleKind.truck ? hw * 0.1 : -hw * 0.45;
          final cabX1 = kind == VehicleKind.truck ? hw * 0.75 : hw * 0.4;
          final cab = Path()
            ..moveTo(cabX0, -hh)
            ..lineTo(cabX0 + 18, -hh - h * 0.85)
            ..lineTo(cabX1 - 22, -hh - h * 0.85)
            ..lineTo(cabX1, -hh)
            ..close();
          c.drawPath(cab, Paint()..color = col);
          c.drawPath(cab, line);
          final win = Path()
            ..moveTo(cabX0 + 10, -hh - 3)
            ..lineTo(cabX0 + 22, -hh - h * 0.72)
            ..lineTo(cabX1 - 25, -hh - h * 0.72)
            ..lineTo(cabX1 - 10, -hh - 3)
            ..close();
          c.drawPath(win, Paint()..color = const Color(0xFF9FD8F0));
          c.drawRect(Rect.fromLTWH(hw - 8, -hh + 6, 6, 8), Paint()..color = const Color(0xFFFFF59D));
          c.drawRect(Rect.fromLTWH(-hw + 2, -hh + 6, 5, 8), Paint()..color = const Color(0xFFE53935));
          break;
        case VehicleKind.buggy:
        case VehicleKind.cart:
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh, hw, hh), const Radius.circular(4)), Paint()..color = col);
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh, hw, hh), const Radius.circular(4)), line);
          if (kind == VehicleKind.buggy) {
            final cage = Paint()
              ..color = const Color(0xFF333333)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3;
            c.drawLine(Offset(-hw * 0.5, -hh), Offset(-hw * 0.3, -hh - 50), cage);
            c.drawLine(Offset(-hw * 0.3, -hh - 50), Offset(hw * 0.3, -hh - 50), cage);
            c.drawLine(Offset(hw * 0.3, -hh - 50), Offset(hw * 0.5, -hh), cage);
          } else {
            c.drawLine(Offset(-hw, -hh), Offset(-hw - 10, -hh - 30),
                Paint()
                  ..color = const Color(0xFF555555)
                  ..strokeWidth = 3);
          }
          break;
        case VehicleKind.bike:
          final frame = Paint()
            ..color = col
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round;
          c.drawLine(Offset(-hw * 0.84, hh + 10), Offset(-hw * 0.2, -hh), frame);
          c.drawLine(Offset(-hw * 0.2, -hh), Offset(hw * 0.5, -hh), frame);
          c.drawLine(Offset(hw * 0.5, -hh - 10), Offset(hw * 0.84, hh + 10), frame);
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw * 0.5, -hh - 6, hw * 0.2, hh), const Radius.circular(5)),
              Paint()..color = const Color(0xFFB3261E));
          c.drawRect(Rect.fromLTRB(-hw * 0.6, -hh - 9, -hw * 0.2, -hh - 4), Paint()..color = const Color(0xFF111111));
          break;
        case VehicleKind.tank:
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh * 0.2, hw, hh + 14), const Radius.circular(18)),
              Paint()..color = const Color(0xFF2B2D22));
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw + 6, -hh, hw - 6, hh * 0.3), const Radius.circular(6)),
              Paint()..color = col);
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw * 0.4, -hh - 26, hw * 0.3, -hh + 2), const Radius.circular(10)),
              Paint()..color = col);
          c.drawRect(Rect.fromLTRB(hw * 0.25, -hh - 18, hw * 1.15, -hh - 10), Paint()..color = darken(col, 0.3));
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw * 0.4, -hh - 26, hw * 0.3, -hh + 2), const Radius.circular(10)), line);
          break;
      }
    });
    for (var i = 0; i < wheels.length; i++) {
      final wh = wheels[i];
      final hub = wh[0];
      final rim = wh[1];
      final rr = wheelR[i];
      final ang = math.atan2(rim.y - hub.y, rim.x - hub.x);
      c.save();
      c.translate(hub.x, hub.y);
      c.rotate(ang);
      if (kind == VehicleKind.tank) {
        c.drawCircle(Offset.zero, rr + 1.5, Paint()..color = outline);
        c.drawCircle(Offset.zero, rr, Paint()..color = const Color(0xFF3A3F2E));
        c.drawCircle(Offset.zero, rr * 0.4, Paint()..color = const Color(0xFF6B705C));
      } else {
        c.drawCircle(Offset.zero, rr + 1.5, Paint()..color = outline);
        c.drawCircle(Offset.zero, rr, Paint()..color = const Color(0xFF222225));
        c.drawCircle(Offset.zero, rr * 0.55, Paint()..color = const Color(0xFFB0B4B8));
        final sp = Paint()
          ..color = const Color(0xFF5E646D)
          ..strokeWidth = 2.5;
        for (var k = 0; k < 4; k++) {
          final a = k * math.pi / 2;
          c.drawLine(Offset.zero, Offset(math.cos(a) * rr * 0.5, math.sin(a) * rr * 0.5), sp);
        }
      }
      c.restore();
    }
    if (r.selected) {
      c.drawPath(
          polyPath(chassis),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / r.zoom
            ..color = const Color(0xFFE53935));
    }
  }
}

// ---------------------------------------------------------------------------
// Simple box machine base class

abstract class BoxMachine extends Entity {
  late List<Particle> body;
  double w, h;
  BoxMachine(String defId, double x, double y, this.w, this.h, double mass,
      {Mat mat = Mat.metal, bool startFrozen = false})
      : super(defId, material: mat) {
    body = makeBox(x, y, w, h, mass);
    addPoly(body);
    if (startFrozen) setFrozen(true);
  }

  BoxFrame get frame => BoxFrame()..from(body);

  void art(Canvas c, RenderCtx r);

  @override
  void render(Canvas c, RenderCtx r) {
    inBox(c, body, () => art(c, r));
    if (r.selected) {
      c.drawPath(
          polyPath(body),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / r.zoom
            ..color = const Color(0xFFE53935));
    }
  }

  void plate(Canvas c, Color col, {double radius = 3}) {
    rrect(c, -w / 2, -h / 2, w, h, radius, darken(col, charred), stroke: 1.6);
  }

  void led(Canvas c, double x, double y, bool lit, {Color color = const Color(0xFF00E676)}) {
    c.drawCircle(Offset(x, y), 3.2, Paint()..color = outline);
    c.drawCircle(Offset(x, y), 2.4, Paint()..color = lit ? color : const Color(0xFF263238));
    if (lit) c.drawCircle(Offset(x, y), 7, Paint()..color = color.withValues(alpha: 0.25));
  }
}

class Thruster extends BoxMachine {
  final double force;
  final bool big;
  Thruster(double x, double y, {this.big = false})
      : force = big ? 90000 : 30000,
        super(big ? 'thruster_big' : 'thruster', x, y, big ? 60 : 36, big ? 34 : 20, big ? 10 : 4);

  @override
  String get name => big ? 'Big Thruster' : 'Thruster';

  @override
  void preStep(double dt) {
    if (!on || frozen) return;
    final f = frame;
    final a = force / totalMass;
    for (final p in particles) {
      p.ax += f.ux * a;
      p.ay += f.uy * a;
    }
  }

  @override
  void update(double dt) {
    if (!on) return;
    final f = frame;
    final x = f.wx(-w / 2 - 4, 0), y = f.wy(-w / 2 - 4, 0);
    for (var i = 0; i < (big ? 3 : 2); i++) {
      sb.fx.fire(x - f.ux * 10 * i, y - f.uy * 10 * i, 1, size: big ? 10 : 6);
    }
    if (sb.rng.nextDouble() < 0.1) Sfx.play('rocket', vol: 0.25, rate: big ? 0.7 : 1.1);
  }

  @override
  void art(Canvas c, RenderCtx r) {
    plate(c, const Color(0xFF5E646D));
    final noz = Path()
      ..moveTo(-w / 2, -h * 0.3)
      ..lineTo(-w / 2 - 10, -h * 0.5)
      ..lineTo(-w / 2 - 10, h * 0.5)
      ..lineTo(-w / 2, h * 0.3)
      ..close();
    c.drawPath(noz, Paint()..color = const Color(0xFF3A3F46));
    c.drawPath(
        noz,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
    c.drawRect(Rect.fromLTWH(-w * 0.2, -h * 0.5, w * 0.12, h), Paint()..color = const Color(0xFFFFB300));
    led(c, w * 0.3, 0, on, color: const Color(0xFFFF6D00));
  }
}

class Fan extends BoxMachine {
  double _rot = 0;
  Fan(double x, double y) : super('fan', x, y, 20, 70, 12);

  @override
  String get name => 'Industrial Fan';

  @override
  void preStep(double dt) {
    if (!on) return;
    final f = frame;
    final ox = f.wx(w / 2, 0), oy = f.wy(w / 2, 0);
    const range = 520.0;
    for (final p in sb.world.particles) {
      if (p.invMass == 0 || identical(p.owner, this)) continue;
      final dx = p.x - ox, dy = p.y - oy;
      final along = dx * f.ux + dy * f.uy;
      if (along < 0 || along > range) continue;
      final side = (dx * f.vx + dy * f.vy).abs();
      if (side > 60 + along * 0.25) continue;
      final k = (1 - along / range) * 2600 / (1 + p.mass * 0.15);
      p.ax += f.ux * k;
      p.ay += f.uy * k;
    }
  }

  @override
  void update(double dt) {
    if (on) {
      _rot += dt * 30;
      if (sb.rng.nextDouble() < 0.3) {
        final f = frame;
        sb.fx.smoke(f.wx(w / 2 + 10, (sb.rng.nextDouble() - 0.5) * h), f.wy(w / 2 + 10, 0), 1,
            size: 3, color: const Color(0x33FFFFFF));
      }
    }
  }

  @override
  void art(Canvas c, RenderCtx r) {
    plate(c, const Color(0xFF455A64));
    final bp = Paint()..color = const Color(0xFFB0BEC5);
    for (var i = 0; i < 4; i++) {
      final y = math.sin(_rot + i * math.pi / 2) * h * 0.4;
      c.drawRect(Rect.fromLTWH(w * 0.1, y - 3, w * 0.5, 6), bp);
    }
    led(c, -w * 0.2, -h * 0.4, on);
  }
}

class Magnet extends BoxMachine {
  Magnet(double x, double y) : super('magnet', x, y, 70, 30, 30);

  @override
  String get name => 'Electromagnet';

  @override
  void preStep(double dt) {
    if (!on) return;
    final f = frame;
    final ox = f.wx(0, h / 2 + 4), oy = f.wy(0, h / 2 + 4);
    for (final e in sb.entities) {
      if (identical(e, this) || !e.conductive || e is Human || e.frozen) continue;
      if (e.material != Mat.metal) continue;
      for (final p in e.particles) {
        if (p.invMass == 0) continue;
        final dx = ox - p.x, dy = oy - p.y;
        final d2 = dx * dx + dy * dy;
        if (d2 > 450 * 450 || d2 < 1) continue;
        final d = math.sqrt(d2);
        final k = math.min(6000.0, 4.0e6 / (d2 + 2000));
        p.ax += dx / d * k;
        p.ay += dy / d * k;
      }
    }
  }

  @override
  void art(Canvas c, RenderCtx r) {
    final u = Path()
      ..moveTo(-w / 2, h / 2)
      ..lineTo(-w / 2, -h / 2)
      ..lineTo(w / 2, -h / 2)
      ..lineTo(w / 2, h / 2)
      ..lineTo(w / 2 - 16, h / 2)
      ..lineTo(w / 2 - 16, -h / 2 + 12)
      ..lineTo(-w / 2 + 16, -h / 2 + 12)
      ..lineTo(-w / 2 + 16, h / 2)
      ..close();
    c.drawPath(u, Paint()..color = darken(const Color(0xFFC62828), charred));
    c.drawPath(
        u,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    c.drawRect(Rect.fromLTWH(-w / 2, h / 2 - 7, 16, 7), Paint()..color = const Color(0xFFCFD8DC));
    c.drawRect(Rect.fromLTWH(w / 2 - 16, h / 2 - 7, 16, 7), Paint()..color = const Color(0xFFCFD8DC));
    led(c, 0, -h / 2 + 6, on, color: const Color(0xFF40C4FF));
  }
}

class GravityField extends BoxMachine {
  final bool singularity;
  GravityField(double x, double y, {this.singularity = false})
      : super(singularity ? 'singularity' : 'antigrav', x, y, 40, 40, 20);

  @override
  String get name => singularity ? 'Singularity Core' : 'Anti-Gravity Field';

  double get radius => singularity ? 900 : 320;

  @override
  void preStep(double dt) {
    if (!on) return;
    final ox = cx, oy = cy;
    final g = sb.world.gravityY;
    for (final p in sb.world.particles) {
      if (p.invMass == 0 || identical(p.owner, this)) continue;
      final dx = ox - p.x, dy = oy - p.y;
      final d2 = dx * dx + dy * dy;
      if (d2 > radius * radius) continue;
      if (singularity) {
        final d = math.max(10.0, math.sqrt(d2));
        final k = math.min(20000.0, 8.0e7 / (d2 + 4000));
        p.ax += dx / d * k;
        p.ay += dy / d * k - g * p.gravityScale;
      } else {
        p.ay -= g * p.gravityScale * 1.15;
        p.ax -= (p.x - p.px) / dt * 0.6;
        p.ay -= (p.y - p.py) / dt * 0.6;
      }
    }
  }

  @override
  void update(double dt) {
    if (!on || !singularity) return;
    // swallow things that reach the core
    for (final e in List<Entity>.from(sb.entities)) {
      if (identical(e, this) || e.removed || e.frozen || e.particles.isEmpty) continue;
      final dx = e.cx - cx, dy = e.cy - cy;
      if (dx * dx + dy * dy < 30 * 30) {
        sb.fx.flash(e.cx, e.cy, 30, color: const Color(0xFFB388FF));
        if (e is Human && e.type.bleeds) sb.fx.blood(e.cx, e.cy, 0, -1, 10, e.type.blood);
        sb.removeEntity(e);
        Sfx.play('pop', vol: 0.5, rate: 0.5);
      }
    }
  }

  @override
  void art(Canvas c, RenderCtx r) {
    final col = singularity ? const Color(0xFF311B92) : const Color(0xFF00838F);
    c.drawCircle(Offset.zero, w / 2 + 1.5, Paint()..color = outline);
    c.drawCircle(Offset.zero, w / 2, Paint()..color = darken(col, charred));
    final glow = singularity ? const Color(0xFFB388FF) : const Color(0xFF84FFFF);
    c.drawCircle(Offset.zero, w * 0.22, Paint()..color = on ? glow : const Color(0xFF263238));
    if (on) {
      final rp = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / r.zoom
        ..color = glow.withValues(alpha: 0.18);
      c.drawCircle(Offset.zero, radius, rp);
      final t = (r.time * (singularity ? -1.5 : 0.7)) % 1.0;
      c.drawCircle(Offset.zero, radius * (singularity ? 1 - t : t), rp);
    }
  }
}

class Piston extends Entity {
  late List<Particle> base, head;
  final double len, ext, thick;
  double cur = 0;
  final List<Stick> axial = [];
  final List<Stick> diag = [];
  final bool press;

  Piston(double x, double y, {this.press = false})
      : len = press ? 80 : 60,
        ext = press ? 160 : 110,
        thick = press ? 60 : 30,
        super(press ? 'press' : 'piston', material: Mat.metal) {
    final m = press ? 120.0 : 25.0;
    base = makeBox(x - len / 2, y, len, thick, m);
    head = makeBox(x + len / 2 + 2, y, 20, thick, m * 0.6);
    addPoly(base);
    addPoly(head);
    // base right edge (1,2) to head left edge (0,3)
    axial.add(addStick(base[1], head[0]));
    axial.add(addStick(base[2], head[3]));
    diag.add(addStick(base[1], head[3]));
    diag.add(addStick(base[2], head[0]));
    diag.add(addStick(base[0], head[0]));
    diag.add(addStick(base[3], head[3]));
    cur = axial.first.rest;
  }

  @override
  String get name => press ? 'Hydraulic Press' : 'Piston';

  @override
  void update(double dt) {
    final target = on ? ext : 2.0;
    final speed = press ? 60.0 : 200.0;
    if ((cur - target).abs() < 0.5) return;
    cur += (target - cur).sign * math.min((target - cur).abs(), speed * dt);
    axial[0].rest = cur;
    axial[1].rest = cur;
    final d = math.sqrt(cur * cur + thick * thick);
    diag[0].rest = d;
    diag[1].rest = d;
    diag[2].rest = cur + len;
    diag[3].rest = cur + len;
    for (final s in [...axial, ...diag]) {
      s.stiffness = press ? 1.0 : 0.9;
    }
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    if (!press || !on) return;
    final o = other.owner;
    if (o is Human && identical(mine, shapes[1])) {
      o.receiveHit(Hit(imp.x, imp.y, -imp.nx, -imp.ny, 25, 0, DmgType.crush, shape: other, source: this));
    }
  }

  @override
  Map<String, dynamic> saveData() => {'cur': cur};

  @override
  void loadData(Map<String, dynamic> d) {
    cur = (d['cur'] as num?)?.toDouble() ?? cur;
    for (final s in axial) {
      s.rest = cur;
    }
    final dd = math.sqrt(cur * cur + thick * thick);
    diag[0].rest = dd;
    diag[1].rest = dd;
    diag[2].rest = cur + len;
    diag[3].rest = cur + len;
  }

  @override
  void render(Canvas c, RenderCtx r) {
    // rod
    final a = BoxFrame()..from(base);
    final b = BoxFrame()..from(head);
    c.drawLine(Offset(a.cx, a.cy), Offset(b.cx, b.cy),
        Paint()
          ..color = outline
          ..strokeWidth = thick * 0.3 + 3);
    c.drawLine(Offset(a.cx, a.cy), Offset(b.cx, b.cy),
        Paint()
          ..color = const Color(0xFFCFD8DC)
          ..strokeWidth = thick * 0.3);
    inBox(c, base, () {
      rrect(c, -len / 2, -thick / 2, len, thick, 3, darken(press ? const Color(0xFF37474F) : const Color(0xFFFFB300), charred));
      c.drawCircle(Offset(-len / 2 + 8, 0), 3, Paint()..color = on ? const Color(0xFF00E676) : const Color(0xFF263238));
    });
    inBox(c, head, () {
      rrect(c, -10, -thick / 2, 20, thick, 2, darken(const Color(0xFF546E7A), charred));
    });
    if (r.selected) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / r.zoom
        ..color = const Color(0xFFE53935);
      c.drawPath(polyPath(base), p);
      c.drawPath(polyPath(head), p);
    }
  }
}

class MotorWheel extends Entity {
  late List<Particle> wheel;
  final double r;
  final bool saw;
  double _snd = 0;
  MotorWheel(double x, double y, {this.saw = false})
      : r = saw ? 46 : 36,
        super(saw ? 'sawblade' : 'motor', material: Mat.metal) {
    wheel = makeWheel(x, y, r, saw ? 20 : 14, saw ? 16 : 12);
    addPoly(wheel.sublist(1), friction: 1.2);
    // anchored on its axle by default
    wheel[0].setMass(0);
    activated = true;
  }

  @override
  String get name => saw ? 'Saw Blade' : 'Motor Wheel';

  @override
  void preStep(double dt) {
    if (!on) return;
    final hub = wheel[0];
    for (var k = 1; k < wheel.length; k++) {
      final p = wheel[k];
      final dx = p.x - hub.x, dy = p.y - hub.y;
      final l = math.sqrt(dx * dx + dy * dy);
      if (l < 1e-6) continue;
      final tvx = -dy / l, tvy = dx / l;
      final v = ((p.x - p.px) * tvx + (p.y - p.py) * tvy) / dt;
      final target = saw ? 1400.0 : 500.0;
      final a = (target - v) * 12;
      p.ax += tvx * a;
      p.ay += tvy * a;
    }
  }

  @override
  void update(double dt) {
    if (!saw || !on) return;
    _snd -= dt;
    final hub = wheel[0];
    for (final sh in sb.world.shapesInRadius(hub.x, hub.y, r + 4)) {
      final o = sh.owner;
      if (o is! Entity || identical(o, this) || sh.isStatic) continue;
      final dx = sh.centerX() - hub.x, dy = sh.centerY() - hub.y;
      final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      o.receiveHit(Hit(hub.x + dx / d * r, hub.y + dy / d * r, dx / d, dy / d, 60 * dt, 600, DmgType.sharp,
          shape: sh, source: this));
      sb.fx.sparks(hub.x + dx / d * r, hub.y + dy / d * r, dx / d, dy / d, 1);
      if (_snd <= 0) {
        _snd = 0.25;
        Sfx.play('saw', vol: 0.5);
      }
    }
  }

  @override
  void render(Canvas c, RenderCtx rc) {
    final hub = wheel[0];
    final rim = wheel[1];
    final ang = math.atan2(rim.y - hub.y, rim.x - hub.x);
    c.save();
    c.translate(hub.x, hub.y);
    c.rotate(ang);
    if (saw) {
      final teeth = Path();
      const n = 24;
      for (var i = 0; i < n; i++) {
        final a0 = i * math.pi * 2 / n, a1 = (i + 0.5) * math.pi * 2 / n;
        final p0 = Offset(math.cos(a0) * r, math.sin(a0) * r);
        final p1 = Offset(math.cos(a1) * (r + 6), math.sin(a1) * (r + 6));
        if (i == 0) {
          teeth.moveTo(p0.dx, p0.dy);
        } else {
          teeth.lineTo(p0.dx, p0.dy);
        }
        teeth.lineTo(p1.dx, p1.dy);
      }
      teeth.close();
      c.drawPath(teeth, Paint()..color = const Color(0xFFCFD8DC));
      c.drawPath(
          teeth,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
      c.drawCircle(Offset.zero, r * 0.3, Paint()..color = const Color(0xFF546E7A));
    } else {
      c.drawCircle(Offset.zero, r + 1.5, Paint()..color = outline);
      c.drawCircle(Offset.zero, r, Paint()..color = darken(const Color(0xFF37474F), charred));
      final sp = Paint()
        ..color = const Color(0xFFFFB300)
        ..strokeWidth = 4;
      for (var k = 0; k < 3; k++) {
        final a = k * math.pi * 2 / 3;
        c.drawLine(Offset.zero, Offset(math.cos(a) * r * 0.85, math.sin(a) * r * 0.85), sp);
      }
    }
    c.drawCircle(Offset.zero, 5, Paint()..color = on ? const Color(0xFF00E676) : const Color(0xFF263238));
    c.restore();
    if (rc.selected) {
      c.drawCircle(Offset(hub.x, hub.y), r + 8,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / rc.zoom
            ..color = const Color(0xFFE53935));
    }
  }
}

class Conveyor extends BoxMachine {
  double _scroll = 0;
  Conveyor(double x, double y) : super('conveyor', x, y, 300, 20, 60, startFrozen: true) {
    activated = true;
  }

  @override
  String get name => 'Conveyor Belt';

  @override
  void preStep(double dt) {
    if (!on) return;
    final f = frame;
    final topX = f.wx(0, -h / 2), topY = f.wy(0, -h / 2);
    for (final p in sb.world.particles) {
      if (p.invMass == 0 || identical(p.owner, this)) continue;
      final dx = p.x - topX, dy = p.y - topY;
      final along = dx * f.ux + dy * f.uy;
      if (along.abs() > w / 2) continue;
      final up = -(dx * f.vx + dy * f.vy);
      if (up < -2 || up > 16) continue;
      final v = ((p.x - p.px) * f.ux + (p.y - p.py) * f.uy) / dt;
      final a = (220 - v) * 20;
      p.ax += f.ux * a;
      p.ay += f.uy * a;
    }
  }

  @override
  void update(double dt) {
    if (on) _scroll = (_scroll + dt * 220) % 20;
  }

  @override
  void art(Canvas c, RenderCtx r) {
    rrect(c, -w / 2, -h / 2, w, h, h / 2, darken(const Color(0xFF263238), charred), stroke: 1.6);
    final lp = Paint()
      ..color = const Color(0xFF607D8B)
      ..strokeWidth = 2;
    for (var x = -w / 2 + _scroll; x < w / 2; x += 20) {
      c.drawLine(Offset(x, -h / 2 + 2), Offset(x + 6, -h / 2 + 2), lp);
    }
    for (var x = -w / 2 + h / 2; x < w / 2; x += 50) {
      c.drawCircle(Offset(x, 0), h * 0.3, Paint()..color = const Color(0xFF90A4AE));
    }
  }
}

class LaunchPad extends BoxMachine {
  double _cd = 0;
  LaunchPad(double x, double y) : super('launchpad', x, y, 90, 14, 40, startFrozen: true) {
    activated = true;
  }

  @override
  String get name => 'Launch Pad';

  @override
  void update(double dt) {
    _cd -= dt;
    if (!on || _cd > 0) return;
    final f = frame;
    final topX = f.wx(0, -h / 2), topY = f.wy(0, -h / 2);
    var fired = false;
    final hitEntities = <Entity>{};
    for (final p in sb.world.particles) {
      if (p.invMass == 0 || identical(p.owner, this)) continue;
      final dx = p.x - topX, dy = p.y - topY;
      final along = dx * f.ux + dy * f.uy;
      if (along.abs() > w / 2) continue;
      final up = -(dx * f.vx + dy * f.vy);
      if (up < -2 || up > 18) continue;
      if (p.owner is Entity) hitEntities.add(p.owner as Entity);
    }
    for (final e in hitEntities) {
      final dv = 1500 * stepDt;
      for (final p in e.particles) {
        p.kick(-f.vx * dv, -f.vy * dv);
      }
      fired = true;
    }
    if (fired) {
      _cd = 0.6;
      Sfx.play('thump', vol: 0.8, rate: 1.3);
    }
  }

  @override
  void art(Canvas c, RenderCtx r) {
    plate(c, const Color(0xFF37474F));
    c.drawRect(Rect.fromLTWH(-w / 2 + 6, -h / 2, w - 12, 5), Paint()..color = on ? const Color(0xFF00E676) : const Color(0xFF455A64));
    final ap = Paint()..color = const Color(0xFFFFD600);
    for (var i = -1; i <= 1; i++) {
      final path = Path()
        ..moveTo(i * 22.0 - 6, h / 2 - 2)
        ..lineTo(i * 22.0, -h / 2 + 6)
        ..lineTo(i * 22.0 + 6, h / 2 - 2)
        ..close();
      c.drawPath(path, ap);
    }
  }
}

class Burner extends BoxMachine {
  Burner(double x, double y) : super('burner', x, y, 50, 18, 30, startFrozen: true);

  @override
  String get name => 'Gas Burner';

  @override
  void update(double dt) {
    if (!on) return;
    final f = frame;
    if (sb.rng.nextDouble() < 0.8) {
      final x = f.wx((sb.rng.nextDouble() - 0.5) * w * 0.6, -h / 2);
      final y = f.wy(0, -h / 2);
      sb.shootFlame(x, y, -f.vx * 260 + (sb.rng.nextDouble() - 0.5) * 60, -f.vy * 260, this);
    }
    if (sb.rng.nextDouble() < 0.05) Sfx.play('flame', vol: 0.3);
  }

  @override
  void art(Canvas c, RenderCtx r) {
    plate(c, const Color(0xFF3E2723));
    for (var i = -1; i <= 1; i++) {
      c.drawCircle(Offset(i * 14.0, -h / 2 + 3), 3, Paint()..color = on ? const Color(0xFF40C4FF) : const Color(0xFF111111));
    }
  }
}

class Turret extends BoxMachine with SentryAim {
  double _cd = 0;
  double aim = 0;
  Turret(double x, double y) : super('turret', x, y, 46, 30, 80, startFrozen: true) {
    activated = true;
  }

  @override
  String get name => 'Sentry Turret';

  @override
  void update(double dt) {
    _cd -= dt;
    if (!on) return;
    final f = frame;
    final px = f.wx(0, -h / 2 - 8), py = f.wy(0, -h / 2 - 8);
    final t = pickTarget(sb, px, py, 1300);
    if (t == null) return;
    final tx = t.particles[pN].x, ty = t.particles[pN].y;
    final want = math.atan2(ty - py, tx - px);
    var d = want - aim;
    while (d > math.pi) {
      d -= math.pi * 2;
    }
    while (d < -math.pi) {
      d += math.pi * 2;
    }
    aim += d.clamp(-6 * dt, 6 * dt);
    if (d.abs() < 0.08 && _cd <= 0) {
      _cd = 0.12;
      final mx = px + math.cos(aim) * 34, my = py + math.sin(aim) * 34;
      final a = aim + (sb.rng.nextDouble() - 0.5) * 0.04;
      sb.fireBullet(mx, my, math.cos(a), math.sin(a), damage: 18, force: 2000, source: this);
      sb.fx.flash(mx, my, 10);
      Sfx.play('smg', vol: 0.6);
    }
  }

  @override
  void render(Canvas c, RenderCtx r) {
    super.render(c, r);
    final f = frame;
    final px = f.wx(0, -h / 2 - 8), py = f.wy(0, -h / 2 - 8);
    c.save();
    c.translate(px, py);
    c.rotate(aim);
    rrect(c, 0, -4, 36, 8, 2, const Color(0xFF263238));
    c.restore();
    c.drawCircle(Offset(px, py), 13, Paint()..color = outline);
    c.drawCircle(Offset(px, py), 11.5, Paint()..color = darken(const Color(0xFF546E7A), charred));
    c.drawCircle(Offset(px, py), 3.5, Paint()..color = on ? const Color(0xFFFF1744) : const Color(0xFF263238));
  }

  @override
  void art(Canvas c, RenderCtx r) {
    plate(c, const Color(0xFF37474F));
  }

  @override
  Map<String, dynamic> saveData() => {'aim': aim};

  @override
  void loadData(Map<String, dynamic> d) {
    aim = (d['aim'] as num?)?.toDouble() ?? 0;
  }
}

mixin SentryAim {
  Human? pickTarget(Sandbox sb, double x, double y, double range) {
    Human? best;
    var bd = range;
    for (final hm in sb.humans) {
      if (hm.dead) continue;
      final b = hm.type.behavior;
      if (b != Behavior.hostile && b != Behavior.berserk) continue;
      final dx = hm.cx - x, dy = hm.cy - y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bd && sb.lineOfSight(x, y, hm.particles[pN].x, hm.particles[pN].y)) {
        bd = d;
        best = hm;
      }
    }
    return best;
  }
}

class SpikeTrap extends Entity {
  late List<Particle> base;
  SpikeTrap(double x, double y) : super('spiketrap', material: Mat.metal) {
    base = makeBox(x, y, 120, 16, 50);
    addPoly(base);
    final f = BoxFrame()..from(base);
    for (var i = 0; i < 5; i++) {
      final lx0 = -60 + i * 24.0;
      final a = addP(f.wx(lx0, -8), f.wy(lx0, -8), 1);
      final b = addP(f.wx(lx0 + 12, -34), f.wy(lx0 + 12, -34), 1);
      final c = addP(f.wx(lx0 + 24, -8), f.wy(lx0 + 24, -8), 1);
      for (final bp in base) {
        addStick(a, bp);
        addStick(b, bp);
        addStick(c, bp);
      }
      addPoly([a, b, c], tag: 'spike');
    }
    setFrozen(true);
  }

  @override
  String get name => 'Spike Trap';

  @override
  void render(Canvas c, RenderCtx r) {
    for (var i = 1; i < shapes.length; i++) {
      drawPoly(c, shapes[i].pts, darken(const Color(0xFFCFD8DC), charred), stroke: 1.4);
    }
    drawPoly(c, base, darken(const Color(0xFF37474F), charred));
    if (r.selected) {
      c.drawPath(
          polyPath(base),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / r.zoom
            ..color = const Color(0xFFE53935));
    }
  }
}

class BearTrap extends BoxMachine {
  bool closed = false;
  final List<UserJoint> _clamps = [];
  BearTrap(double x, double y) : super('beartrap', x, y, 60, 10, 12);

  @override
  String get name => 'Bear Trap';

  @override
  void use() {
    // re-open
    for (final j in _clamps) {
      sb.removeJoint(j);
    }
    _clamps.clear();
    closed = false;
    Sfx.play('click', vol: 0.6);
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    if (closed) return;
    final o = other.owner;
    if (o is! Human) return;
    closed = true;
    Sfx.play('clang', vol: 1, rate: 0.8);
    o.receiveHit(Hit(imp.x, imp.y, 0, 1, 35, 0, DmgType.sharp, shape: other, source: this));
    final idx = sb.nearestParticleIndex(o, imp.x, imp.y);
    if (idx >= 0) {
      final j = sb.addJoint(JointType.nail, this, 0, o, idx, undoable: false);
      if (j != null) {
        j.sticks.first.breakForce = 3;
        _clamps.add(j);
      }
    }
  }

  @override
  void art(Canvas c, RenderCtx r) {
    plate(c, const Color(0xFF5D4037), radius: 2);
    final tp = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    if (closed) {
      c.drawLine(Offset(-w * 0.3, -h / 2), Offset(0, -h / 2 - 18), tp);
      c.drawLine(Offset(w * 0.3, -h / 2), Offset(0, -h / 2 - 18), tp);
    } else {
      c.drawArc(Rect.fromLTWH(-w / 2, -h / 2 - 12, w * 0.48, 24), math.pi, math.pi / 2, false, tp);
      c.drawArc(Rect.fromLTWH(w * 0.02, -h / 2 - 12, w * 0.48, 24), math.pi * 1.5, math.pi / 2, false, tp);
    }
  }
}

// ---------------------------------------------------------------------------
// Electrical

enum ElecKind { battery, generator, button, toggle, timer, sensor, tripwire, plate, lamp, siren, shockPad, tesla, logicNot }

class Electric extends BoxMachine {
  final ElecKind kind;
  double pulse = 0;
  double interval = 2;
  double _t = 0;
  bool _tripped = false;
  double _zapCd = 0;
  double _siren = 0;

  Electric(this.kind, double x, double y, String defId)
      : super(defId, x, y, _dims(kind).width, _dims(kind).height, _mass(kind),
            startFrozen: kind == ElecKind.plate || kind == ElecKind.tripwire || kind == ElecKind.shockPad);

  static Size _dims(ElecKind k) => switch (k) {
        ElecKind.battery => const Size(30, 44),
        ElecKind.generator => const Size(80, 56),
        ElecKind.button => const Size(30, 14),
        ElecKind.toggle => const Size(30, 22),
        ElecKind.timer => const Size(34, 34),
        ElecKind.sensor => const Size(26, 26),
        ElecKind.tripwire => const Size(20, 16),
        ElecKind.plate => const Size(90, 8),
        ElecKind.lamp => const Size(24, 30),
        ElecKind.siren => const Size(26, 22),
        ElecKind.shockPad => const Size(110, 10),
        ElecKind.tesla => const Size(36, 110),
        ElecKind.logicNot => const Size(30, 20),
      };

  static double _mass(ElecKind k) => switch (k) {
        ElecKind.generator => 90.0,
        ElecKind.tesla => 60.0,
        ElecKind.battery => 12.0,
        _ => 4.0,
      };

  @override
  String get name => switch (kind) {
        ElecKind.battery => 'Battery',
        ElecKind.generator => 'Generator',
        ElecKind.button => 'Button',
        ElecKind.toggle => 'Switch',
        ElecKind.timer => 'Timer',
        ElecKind.sensor => 'Motion Sensor',
        ElecKind.tripwire => 'Laser Tripwire',
        ElecKind.plate => 'Pressure Plate',
        ElecKind.lamp => 'Lamp',
        ElecKind.siren => 'Siren',
        ElecKind.shockPad => 'Shock Pad',
        ElecKind.tesla => 'Tesla Coil',
        ElecKind.logicNot => 'NOT Gate',
      };

  @override
  bool get isPowerSource => switch (kind) {
        ElecKind.battery || ElecKind.generator || ElecKind.button || ElecKind.toggle ||
        ElecKind.timer || ElecKind.sensor || ElecKind.tripwire || ElecKind.plate || ElecKind.logicNot =>
          true,
        _ => false,
      };

  @override
  bool get sourceOn => switch (kind) {
        ElecKind.battery || ElecKind.generator => !activated,
        ElecKind.button || ElecKind.timer => pulse > 0,
        ElecKind.toggle => activated,
        ElecKind.sensor || ElecKind.tripwire || ElecKind.plate => _tripped,
        ElecKind.logicNot => !_notInput,
        _ => false,
      };

  bool _notInput = false;

  @override
  bool get conductive => true;

  @override
  void use() {
    switch (kind) {
      case ElecKind.button:
        pulse = 0.35;
        Sfx.play('click', vol: 0.7);
        break;
      case ElecKind.timer:
        interval = interval >= 5 ? 0.5 : (interval >= 2 ? 5 : (interval >= 1 ? 2 : 1));
        Sfx.play('click', vol: 0.5, rate: 1.3);
        break;
      default:
        activated = !activated;
        Sfx.play('click', vol: 0.6);
    }
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    if (kind == ElecKind.button && speed > 200) pulse = 0.35;
  }

  @override
  void update(double dt) {
    if (pulse > 0) pulse -= dt;
    _zapCd -= dt;
    switch (kind) {
      case ElecKind.timer:
        _t += dt;
        if (_t >= interval) {
          _t = 0;
          pulse = 0.2;
        }
        break;
      case ElecKind.sensor:
        _tripped = false;
        for (final h in sb.humans) {
          final dx = h.cx - cx, dy = h.cy - cy;
          if (dx * dx + dy * dy < 220 * 220 && !h.dead) {
            _tripped = true;
            break;
          }
        }
        break;
      case ElecKind.tripwire:
        final tf = frame;
        final hits = sb.world.raycast(tf.wx(w / 2, 0), tf.wy(w / 2, 0), tf.ux, tf.uy, 900,
            filter: (s) => !identical(s.owner, this));
        _tripped = false;
        _beamLen = 900;
        if (hits.isNotEmpty) {
          _beamLen = hits.first.t;
          final o = hits.first.shape.owner;
          _tripped = o is Entity && !o.frozen && o.particles.isNotEmpty && o.particles.first.invMass > 0;
        }
        break;
      case ElecKind.plate:
        final pf = frame;
        final topX = pf.wx(0, -h / 2), topY = pf.wy(0, -h / 2);
        _tripped = false;
        for (final s in sb.world.shapesInRadius(topX, topY, w / 2 + 2)) {
          final o = s.owner;
          if (o is Entity && !identical(o, this) && !o.frozen && s.distanceTo(topX, topY) < w / 2) {
            final sy = s.centerY();
            if ((sy - topY) < 4) {
              _tripped = true;
              break;
            }
          }
        }
        break;
      case ElecKind.logicNot:
        // inverts: powered by anything other than itself → output off
        _notInput = powered;
        break;
      case ElecKind.shockPad:
        if (on && _zapCd <= 0) {
          _zapCd = 0.25;
          final sf = frame;
          for (final s in sb.world.shapesInRadius(sf.wx(0, -h / 2), sf.wy(0, -h / 2), w / 2)) {
            final o = s.owner;
            if (o is Human) {
              o.receiveHit(Hit(s.centerX(), s.centerY(), 0, -1, 12, 400, DmgType.electric, shape: s));
              sb.fx.arc(sf.wx((sb.rng.nextDouble() - 0.5) * w, -h / 2), sf.wy(0, -h / 2), s.centerX(), s.centerY());
              Sfx.play('zap', vol: 0.5);
            }
          }
        }
        break;
      case ElecKind.tesla:
        if (on && _zapCd <= 0) {
          _zapCd = 0.45;
          final cf = frame;
          final tx = cf.wx(0, -h / 2 - 10), ty = cf.wy(0, -h / 2 - 10);
          Entity? best;
          var bd = 380.0;
          for (final e in sb.entities) {
            if (identical(e, this) || e.removed || e.particles.isEmpty) continue;
            if (!(e is Human || (e.conductive && e.material == Mat.metal))) continue;
            final dx = e.cx - tx, dy = e.cy - ty;
            final d = math.sqrt(dx * dx + dy * dy);
            if (d < bd) {
              bd = d;
              best = e;
            }
          }
          if (best != null) {
            sb.fx.arc(tx, ty, best.cx, best.cy);
            best.receiveHit(Hit(best.cx, best.cy, 0, 0, 22, 0, DmgType.electric));
            Sfx.play('zap', vol: 0.7);
          } else if (sb.rng.nextDouble() < 0.5) {
            final a = sb.rng.nextDouble() * math.pi * 2;
            sb.fx.arc(tx, ty, tx + math.cos(a) * 60, ty + math.sin(a) * 60);
          }
        }
        break;
      case ElecKind.siren:
        if (on) {
          _siren -= dt;
          if (_siren <= 0) {
            _siren = 0.6;
            Sfx.play('beep', vol: 0.5);
          }
        }
        break;
      default:
        break;
    }
  }

  double _beamLen = 900;

  @override
  void render(Canvas c, RenderCtx r) {
    if (kind == ElecKind.tripwire) {
      final f = frame;
      final x0 = f.wx(w / 2, 0), y0 = f.wy(w / 2, 0);
      c.drawLine(Offset(x0, y0), Offset(x0 + f.ux * _beamLen, y0 + f.uy * _beamLen),
          Paint()
            ..color = (_tripped ? const Color(0xFFFF1744) : const Color(0xFFFF5252)).withValues(alpha: 0.7)
            ..strokeWidth = 1.5);
    }
    if (kind == ElecKind.lamp && on) {
      c.drawCircle(Offset(cx, cy), 140,
          Paint()
            ..color = const Color(0x22FFF59D)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    }
    if (kind == ElecKind.siren && on && (r.time * 3).floor() % 2 == 0) {
      c.drawCircle(Offset(cx, cy), 60, Paint()..color = const Color(0x33FF1744));
    }
    super.render(c, r);
  }

  @override
  void art(Canvas c, RenderCtx r) {
    final hw = w / 2, hh = h / 2;
    switch (kind) {
      case ElecKind.battery:
        plate(c, const Color(0xFF263238));
        c.drawRect(Rect.fromLTWH(-hw, -hh, w, h * 0.3), Paint()..color = const Color(0xFFFFB300));
        c.drawRect(Rect.fromLTWH(-5, -hh - 5, 10, 5), Paint()..color = const Color(0xFF9E9E9E));
        led(c, 0, hh * 0.4, sourceOn);
        break;
      case ElecKind.generator:
        plate(c, const Color(0xFFC62828));
        c.drawRect(Rect.fromLTWH(-hw + 6, -hh + 6, w * 0.45, h - 12), Paint()..color = const Color(0xFF263238));
        led(c, hw * 0.5, -hh * 0.4, sourceOn);
        break;
      case ElecKind.button:
        plate(c, const Color(0xFF455A64), radius: 2);
        rrect(c, -8, -hh - (pulse > 0 ? 2 : 6), 16, 8, 3, const Color(0xFFE53935));
        break;
      case ElecKind.toggle:
        plate(c, const Color(0xFF455A64), radius: 2);
        final lp = Paint()
          ..color = const Color(0xFF212121)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
        c.drawLine(Offset.zero, Offset(activated ? 10 : -10, -hh - 8), lp);
        led(c, hw - 6, hh - 6, activated);
        break;
      case ElecKind.timer:
        c.drawCircle(Offset.zero, hw + 1.5, Paint()..color = outline);
        c.drawCircle(Offset.zero, hw, Paint()..color = const Color(0xFFECEFF1));
        final a = (_t / interval) * math.pi * 2 - math.pi / 2;
        c.drawLine(Offset.zero, Offset(math.cos(a) * hw * 0.8, math.sin(a) * hw * 0.8),
            Paint()
              ..color = const Color(0xFFE53935)
              ..strokeWidth = 2);
        led(c, 0, hh * 0.5, pulse > 0);
        break;
      case ElecKind.sensor:
        plate(c, const Color(0xFFECEFF1), radius: 6);
        c.drawCircle(Offset.zero, 7, Paint()..color = _tripped ? const Color(0xFFFF1744) : const Color(0xFF37474F));
        break;
      case ElecKind.tripwire:
        plate(c, const Color(0xFF37474F));
        c.drawCircle(Offset(hw - 3, 0), 3, Paint()..color = const Color(0xFFFF1744));
        break;
      case ElecKind.plate:
        plate(c, _tripped ? const Color(0xFF66BB6A) : const Color(0xFF9E9E9E), radius: 2);
        break;
      case ElecKind.lamp:
        c.drawRect(Rect.fromLTWH(-6, hh * 0.2, 12, hh * 0.8), Paint()..color = const Color(0xFF455A64));
        c.drawCircle(Offset(0, -hh * 0.2), hw * 0.75 + 1.5, Paint()..color = outline);
        c.drawCircle(Offset(0, -hh * 0.2), hw * 0.75, Paint()..color = on ? const Color(0xFFFFF59D) : const Color(0xFF90A4AE));
        break;
      case ElecKind.siren:
        plate(c, const Color(0xFF263238), radius: 4);
        c.drawArc(Rect.fromLTWH(-hw + 3, -hh - 8, w - 6, 20), math.pi, math.pi, true,
            Paint()..color = on ? const Color(0xFFFF1744) : const Color(0xFF7F0000));
        break;
      case ElecKind.shockPad:
        plate(c, const Color(0xFF263238), radius: 2);
        final yp = Paint()..color = const Color(0xFFFFD600);
        for (var x = -hw + 5; x < hw - 10; x += 20) {
          c.drawRect(Rect.fromLTWH(x, -hh, 10, 3), yp);
        }
        if (on) {
          c.drawRect(Rect.fromLTWH(-hw, -hh - 3, w, 3), Paint()..color = const Color(0x889FE7FF));
        }
        break;
      case ElecKind.tesla:
        rrect(c, -hw, hh - 20, w, 20, 3, const Color(0xFF37474F));
        for (var y = -hh + 18; y < hh - 22; y += 8) {
          c.drawRect(Rect.fromLTWH(-hw * 0.6, y, w * 0.6 * 2, 5), Paint()..color = const Color(0xFFB87333));
        }
        c.drawCircle(Offset(0, -hh + 8), 12, Paint()..color = outline);
        c.drawCircle(Offset(0, -hh + 8), 10.5, Paint()..color = const Color(0xFFCFD8DC));
        if (on) c.drawCircle(Offset(0, -hh + 8), 18, Paint()..color = const Color(0x339FE7FF));
        break;
      case ElecKind.logicNot:
        plate(c, const Color(0xFF1A237E), radius: 3);
        final tri = Path()
          ..moveTo(-8, -6)
          ..lineTo(6, 0)
          ..lineTo(-8, 6)
          ..close();
        c.drawPath(tri, Paint()..color = const Color(0xFFFFFFFF));
        c.drawCircle(const Offset(9, 0), 2.5, Paint()..color = const Color(0xFFFFFFFF));
        led(c, hw - 5, -hh + 5, sourceOn);
        break;
    }
  }

  @override
  Map<String, dynamic> saveData() => {'iv': interval};

  @override
  void loadData(Map<String, dynamic> d) {
    interval = (d['iv'] as num?)?.toDouble() ?? 2;
  }
}

/// A chain of links that can be grabbed and swung.
class Chain extends Entity {
  final int links;
  Chain(double x, double y, {this.links = 14}) : super('chain', material: Mat.metal) {
    Particle? prev;
    for (var i = 0; i <= links; i++) {
      final p = addP(x + i * 14.0, y, 0.8);
      if (prev != null) {
        addStick(prev, p);
        addCapsule(prev, p, 3, friction: 0.5);
      }
      prev = p;
    }
  }

  @override
  String get name => 'Chain';

  @override
  void render(Canvas c, RenderCtx r) {
    final col = darken(const Color(0xFF9EA4AB), charred);
    for (var i = 0; i < particles.length - 1; i++) {
      final a = particles[i], b = particles[i + 1];
      drawCapsule(c, a.x, a.y, b.x, b.y, i.isEven ? 3.2 : 2.2, col, stroke: 1.0);
    }
    if (r.selected) {
      for (final p in particles) {
        c.drawCircle(Offset(p.x, p.y), 5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5 / r.zoom
              ..color = const Color(0xFFE53935));
      }
    }
  }
}
