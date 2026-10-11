// Ragbox physics engine.
//
// A position-based (Verlet) particle engine. Every physical thing is built
// from particles joined by sticks. Collision shapes are either capsules
// (two particles + radius, a circle when both particles are the same) or
// convex polygons whose corners are particles. Static geometry is simply
// made of particles with zero inverse mass.
//
// Contacts are resolved with a unified "feature" model: each side of a
// contact is a point interpolated between two particles (p0, p1, t), which
// lets capsule, polygon and point contacts share one solver.

import 'dart:math' as math;

class Particle {
  double x, y, px, py;
  double invMass;
  double mass;
  double ax = 0, ay = 0;
  double gravityScale = 1.0;
  /// Physics frame of the most recent contact (used for ground checks).
  int touchFrame = -1000;
  double touchNx = 0, touchNy = 0;
  Object? owner;

  Particle(this.x, this.y, double m)
      : px = x,
        py = y,
        mass = m,
        invMass = m <= 0 ? 0.0 : 1.0 / m;

  bool get pinned => invMass == 0.0;
  double get vx => x - px;
  double get vy => y - py;

  void setMass(double m) {
    mass = m;
    invMass = m <= 0 ? 0.0 : 1.0 / m;
  }

  void moveTo(double nx, double ny) {
    final dx = nx - x, dy = ny - y;
    x += dx;
    y += dy;
    px += dx;
    py += dy;
  }

  /// Adds an instantaneous velocity change (units per step).
  void kick(double dvx, double dvy) {
    if (invMass == 0) return;
    px -= dvx;
    py -= dvy;
  }
}

enum StickKind { rigid, rope, spring }

class Stick {
  Particle a, b;
  double rest;
  double stiffness;
  StickKind kind;
  double breakForce; // relative stretch beyond which the stick snaps; 0 = never
  bool broken = false;
  Object? tag;

  Stick(this.a, this.b,
      {double? rest,
      this.stiffness = 1.0,
      this.kind = StickKind.rigid,
      this.breakForce = 0,
      this.tag})
      : rest = rest ?? _dist(a, b);

  static double _dist(Particle a, Particle b) {
    final dx = b.x - a.x, dy = b.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double get length => _dist(a, b);
}

/// Keeps the signed angle a-b-c inside [min, max] (radians in [0, 2pi)).
/// When [target] is set and [muscle] > 0 the joint is also softly pulled
/// toward the target angle (used for active ragdoll muscles).
class AngleLimit {
  Particle a, b, c;
  double min, max;
  double stiffness;
  double? target;
  double muscle = 0;
  bool enabled = true;

  AngleLimit(this.a, this.b, this.c, this.min, this.max,
      {this.stiffness = 0.5, this.target});

  double current() {
    final ux = a.x - b.x, uy = a.y - b.y;
    final vx = c.x - b.x, vy = c.y - b.y;
    var ang = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
    if (ang < 0) ang += math.pi * 2;
    return ang;
  }
}

enum ShapeKind { capsule, poly }

class Shape {
  final ShapeKind kind;
  final List<Particle> pts;
  double radius;
  Object? owner; // the game entity
  int group; // shapes with the same non-zero group never collide
  double friction;
  double restitution;
  bool sensor = false; // reports overlaps but does not collide
  bool enabled = true;
  Object? tag; // limb id etc.

  // broadphase cache
  double minX = 0, minY = 0, maxX = 0, maxY = 0;

  Shape.capsule(Particle a, Particle b, this.radius,
      {this.owner, this.group = 0, this.friction = 0.6, this.restitution = 0, this.tag})
      : kind = ShapeKind.capsule,
        pts = [a, b];

  Shape.circle(Particle a, this.radius,
      {this.owner, this.group = 0, this.friction = 0.6, this.restitution = 0, this.tag})
      : kind = ShapeKind.capsule,
        pts = [a, a];

  Shape.poly(this.pts,
      {this.owner, this.group = 0, this.friction = 0.6, this.restitution = 0, this.tag})
      : kind = ShapeKind.poly,
        radius = 0;

  bool get isStatic {
    for (final p in pts) {
      if (p.invMass != 0) return false;
    }
    return true;
  }

  void computeAabb(double margin) {
    var x0 = double.infinity, y0 = double.infinity;
    var x1 = -double.infinity, y1 = -double.infinity;
    for (final p in pts) {
      if (p.x < x0) x0 = p.x;
      if (p.y < y0) y0 = p.y;
      if (p.x > x1) x1 = p.x;
      if (p.y > y1) y1 = p.y;
    }
    final r = radius + margin;
    minX = x0 - r;
    minY = y0 - r;
    maxX = x1 + r;
    maxY = y1 + r;
  }

  double centerX() {
    var s = 0.0;
    for (final p in pts) {
      s += p.x;
    }
    return s / pts.length;
  }

  double centerY() {
    var s = 0.0;
    for (final p in pts) {
      s += p.y;
    }
    return s / pts.length;
  }

