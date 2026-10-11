import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../engine/physics.dart';
import 'sandbox.dart';

enum Mat { wood, metal, glass, stone, rubber, flesh, plastic, explosive, bone, ice }

class MatInfo {
  final Color color;
  final double friction;
  final double toughness; // damage multiplier divisor
  final double pierce; // bullet power lost per unit of thickness
  final bool sparks;
  final double flammability;
  final bool conductive;
  final String impactSound;
  const MatInfo(this.color, this.friction, this.toughness, this.pierce, this.sparks,
      this.flammability, this.conductive, this.impactSound);
}

const Map<Mat, MatInfo> matInfo = {
  Mat.wood: MatInfo(Color(0xFF9C6B3C), 0.7, 1.0, 0.012, false, 0.6, false, 'thud'),
  Mat.metal: MatInfo(Color(0xFF8A929C), 0.45, 4.0, 0.05, true, 0.0, true, 'clang'),
  Mat.glass: MatInfo(Color(0xAA9FD8F0), 0.3, 0.4, 0.004, false, 0.0, false, 'glass'),
  Mat.stone: MatInfo(Color(0xFF7D7A75), 0.8, 3.0, 0.04, true, 0.0, false, 'thud'),
  Mat.rubber: MatInfo(Color(0xFF2D2D30), 1.0, 1.5, 0.01, false, 0.3, false, 'thud'),
  Mat.flesh: MatInfo(Color(0xFFE0A47A), 0.8, 1.0, 0.008, false, 0.15, true, 'squish'),
  Mat.plastic: MatInfo(Color(0xFFD9D4C7), 0.5, 0.8, 0.008, false, 0.4, false, 'thud'),
  Mat.explosive: MatInfo(Color(0xFFB3261E), 0.6, 0.8, 0.01, false, 1.0, false, 'thud'),
  Mat.bone: MatInfo(Color(0xFFE8E2CF), 0.7, 1.2, 0.01, false, 0.0, false, 'thud'),
  Mat.ice: MatInfo(Color(0xCCBFE6FF), 0.05, 0.8, 0.01, false, 0.0, false, 'glass'),
};

enum DmgType { bullet, blunt, sharp, explosion, fire, electric, laser, cold, heal, crush }

class Hit {
  final double x, y; // world point
  final double dx, dy; // unit direction of travel
  double damage;
  final double force; // impulse magnitude (mass*units/second)
  final DmgType type;
  final Shape? shape;
  final Entity? source;
  /// Set by the receiver when the projectile is stopped (armor, ricochet).
  bool stopped = false;
  Hit(this.x, this.y, this.dx, this.dy, this.damage, this.force, this.type,
      {this.shape, this.source});
}

class RenderCtx {
  double zoom = 1;
  double time = 0;
  bool selected = false;
  bool lowDetail = false;
}

/// Base class for everything that lives in the sandbox.
abstract class Entity {
  Sandbox? _sb;
  Sandbox get sb => _sb!;
  bool get attached => _sb != null;
  void attach(Sandbox s) => _sb = s;
  void detach() => _sb = null;

  int id = 0;
  final String defId;
  final List<Particle> particles = [];
  final List<Stick> sticks = [];
  final List<Shape> shapes = [];
  final List<AngleLimit> angles = [];

  double hp = double.infinity;
  double maxHp = double.infinity;
  bool removed = false;
  bool frozen = false;
  bool activated = false;
  bool powered = false;
  bool wasPowered = false;
  double burning = 0; // seconds of fire left
  double charred = 0; // 0..1 visual darkening
  double heat = 0; // laser/flame heat buildup
  Mat material;
  List<double> _savedMass = const [];
  /// spawn order serial for undo
  double spawnTime = 0;

  Entity(this.defId, {this.material = Mat.wood});

  // --- construction helpers -------------------------------------------
  Particle addP(double x, double y, double mass) {
    final p = Particle(x, y, mass)..owner = this;
    particles.add(p);
    if (attached) sb.world.addParticle(p);
    return p;
  }

  Stick addStick(Particle a, Particle b,
      {double? rest, double stiffness = 1, StickKind kind = StickKind.rigid, double breakForce = 0}) {
    final s = Stick(a, b, rest: rest, stiffness: stiffness, kind: kind, breakForce: breakForce)
      ..tag = this;
    sticks.add(s);
    if (attached) sb.world.addStick(s);
    return s;
  }

  /// Fully braces a set of particles so they form a rigid body.
  void brace(List<Particle> ps, {double stiffness = 1}) {
    for (var i = 0; i < ps.length; i++) {
      for (var j = i + 1; j < ps.length; j++) {
        addStick(ps[i], ps[j], stiffness: stiffness);
      }
    }
  }