  /// True when the world point lies inside the shape (plus [pad]).
  bool containsPoint(double x, double y, [double pad = 0]) {
    if (kind == ShapeKind.capsule) {
      final d = distPointSeg(x, y, pts[0].x, pts[0].y, pts[1].x, pts[1].y);
      return d <= radius + pad;
    }
    final n = pts.length;
    final cx = centerX(), cy = centerY();
    for (var i = 0; i < n; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      var nx = b.y - a.y, ny = -(b.x - a.x);
      final len = math.sqrt(nx * nx + ny * ny);
      if (len < 1e-9) continue;
      nx /= len;
      ny /= len;
      if ((cx - a.x) * nx + (cy - a.y) * ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      if ((x - a.x) * nx + (y - a.y) * ny > pad) return false;
    }
    return true;
  }

  /// Distance from a point to the shape surface (0 when inside).
  double distanceTo(double x, double y) {
    if (kind == ShapeKind.capsule) {
      final d = distPointSeg(x, y, pts[0].x, pts[0].y, pts[1].x, pts[1].y) - radius;
      return d < 0 ? 0 : d;
    }
    if (containsPoint(x, y)) return 0;
    var best = double.infinity;
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      final d = distPointSeg(x, y, a.x, a.y, b.x, b.y);
      if (d < best) best = d;
    }
    return best;
  }
}

double distPointSeg(double px, double py, double ax, double ay, double bx, double by) {
  final t = projT(px, py, ax, ay, bx, by);
  final cx = ax + (bx - ax) * t, cy = ay + (by - ay) * t;
  final dx = px - cx, dy = py - cy;
  return math.sqrt(dx * dx + dy * dy);
}

double projT(double px, double py, double ax, double ay, double bx, double by) {
  final dx = bx - ax, dy = by - ay;
  final l2 = dx * dx + dy * dy;
  if (l2 < 1e-12) return 0.0;
  final t = ((px - ax) * dx + (py - ay) * dy) / l2;
  return t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
}

/// Result of closest points between two segments.
class _SegSeg {
  double s = 0, t = 0, dist2 = 0;
  double cx1 = 0, cy1 = 0, cx2 = 0, cy2 = 0;
}

final _SegSeg _ss = _SegSeg();

void _closestSegSeg(double p1x, double p1y, double q1x, double q1y, double p2x,
    double p2y, double q2x, double q2y) {
  // Real-Time Collision Detection, 5.1.9
  final d1x = q1x - p1x, d1y = q1y - p1y;
  final d2x = q2x - p2x, d2y = q2y - p2y;
  final rx = p1x - p2x, ry = p1y - p2y;
  final a = d1x * d1x + d1y * d1y;
  final e = d2x * d2x + d2y * d2y;
  final f = d2x * rx + d2y * ry;
  double s, t;
  const eps = 1e-9;
  if (a <= eps && e <= eps) {
    s = 0;
    t = 0;
  } else if (a <= eps) {
    s = 0;
    t = (f / e).clamp(0.0, 1.0);
  } else {
    final c = d1x * rx + d1y * ry;
    if (e <= eps) {
      t = 0;
      s = (-c / a).clamp(0.0, 1.0);
    } else {
      final b = d1x * d2x + d1y * d2y;
      final denom = a * e - b * b;
      if (denom != 0) {
        s = ((b * f - c * e) / denom).clamp(0.0, 1.0);
      } else {
        s = 0;
      }
      t = (b * s + f) / e;
      if (t < 0) {
        t = 0;
        s = (-c / a).clamp(0.0, 1.0);
      } else if (t > 1) {
        t = 1;
        s = ((b - c) / a).clamp(0.0, 1.0);
      }
    }
  }
  _ss.s = s;
  _ss.t = t;
  _ss.cx1 = p1x + d1x * s;
  _ss.cy1 = p1y + d1y * s;
  _ss.cx2 = p2x + d2x * t;
  _ss.cy2 = p2y + d2y * t;
  final dx = _ss.cx1 - _ss.cx2, dy = _ss.cy1 - _ss.cy2;
  _ss.dist2 = dx * dx + dy * dy;
}

class Impact {
  final Shape a, b;
  final double speed; // relative normal speed in units/second
  final double x, y;
  final double nx, ny;
  Impact(this.a, this.b, this.speed, this.x, this.y, this.nx, this.ny);
}

class RayHit {
  final Shape shape;
  final double t; // distance along ray
  final double x, y;
  final double nx, ny;
  final double exitT;
  RayHit(this.shape, this.t, this.x, this.y, this.nx, this.ny, this.exitT);
}

/// A soft "hand" that drags a particle toward a target point.
class DragHandle {
  Particle p;
  double tx, ty;
  double strength;
  DragHandle(this.p, this.tx, this.ty, {this.strength = 0.35});
}

class PhysicsWorld {
  final List<Particle> particles = [];
  final List<Stick> sticks = [];
  final List<AngleLimit> angles = [];
  final List<Shape> shapes = [];
  final List<Impact> impacts = [];
  final List<DragHandle> drags = [];