  Shape addPoly(List<Particle> ps, {double friction = -1, double restitution = 0, Object? tag}) {
    final s = Shape.poly(ps,
        owner: this,
        friction: friction < 0 ? matInfo[material]!.friction : friction,
        restitution: restitution,
        tag: tag);
    shapes.add(s);
    if (attached) sb.world.addShape(s);
    return s;
  }

  Shape addCapsule(Particle a, Particle b, double r,
      {double friction = -1, double restitution = 0, Object? tag}) {
    final s = Shape.capsule(a, b, r,
        owner: this,
        friction: friction < 0 ? matInfo[material]!.friction : friction,
        restitution: restitution,
        tag: tag);
    shapes.add(s);
    if (attached) sb.world.addShape(s);
    return s;
  }

  AngleLimit addAngle(Particle a, Particle b, Particle c, double mn, double mx,
      {double stiffness = 0.5, double? target}) {
    final al = AngleLimit(a, b, c, mn, mx, stiffness: stiffness, target: target);
    angles.add(al);
    if (attached) sb.world.addAngle(al);
    return al;
  }

  /// Builds a rigid box centred at (x, y), rotated by [rot].
  List<Particle> makeBox(double x, double y, double w, double h, double mass,
      {double rot = 0}) {
    final cs = math.cos(rot), sn = math.sin(rot);
    final hw = w / 2, hh = h / 2;
    final local = [
      [-hw, -hh],
      [hw, -hh],
      [hw, hh],
      [-hw, hh]
    ];
    final ps = <Particle>[];
    for (final l in local) {
      ps.add(addP(x + l[0] * cs - l[1] * sn, y + l[0] * sn + l[1] * cs, mass / 4));
    }
    brace(ps);
    return ps;
  }

  /// Builds a rigid regular polygon (wheel/ball). Returns [hub, rim...].
  List<Particle> makeWheel(double x, double y, double r, double mass, int sides) {
    final hub = addP(x, y, mass * 0.2);
    final rim = <Particle>[];
    for (var i = 0; i < sides; i++) {
      final a = i / sides * math.pi * 2;
      rim.add(addP(x + math.cos(a) * r, y + math.sin(a) * r, mass * 0.8 / sides));
    }
    for (var i = 0; i < sides; i++) {
      addStick(hub, rim[i]);
      addStick(rim[i], rim[(i + 1) % sides]);
      addStick(rim[i], rim[(i + sides ~/ 2) % sides]);
      addStick(rim[i], rim[(i + 2) % sides]);
    }
    return [hub, ...rim];
  }

  // --- frame helpers ----------------------------------------------------
  double get cx {
    var s = 0.0;
    for (final p in particles) {
      s += p.x;
    }
    return particles.isEmpty ? 0 : s / particles.length;
  }

  double get cy {
    var s = 0.0;
    for (final p in particles) {
      s += p.y;
    }
    return particles.isEmpty ? 0 : s / particles.length;
  }

  double get vx {
    var s = 0.0;
    for (final p in particles) {
      s += p.vx;
    }
    return particles.isEmpty ? 0 : s / particles.length;
  }

  double get vy {
    var s = 0.0;
    for (final p in particles) {
      s += p.vy;
    }
    return particles.isEmpty ? 0 : s / particles.length;
  }

  double get totalMass {
    var m = 0.0;
    for (final p in particles) {
      m += p.mass;
    }
    return m;
  }

  /// Orientation from particle 0 to particle 1 (rigid bodies built by makeBox).
  double get angle {
    if (particles.length < 2) return 0;
    final a = particles[0], b = particles[1];
    return math.atan2(b.y - a.y, b.x - a.x);
  }

  bool get isStaticBody => frozen;
  bool get isHuman => false;
  bool get canBurn => matInfo[material]!.flammability > 0;
  bool get conductive => matInfo[material]!.conductive;
  String get name => defId;

  // --- power --------------------------------------------------------------
  bool get isPowerSource => false;
  bool get sourceOn => false;
  bool get on => activated || powered;

  // --- lifecycle ------------------------------------------------------------
  void update(double dt) {}
  /// Called before every physics sub step (apply forces here).
  void preStep(double dt) {}
  void render(Canvas c, RenderCtx r);

  /// Tap with the Use tool / Activate button.
  void use() {
    activated = !activated;
  }