  double gravityX = 0, gravityY = 980;
  double airDamping = 0.999;
  double globalFriction = 1.0;
  int iterations = 8;
  int frame = 0;
  double prevDt = 1 / 120.0;
  double maxSpeed = 120; // units per step clamp
  double impactThreshold = 250; // units/s before an impact is reported

  // Pair cache rebuilt every step.
  final List<Shape> _sorted = [];
  final List<int> _pairs = [];

  void addParticle(Particle p) => particles.add(p);
  void addStick(Stick s) => sticks.add(s);
  void addShape(Shape s) {
    s.computeAabb(3);
    shapes.add(s);
    _sorted.add(s);
  }

  void addAngle(AngleLimit a) => angles.add(a);

  void removeParticles(Iterable<Particle> ps) {
    final set = ps.toSet();
    particles.removeWhere(set.contains);
    sticks.removeWhere((s) => set.contains(s.a) || set.contains(s.b));
    angles.removeWhere((a) => set.contains(a.a) || set.contains(a.b) || set.contains(a.c));
    drags.removeWhere((d) => set.contains(d.p));
  }

  void removeShapes(Iterable<Shape> ss) {
    final set = ss.toSet();
    shapes.removeWhere(set.contains);
    _sorted.removeWhere(set.contains);
  }

  void removeStick(Stick s) => sticks.remove(s);

  void clear() {
    particles.clear();
    sticks.clear();
    angles.clear();
    shapes.clear();
    impacts.clear();
    drags.clear();
    _sorted.clear();
    _pairs.clear();
  }

  /// Advance the simulation by [dt] seconds (one sub step).
  void step(double dt) {
    frame++;
    impacts.clear();
    final dtRatio = dt / prevDt;
    final dt2 = dt * dt;
    final damp = airDamping;
    for (final p in particles) {
      if (p.invMass == 0) {
        p.px = p.x;
        p.py = p.y;
        p.ax = 0;
        p.ay = 0;
        continue;
      }
      var vx = (p.x - p.px) * dtRatio * damp;
      var vy = (p.y - p.py) * dtRatio * damp;
      final sp2 = vx * vx + vy * vy;
      if (sp2 > maxSpeed * maxSpeed) {
        final k = maxSpeed / math.sqrt(sp2);
        vx *= k;
        vy *= k;
      }
      p.px = p.x;
      p.py = p.y;
      p.x += vx + (gravityX * p.gravityScale + p.ax) * dt2;
      p.y += vy + (gravityY * p.gravityScale + p.ay) * dt2;
      p.ax = 0;
      p.ay = 0;
    }
    prevDt = dt;

    _broadphase();

    final iters = iterations;
    for (var it = 0; it < iters; it++) {
      for (final d in drags) {
        _solveDrag(d);
      }
      for (final s in sticks) {
        _solveStick(s);
      }
      for (final a in angles) {
        if (a.enabled) _solveAngle(a);
      }
      _narrowphase(it == 0, dt);
    }
    // Remove broken sticks.
    sticks.removeWhere((s) => s.broken);
  }

  void _solveDrag(DragHandle d) {
    final p = d.p;
    if (p.invMass == 0) return;
    p.x += (d.tx - p.x) * d.strength;
    p.y += (d.ty - p.y) * d.strength;
  }

  void _solveStick(Stick s) {
    final a = s.a, b = s.b;
    final dx = b.x - a.x, dy = b.y - a.y;
    final len = math.sqrt(dx * dx + dy * dy);
    if (s.kind == StickKind.rope && len <= s.rest) return;
    final w = a.invMass + b.invMass;
    if (w == 0) return;
    if (s.breakForce > 0 && s.rest > 0 && (len - s.rest) / s.rest > s.breakForce) {
      s.broken = true;
      return;
    }
    if (len < 1e-9) {
      if (s.rest == 0) return;
      // Coincident particles: nudge apart.
      b.x += 0.01;
      return;
    }
    final diff = (len - s.rest) / (len * w) * s.stiffness;
    final ox = dx * diff, oy = dy * diff;
    a.x += ox * a.invMass;
    a.y += oy * a.invMass;
    b.x -= ox * b.invMass;
    b.y -= oy * b.invMass;
  }