  void onPowerChanged(bool now) {}

  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    if (speed > 900 && hp.isFinite) {
      damage((speed - 900) / 60, DmgType.blunt);
    }
  }

  void damage(double amount, DmgType type) {
    if (!hp.isFinite) return;
    hp -= amount / matInfo[material]!.toughness;
    if (hp <= 0) destroy();
  }

  /// Called when a bullet/explosion/etc hits one of this entity's shapes.
  void receiveHit(Hit h) {
    if (h.type == DmgType.fire || h.type == DmgType.laser) {
      ignite(h.type == DmgType.laser ? 3 : 1.5);
    }
    damage(h.damage, h.type);
    if (h.shape != null) {
      applyImpulseAt(h.shape!, h.x, h.y, h.dx * h.force, h.dy * h.force);
    } else {
      final m = totalMass;
      if (m > 0) {
        final dt = stepDt;
        for (final p in particles) {
          p.kick(h.dx * h.force / m * dt, h.dy * h.force / m * dt);
        }
      }
    }
  }

  /// Duration of the current physics sub step.
  double get stepDt => attached ? sb.world.prevDt : 1 / 120.0;

  /// Distributes an impulse (mass*units/second) over the particles of [s]
  /// weighted by proximity to (x, y).
  void applyImpulseAt(Shape s, double x, double y, double ix, double iy) {
    final dt = stepDt;
    var wsum = 0.0;
    final ws = <double>[];
    for (final p in s.pts) {
      final d = math.sqrt((p.x - x) * (p.x - x) + (p.y - y) * (p.y - y));
      final w = 1 / (1 + d / 12);
      ws.add(w);
      wsum += w;
    }
    if (wsum <= 0) return;
    // impulse spreads over the whole body mass (rigid bodies)
    final bodyMass = math.max(totalMass, 0.001);
    for (var i = 0; i < s.pts.length; i++) {
      final p = s.pts[i];
      if (p.invMass == 0) continue;
      final share = ws[i] / wsum;
      final k = share * s.pts.length / bodyMass * dt;
      p.kick(ix * k, iy * k);
    }
  }

  void ignite([double seconds = 6]) {
    if (!canBurn) return;
    burning = math.max(burning, seconds * (0.5 + matInfo[material]!.flammability));
  }

  /// Destroy the entity (break, explode...). Default removes it.
  void destroy() {
    if (removed) return;
    sb.removeEntity(this);
  }

  void setFrozen(bool f) {
    if (f == frozen) return;
    frozen = f;
    if (f) {
      _savedMass = particles.map((p) => p.mass).toList();
      for (final p in particles) {
        p.setMass(0);
        p.px = p.x;
        p.py = p.y;
      }
    } else {
      for (var i = 0; i < particles.length; i++) {
        particles[i].setMass(i < _savedMass.length ? _savedMass[i] : 1.0);
      }
    }
  }

  /// Mirror horizontally around the entity center.
  void flip() {
    final c = cx;
    for (final p in particles) {
      p.x = 2 * c - p.x;
      p.px = 2 * c - p.px;
    }
    for (final a in angles) {
      final mn = a.min, mx = a.max;
      a.min = math.pi * 2 - mx;
      a.max = math.pi * 2 - mn;
      if (a.target != null) a.target = math.pi * 2 - a.target!;
    }
    // Polygon winding is irrelevant to the solver (normals are oriented by
    // centroid), so nothing else is needed.
  }

  /// Entity specific persistent data.
  Map<String, dynamic> saveData() => {};
  void loadData(Map<String, dynamic> d) {}

  Map<String, dynamic> toJson() {
    final ps = <double>[];
    for (final p in particles) {
      ps..add(_r(p.x))..add(_r(p.y))..add(_r(p.px))..add(_r(p.py));
    }
    return {
      'id': id,
      'def': defId,
      'hp': hp.isFinite ? hp : -1,
      'frozen': frozen,
      'act': activated,
      'burn': burning,
      'char': charred,
      'p': ps,
      'd': saveData(),
      if (frozen) 'm': _savedMass,
    };
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;

  void restoreFromJson(Map<String, dynamic> j) {
    loadData((j['d'] as Map?)?.cast<String, dynamic>() ?? {});
    final h = (j['hp'] as num?)?.toDouble() ?? -1;
    if (h >= 0) hp = h;
    burning = (j['burn'] as num?)?.toDouble() ?? 0;
    charred = (j['char'] as num?)?.toDouble() ?? 0;
    activated = j['act'] == true;
    final ps = (j['p'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
    if (ps.length == particles.length * 4) {
      for (var i = 0; i < particles.length; i++) {
        final p = particles[i];
        p.x = ps[i * 4];
        p.y = ps[i * 4 + 1];
        p.px = ps[i * 4 + 2];
        p.py = ps[i * 4 + 3];
      }
    }
    if (j['frozen'] == true) {
      setFrozen(true);
      final m = (j['m'] as List?)?.map((e) => (e as num).toDouble()).toList();
      if (m != null && m.length == particles.length) _savedMass = m;
    }
  }
}

// ---------------------------------------------------------------------------
// Drawing helpers shared by entities.

Path polyPath(List<Particle> ps) {
  final path = Path();
  if (ps.isEmpty) return path;
  path.moveTo(ps[0].x, ps[0].y);
  for (var i = 1; i < ps.length; i++) {
    path.lineTo(ps[i].x, ps[i].y);
  }
  path.close();
  return path;
}

final Paint fillPaint = Paint()..isAntiAlias = true;
final Paint strokePaint = Paint()
  ..style = PaintingStyle.stroke
  ..isAntiAlias = true
  ..strokeJoin = StrokeJoin.round
  ..strokeCap = StrokeCap.round;

const Color outline = Color(0xFF111114);

void drawPoly(Canvas c, List<Particle> ps, Color fill, {double stroke = 1.6, Color? line}) {
  final path = polyPath(ps);
  fillPaint.color = fill;
  c.drawPath(path, fillPaint);
  if (stroke > 0) {
    strokePaint
      ..color = line ?? outline
      ..strokeWidth = stroke;
    c.drawPath(path, strokePaint);
  }
}

void drawCapsule(Canvas c, double x1, double y1, double x2, double y2, double r, Color fill,
    {double stroke = 1.6}) {
  if (stroke > 0) {
    strokePaint
      ..color = outline
      ..strokeWidth = r * 2 + stroke * 2;
    c.drawLine(Offset(x1, y1), Offset(x2, y2), strokePaint);
  }
  strokePaint
    ..color = fill
    ..strokeWidth = r * 2;
  c.drawLine(Offset(x1, y1), Offset(x2, y2), strokePaint);
}

Color darken(Color c, double t) {
  t = t.clamp(0.0, 1.0);
  return Color.lerp(c, const Color(0xFF151210), t * 0.85)!;
}

/// Executes [draw] in the local frame of a rigid body: origin at (x, y),
/// x-axis rotated by [ang].
void inFrame(Canvas c, double x, double y, double ang, void Function() draw) {
  c.save();
  c.translate(x, y);
  c.rotate(ang);
  draw();
  c.restore();
}

final Float64List _m4 = Float64List(16);

/// Draws in the local frame of a rigid box built by [Entity.makeBox]
/// (particles 0..3 = top-left, top-right, bottom-right, bottom-left at rest).
/// The frame follows mirroring, so art never renders upside down after a flip.
/// Local origin is the box centre, +x toward particle 1, +y toward particle 3.
void inBox(Canvas c, List<Particle> b, void Function() draw) {
  final p0 = b[0], p1 = b[1], p3 = b[3];
  final cxm = (b[0].x + b[1].x + b[2].x + b[3].x) / 4;
  final cym = (b[0].y + b[1].y + b[2].y + b[3].y) / 4;
  var ux = p1.x - p0.x, uy = p1.y - p0.y;
  var vx = p3.x - p0.x, vy = p3.y - p0.y;
  final ul = math.sqrt(ux * ux + uy * uy), vl = math.sqrt(vx * vx + vy * vy);
  if (ul < 1e-6 || vl < 1e-6) return;
  ux /= ul;
  uy /= ul;
  vx /= vl;
  vy /= vl;
  _m4.fillRange(0, 16, 0);
  _m4[0] = ux;
  _m4[1] = uy;
  _m4[4] = vx;
  _m4[5] = vy;
  _m4[10] = 1;
  _m4[12] = cxm;
  _m4[13] = cym;
  _m4[15] = 1;
  c.save();
  c.transform(_m4);
  draw();
  c.restore();
}

/// Local frame helper for code that needs box axes (muzzles etc).
class BoxFrame {
  double cx = 0, cy = 0, ux = 1, uy = 0, vx = 0, vy = 1;
  void from(List<Particle> b) {
    cx = (b[0].x + b[1].x + b[2].x + b[3].x) / 4;
    cy = (b[0].y + b[1].y + b[2].y + b[3].y) / 4;
    ux = b[1].x - b[0].x;
    uy = b[1].y - b[0].y;
    vx = b[3].x - b[0].x;
    vy = b[3].y - b[0].y;
    final ul = math.sqrt(ux * ux + uy * uy), vl = math.sqrt(vx * vx + vy * vy);
    if (ul > 1e-6) {
      ux /= ul;
      uy /= ul;
    }
    if (vl > 1e-6) {
      vx /= vl;
      vy /= vl;
    }
  }

  double wx(double lx, double ly) => cx + ux * lx + vx * ly;
  double wy(double lx, double ly) => cy + uy * lx + vy * ly;
  /// +1 when the frame is not mirrored.
  double get handed => ux * vy - uy * vx >= 0 ? 1.0 : -1.0;
}

void rrect(Canvas c, double x, double y, double w, double h, double r, Color col,
    {double stroke = 1.2}) {
  final rr = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
  if (stroke > 0) {
    strokePaint
      ..color = outline
      ..strokeWidth = stroke;
  }
  fillPaint.color = col;
  c.drawRRect(rr, fillPaint);
  if (stroke > 0) c.drawRRect(rr, strokePaint);
}