  void _solveAngle(AngleLimit al) {
    final cur = al.current();
    double diff;
    if (cur < al.min) {
      diff = (al.min - cur) * al.stiffness;
    } else if (cur > al.max) {
      diff = (al.max - cur) * al.stiffness;
    } else if (al.target != null && al.muscle > 0) {
      final t = al.target!.clamp(al.min, al.max);
      diff = (t - cur) * al.muscle;
    } else {
      return;
    }
    if (diff.abs() < 1e-5) return;
    const k = 1.0;
    // Rotate a and c around b in opposite directions.
    final a = al.a, b = al.b, c = al.c;
    final wa = a.invMass, wc = c.invMass;
    final wsum = wa + wc;
    if (wsum == 0) return;
    // positive diff -> increase angle -> rotate c positively, a negatively
    final rotC = diff * k * (wc / wsum);
    final rotA = -diff * k * (wa / wsum);
    final ax0 = a.x, ay0 = a.y, cx0 = c.x, cy0 = c.y;
    _rotateAround(c, b, rotC);
    _rotateAround(a, b, rotA);
    // Rotating the outer particles around a fixed middle one would create
    // momentum from nothing (bodies would drift or launch). Shift all three
    // back so their combined centre of mass stays where it was.
    final ma = a.mass, mb = b.mass, mc = c.mass;
    final mt = (a.invMass > 0 ? ma : 0.0) + (b.invMass > 0 ? mb : 0.0) + (c.invMass > 0 ? mc : 0.0);
    if (mt <= 0) return;
    final px = (a.invMass > 0 ? ma * (a.x - ax0) : 0.0) + (c.invMass > 0 ? mc * (c.x - cx0) : 0.0);
    final py = (a.invMass > 0 ? ma * (a.y - ay0) : 0.0) + (c.invMass > 0 ? mc * (c.y - cy0) : 0.0);
    final sx = px / mt, sy = py / mt;
    if (a.invMass > 0) {
      a.x -= sx;
      a.y -= sy;
    }
    if (b.invMass > 0) {
      b.x -= sx;
      b.y -= sy;
    }
    if (c.invMass > 0) {
      c.x -= sx;
      c.y -= sy;
    }
  }

  void _rotateAround(Particle p, Particle pivot, double ang) {
    if (p.invMass == 0 || ang == 0) return;
    final cs = math.cos(ang), sn = math.sin(ang);
    final dx = p.x - pivot.x, dy = p.y - pivot.y;
    p.x = pivot.x + dx * cs - dy * sn;
    p.y = pivot.y + dx * sn + dy * cs;
  }

  void _broadphase() {
    _pairs.clear();
    for (final s in _sorted) {
      s.computeAabb(3);
    }
    // insertion sort by minX (nearly sorted frame to frame)
    for (var i = 1; i < _sorted.length; i++) {
      final s = _sorted[i];
      var j = i - 1;
      while (j >= 0 && _sorted[j].minX > s.minX) {
        _sorted[j + 1] = _sorted[j];
        j--;
      }
      _sorted[j + 1] = s;
    }
    final n = _sorted.length;
    final statics = List<bool>.generate(n, (i) => _sorted[i].isStatic);
    for (var i = 0; i < n; i++) {
      final a = _sorted[i];
      if (!a.enabled) continue;
      for (var j = i + 1; j < n; j++) {
        final b = _sorted[j];
        if (b.minX > a.maxX) break;
        if (!b.enabled) continue;
        if (statics[i] && statics[j]) continue;
        if (a.group != 0 && a.group == b.group) continue;
        if (a.maxY < b.minY || b.maxY < a.minY) continue;
        if (identical(a.owner, b.owner) && a.owner != null && a.group == 0 && b.group == 0) {
          // shapes of the same entity never collide with each other
          continue;
        }
        _pairs.add(i);
        _pairs.add(j);
      }
    }
  }

  /// Called by the game to receive sensor overlaps; set by Sandbox.
  void Function(Shape sensor, Shape other)? onSensor;

  void _narrowphase(bool first, double dt) {
    for (var k = 0; k < _pairs.length; k += 2) {
      final a = _sorted[_pairs[k]], b = _sorted[_pairs[k + 1]];
      if (a.sensor || b.sensor) {
        if (first && onSensor != null) {
          if (_overlapSimple(a, b)) {
            if (a.sensor) onSensor!(a, b);
            if (b.sensor) onSensor!(b, a);
          }
        }
        continue;
      }
      if (a.kind == ShapeKind.capsule && b.kind == ShapeKind.capsule) {
        _capCap(a, b, first, dt);
      } else if (a.kind == ShapeKind.capsule && b.kind == ShapeKind.poly) {
        _capPoly(a, b, first, dt);
      } else if (a.kind == ShapeKind.poly && b.kind == ShapeKind.capsule) {
        _capPoly(b, a, first, dt);
      } else {
        _polyPoly(a, b, first, dt);
      }
    }
  }

  bool _overlapSimple(Shape a, Shape b) {
    if (a.kind == ShapeKind.poly) {
      if (b.containsPoint(a.centerX(), a.centerY())) return true;
      for (final p in b.pts) {
        if (a.containsPoint(p.x, p.y, b.radius)) return true;
      }
      return false;
    }
    if (b.kind == ShapeKind.poly) return _overlapSimple(b, a);
    _closestSegSeg(a.pts[0].x, a.pts[0].y, a.pts[1].x, a.pts[1].y, b.pts[0].x,
        b.pts[0].y, b.pts[1].x, b.pts[1].y);
    final r = a.radius + b.radius;
    return _ss.dist2 < r * r;
  }

  void _capCap(Shape a, Shape b, bool first, double dt) {
    final a0 = a.pts[0], a1 = a.pts[1], b0 = b.pts[0], b1 = b.pts[1];
    _closestSegSeg(a0.x, a0.y, a1.x, a1.y, b0.x, b0.y, b1.x, b1.y);
    final r = a.radius + b.radius;
    if (_ss.dist2 >= r * r) return;
    final d = math.sqrt(_ss.dist2);
    double nx, ny;
    if (d < 1e-6) {
      // pick perpendicular of b
      var tx = b1.x - b0.x, ty = b1.y - b0.y;
      final l = math.sqrt(tx * tx + ty * ty);
      if (l < 1e-6) {
        nx = 0;
        ny = -1;
      } else {
        tx /= l;
        ty /= l;
        nx = -ty;
        ny = tx;
      }
    } else {
      nx = (_ss.cx1 - _ss.cx2) / d;
      ny = (_ss.cy1 - _ss.cy2) / d;
    }
    final s = identical(a0, a1) ? 0.0 : _ss.s;
    final t = identical(b0, b1) ? 0.0 : _ss.t;
    _resolve(a, b, a0, a1, s, b0, b1, t, nx, ny, r - d, first, dt);
  }

  void _capPoly(Shape c, Shape p, bool first, double dt) {
    final c0 = c.pts[0], c1 = c.pts[1];
    final pts = p.pts;
    final n = pts.length;
    final pcx = p.centerX(), pcy = p.centerY();
    var bestD2 = double.infinity;
    var bestS = 0.0, bestT = 0.0;
    var bestEdge = 0;
    var bcx1 = 0.0, bcy1 = 0.0, bcx2 = 0.0, bcy2 = 0.0;
    for (var i = 0; i < n; i++) {
      final e0 = pts[i], e1 = pts[(i + 1) % n];
      _closestSegSeg(c0.x, c0.y, c1.x, c1.y, e0.x, e0.y, e1.x, e1.y);
      if (_ss.dist2 < bestD2) {
        bestD2 = _ss.dist2;
        bestS = _ss.s;
        bestT = _ss.t;
        bestEdge = i;
        bcx1 = _ss.cx1;
        bcy1 = _ss.cy1;
        bcx2 = _ss.cx2;
        bcy2 = _ss.cy2;
      }
    }
    final r = c.radius;
    final inside0 = p.containsPoint(c0.x, c0.y);
    final inside1 = identical(c0, c1) ? inside0 : p.containsPoint(c1.x, c1.y);
    final insideM = identical(c0, c1)
        ? inside0
        : p.containsPoint((c0.x + c1.x) * 0.5, (c0.y + c1.y) * 0.5);
    final sIsPoint = identical(c0, c1);
    if (!inside0 && !inside1 && !insideM) {
      if (bestD2 >= r * r) return;
      final d = math.sqrt(bestD2);
      if (d > 1e-6) {
        final nx = (bcx1 - bcx2) / d, ny = (bcy1 - bcy2) / d;
        final e0 = pts[bestEdge], e1 = pts[(bestEdge + 1) % n];
        _resolve(c, p, c0, c1, sIsPoint ? 0.0 : bestS, e0, e1, bestT, nx, ny, r - d, first, dt);
        return;
      }
    }
    // Deep penetration: SAT over polygon edge normals.
    var bestPen = double.infinity;
    var bnx = 0.0, bny = 0.0;
    var bi = 0;
    var bs = 0.0;
    for (var i = 0; i < n; i++) {
      final e0 = pts[i], e1 = pts[(i + 1) % n];
      var nx = e1.y - e0.y, ny = -(e1.x - e0.x);
      final len = math.sqrt(nx * nx + ny * ny);
      if (len < 1e-9) continue;
      nx /= len;
      ny /= len;
      if ((pcx - e0.x) * nx + (pcy - e0.y) * ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      final edgeProj = e0.x * nx + e0.y * ny;
      final p0 = c0.x * nx + c0.y * ny;
      final p1 = c1.x * nx + c1.y * ny;
      final minP = math.min(p0, p1) - r;
      final pen = edgeProj - minP;
      if (pen < bestPen) {
        bestPen = pen;
        bnx = nx;
        bny = ny;
        bi = i;
        if (sIsPoint) {
          bs = 0;
        } else if ((p0 - p1).abs() < 1.0) {
          bs = 0.5;
        } else {
          bs = p0 < p1 ? 0.0 : 1.0;
        }
      }
    }
    if (bestPen <= 0 || bestPen == double.infinity) return;
    final e0 = pts[bi], e1 = pts[(bi + 1) % n];
    final cpx = c0.x + (c1.x - c0.x) * bs, cpy = c0.y + (c1.y - c0.y) * bs;
    final et = projT(cpx, cpy, e0.x, e0.y, e1.x, e1.y);
    _resolve(c, p, c0, c1, bs, e0, e1, et, bnx, bny, bestPen, first, dt);
  }

  void _polyPoly(Shape a, Shape b, bool first, double dt) {
    // Best separating axis from each polygon's own edges.
    final bestOv = [double.infinity, double.infinity];
    final bestNx = [0.0, 0.0], bestNy = [0.0, 0.0];
    for (var pass = 0; pass < 2; pass++) {
      final s = pass == 0 ? a : b;
      final o = pass == 0 ? b : a;
      final n = s.pts.length;
      for (var i = 0; i < n; i++) {
        final e0 = s.pts[i], e1 = s.pts[(i + 1) % n];
        var nx = e1.y - e0.y, ny = -(e1.x - e0.x);
        final len = math.sqrt(nx * nx + ny * ny);
        if (len < 1e-9) continue;
        nx /= len;
        ny /= len;
        var minA = double.infinity, maxA = -double.infinity;
        for (final p in s.pts) {
          final d = p.x * nx + p.y * ny;
          if (d < minA) minA = d;
          if (d > maxA) maxA = d;
        }
        var minB = double.infinity, maxB = -double.infinity;
        for (final p in o.pts) {
          final d = p.x * nx + p.y * ny;
          if (d < minB) minB = d;
          if (d > maxB) maxB = d;
        }
        final ov = math.min(maxA - minB, maxB - minA);
        if (ov <= 0) return;
        if (ov < bestOv[pass]) {
          bestOv[pass] = ov;
          bestNx[pass] = nx;
          bestNy[pass] = ny;
        }
      }
    }
    // Pick the reference polygon. On (near) ties prefer the larger polygon,
    // so a small box resting on big ground uses the ground's face and the
    // box's corners as contact points (stable stacking, no spurious torque).
    int pick;
    if (bestOv[0] < bestOv[1] * 0.95 - 0.01) {
      pick = 0;
    } else if (bestOv[1] < bestOv[0] * 0.95 - 0.01) {
      pick = 1;
    } else {
      pick = _area(a) >= _area(b) ? 0 : 1;
    }
    final ref = pick == 0 ? a : b;
    final inc = pick == 0 ? b : a;
    final minOverlap = bestOv[pick];
    var bnx = bestNx[pick], bny = bestNy[pick];
    if (!minOverlap.isFinite) return;
    // normal must point from ref toward inc
    final dcx = inc.centerX() - ref.centerX(), dcy = inc.centerY() - ref.centerY();
    if (dcx * bnx + dcy * bny < 0) {
      bnx = -bnx;
      bny = -bny;
    }
    // the reference edge is the one whose outward normal faces the incident polygon
    var refEdge = 0;
    {
      final n = ref.pts.length;
      final rcx = ref.centerX(), rcy = ref.centerY();
      var bestDot = -double.infinity;
      for (var i = 0; i < n; i++) {
        final e0 = ref.pts[i], e1 = ref.pts[(i + 1) % n];
        var nx = e1.y - e0.y, ny = -(e1.x - e0.x);
        final len = math.sqrt(nx * nx + ny * ny);
        if (len < 1e-9) continue;
        nx /= len;
        ny /= len;
        if ((rcx - e0.x) * nx + (rcy - e0.y) * ny > 0) {
          nx = -nx;
          ny = -ny;
        }
        final d = nx * bnx + ny * bny;
        if (d > bestDot) {
          bestDot = d;
          refEdge = i;
        }
      }
    }
    // support of ref along n
    var refMax = -double.infinity;
    for (final p in ref.pts) {
      final d = p.x * bnx + p.y * bny;
      if (d > refMax) refMax = d;
    }
    final n = ref.pts.length;
    final e0 = ref.pts[refEdge], e1 = ref.pts[(refEdge + 1) % n];
    // Resolve every penetrating vertex of the incident polygon.
    var resolved = 0;
    for (final v in inc.pts) {
      final pen = refMax - (v.x * bnx + v.y * bny);
      if (pen <= 0) continue;
      if (pen > minOverlap + 0.5) continue; // vertex is not on the contact side
      final t = projT(v.x, v.y, e0.x, e0.y, e1.x, e1.y);
      _resolve(inc, ref, v, v, 0, e0, e1, t, bnx, bny, pen, first && resolved == 0, dt);
      resolved++;
    }
    if (resolved == 0) {
      // fall back to deepest vertex
      Particle? deepest;
      var best = double.infinity;
      for (final v in inc.pts) {
        final d = v.x * bnx + v.y * bny;
        if (d < best) {
          best = d;
          deepest = v;
        }
      }
      if (deepest != null) {
        final t = projT(deepest.x, deepest.y, e0.x, e0.y, e1.x, e1.y);
        _resolve(inc, ref, deepest, deepest, 0, e0, e1, t, bnx, bny, minOverlap, first, dt);
      }
    }
  }

  static double _area(Shape s) => (s.maxX - s.minX) * (s.maxY - s.minY);

  /// Push side A along +n and side B along -n by [depth].
  void _resolve(Shape sa, Shape sb, Particle a0, Particle a1, double ta, Particle b0,
      Particle b1, double tb, double nx, double ny, double depth, bool first, double dt) {
    if (depth <= 0) return;
    final aSame = identical(a0, a1);
    final bSame = identical(b0, b1);
    final wa0 = aSame ? 1.0 : 1 - ta, wa1 = aSame ? 0.0 : ta;
    final wb0 = bSame ? 1.0 : 1 - tb, wb1 = bSame ? 0.0 : tb;
    final kA = wa0 * wa0 * a0.invMass + (aSame ? 0.0 : wa1 * wa1 * a1.invMass);
    final kB = wb0 * wb0 * b0.invMass + (bSame ? 0.0 : wb1 * wb1 * b1.invMass);
    final kSum = kA + kB;
    if (kSum <= 0) return;

    // relative velocity of the contact points
    final vax = a0.vx * wa0 + (aSame ? 0.0 : a1.vx * wa1);
    final vay = a0.vy * wa0 + (aSame ? 0.0 : a1.vy * wa1);
    final vbx = b0.vx * wb0 + (bSame ? 0.0 : b1.vx * wb1);
    final vby = b0.vy * wb0 + (bSame ? 0.0 : b1.vy * wb1);
    final rvx = vax - vbx, rvy = vay - vby;
    final vn = rvx * nx + rvy * ny;

    if (first && vn < 0) {
      final speed = -vn / dt;
      if (speed > impactThreshold) {
        final cx = (a0.x * wa0 + (aSame ? 0.0 : a1.x * wa1));
        final cy = (a0.y * wa0 + (aSame ? 0.0 : a1.y * wa1));
        impacts.add(Impact(sa, sb, speed, cx, cy, nx, ny));
      }
    }

    final lambda = depth / kSum;
    a0.x += nx * lambda * wa0 * a0.invMass;
    a0.y += ny * lambda * wa0 * a0.invMass;
    if (!aSame) {
      a1.x += nx * lambda * wa1 * a1.invMass;
      a1.y += ny * lambda * wa1 * a1.invMass;
    }
    b0.x -= nx * lambda * wb0 * b0.invMass;
    b0.y -= ny * lambda * wb0 * b0.invMass;
    if (!bSame) {
      b1.x -= nx * lambda * wb1 * b1.invMass;
      b1.y -= ny * lambda * wb1 * b1.invMass;
    }

    // Overlap that motion this step does not explain (objects spawned or
    // squeezed inside each other) is removed without turning it into
    // velocity. Otherwise Verlet would fire the bodies apart at depth/dt.
    final free = depth - math.max(0.0, -vn) - 1.0;
    if (free > 0) {
      final lf = free / kSum;
      a0.px += nx * lf * wa0 * a0.invMass;
      a0.py += ny * lf * wa0 * a0.invMass;
      if (!aSame) {
        a1.px += nx * lf * wa1 * a1.invMass;
        a1.py += ny * lf * wa1 * a1.invMass;
      }
      b0.px -= nx * lf * wb0 * b0.invMass;
      b0.py -= ny * lf * wb0 * b0.invMass;
      if (!bSame) {
        b1.px -= nx * lf * wb1 * b1.invMass;
        b1.py -= ny * lf * wb1 * b1.invMass;
      }
    }

    final f = frame;
    a0.touchFrame = f;
    a0.touchNx = nx;
    a0.touchNy = ny;
    if (!aSame) {
      a1.touchFrame = f;
      a1.touchNx = nx;
      a1.touchNy = ny;
    }
    b0.touchFrame = f;
    b0.touchNx = -nx;
    b0.touchNy = -ny;
    if (!bSame) {
      b1.touchFrame = f;
      b1.touchNx = -nx;
      b1.touchNy = -ny;
    }

    // Friction: remove part of the tangential relative motion.
    final mu = math.sqrt(sa.friction * sb.friction) * globalFriction;
    if (mu > 0) {
      final tx = rvx - vn * nx, ty = rvy - vn * ny;
      final tl = math.sqrt(tx * tx + ty * ty);
      if (tl > 1e-6) {
        // static friction removes all sliding, kinetic removes a share
        final mag = tl < depth * mu * 4 ? tl : tl * mu * 0.35;
        final l2 = mag / kSum;
        final ux = tx / tl, uy = ty / tl;
        a0.x -= ux * l2 * wa0 * a0.invMass;
        a0.y -= uy * l2 * wa0 * a0.invMass;
        if (!aSame) {
          a1.x -= ux * l2 * wa1 * a1.invMass;
          a1.y -= uy * l2 * wa1 * a1.invMass;
        }
        b0.x += ux * l2 * wb0 * b0.invMass;
        b0.y += uy * l2 * wb0 * b0.invMass;
        if (!bSame) {
          b1.x += ux * l2 * wb1 * b1.invMass;
          b1.y += uy * l2 * wb1 * b1.invMass;
        }
      }
    }

    // Restitution for single-particle balls.
    if (first && vn < 0) {
      final e = math.max(sa.restitution, sb.restitution);
      if (e > 0) {
        if (aSame && a0.invMass > 0 && b0.invMass == 0) {
          final bounce = -vn * e;
          a0.px = a0.x - (rvx - vn * nx) - nx * bounce;
          a0.py = a0.y - (rvy - vn * ny) - ny * bounce;
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Queries

  Shape? shapeAt(double x, double y, {double pad = 0, bool Function(Shape)? filter}) {
    Shape? best;
    var bestD = double.infinity;
    for (final s in shapes) {
      if (!s.enabled) continue;
      if (filter != null && !filter(s)) continue;
      if (x < s.minX - pad || x > s.maxX + pad || y < s.minY - pad || y > s.maxY + pad) {
        continue;
      }
      final d = s.distanceTo(x, y);
      if (d <= pad && d < bestD) {
        bestD = d;
        best = s;
      }
    }
    return best;
  }

  List<Shape> shapesInRadius(double x, double y, double r) {
    final out = <Shape>[];
    for (final s in shapes) {
      if (!s.enabled) continue;
      if (x + r < s.minX || x - r > s.maxX || y + r < s.minY || y - r > s.maxY) continue;
      if (s.distanceTo(x, y) <= r) out.add(s);
    }
    return out;
  }

  /// Casts a ray from (ox,oy) in unit direction (dx,dy). Returns hits sorted
  /// by distance, each shape at most once.
  List<RayHit> raycast(double ox, double oy, double dx, double dy, double maxLen,
      {bool Function(Shape)? filter}) {
    final hits = <RayHit>[];
    final ex = ox + dx * maxLen, ey = oy + dy * maxLen;
    final rx0 = math.min(ox, ex), rx1 = math.max(ox, ex);
    final ry0 = math.min(oy, ey), ry1 = math.max(oy, ey);
    for (final s in shapes) {
      if (!s.enabled || s.sensor) continue;
      if (s.maxX < rx0 || s.minX > rx1 || s.maxY < ry0 || s.minY > ry1) continue;
      if (filter != null && !filter(s)) continue;
      final h = s.kind == ShapeKind.poly
          ? _rayPoly(s, ox, oy, dx, dy, maxLen)
          : _rayCapsule(s, ox, oy, dx, dy, maxLen);
      if (h != null) hits.add(h);
    }
    hits.sort((a, b) => a.t.compareTo(b.t));
    return hits;
  }

  RayHit? _rayPoly(Shape s, double ox, double oy, double dx, double dy, double maxLen) {
    var tEnter = 0.0, tExit = maxLen;
    var enx = 0.0, eny = 0.0;
    final n = s.pts.length;
    final cx = s.centerX(), cy = s.centerY();
    for (var i = 0; i < n; i++) {
      final a = s.pts[i], b = s.pts[(i + 1) % n];
      var nx = b.y - a.y, ny = -(b.x - a.x);
      final len = math.sqrt(nx * nx + ny * ny);
      if (len < 1e-9) continue;
      nx /= len;
      ny /= len;
      if ((cx - a.x) * nx + (cy - a.y) * ny > 0) {
        nx = -nx;
        ny = -ny;
      }
      final nm = (a.x - ox) * nx + (a.y - oy) * ny;
      final den = dx * nx + dy * ny;
      if (den.abs() < 1e-12) {
        if (nm < 0) return null; // parallel and outside
        continue;
      }
      final t = nm / den;
      if (den < 0) {
        if (t > tEnter) {
          tEnter = t;
          enx = nx;
          eny = ny;
        }
      } else {
        if (t < tExit) tExit = t;
      }
      if (tEnter > tExit) return null;
    }
    if (tEnter > maxLen) return null;
    if (enx == 0 && eny == 0) {
      // origin inside polygon
      enx = -dx;
      eny = -dy;
    }
    return RayHit(s, tEnter, ox + dx * tEnter, oy + dy * tEnter, enx, eny, tExit);
  }

  RayHit? _rayCapsule(Shape s, double ox, double oy, double dx, double dy, double maxLen) {
    final a = s.pts[0], b = s.pts[1];
    final ex = ox + dx * maxLen, ey = oy + dy * maxLen;
    _closestSegSeg(ox, oy, ex, ey, a.x, a.y, b.x, b.y);
    final r = s.radius;
    if (_ss.dist2 > r * r) return null;
    // bisection on [0, s*len] for first point within radius
    final tHit = _ss.s * maxLen;
    double dAt(double t) =>
        distPointSeg(ox + dx * t, oy + dy * t, a.x, a.y, b.x, b.y);
    if (dAt(0) <= r) {
      return RayHit(s, 0, ox, oy, -dx, -dy, tHit + r);
    }
    var lo = 0.0, hi = tHit;
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) * 0.5;
      if (dAt(mid) > r) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final hx = ox + dx * hi, hy = oy + dy * hi;
    final tt = projT(hx, hy, a.x, a.y, b.x, b.y);
    final cx = a.x + (b.x - a.x) * tt, cy = a.y + (b.y - a.y) * tt;
    var nx = hx - cx, ny = hy - cy;
    final l = math.sqrt(nx * nx + ny * ny);
    if (l > 1e-9) {
      nx /= l;
      ny /= l;
    } else {
      nx = -dx;
      ny = -dy;
    }
    // exit: symmetric estimate
    final exit = tHit + (tHit - hi);
    return RayHit(s, hi, hx, hy, nx, ny, exit);
  }
}
