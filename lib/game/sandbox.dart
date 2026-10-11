import 'dart:math' as math;
import 'dart:ui';

import '../core/sfx.dart';
import '../engine/physics.dart';
import 'catalog.dart';
import 'entity.dart';
import 'fx.dart';
import 'human.dart';
import 'maps.dart';

enum JointType { rope, weld, pin, spring, grip, nail }

/// A connection made by a tool (rope, weld, pin...) or by a human grabbing
/// an item. Stored by entity id + particle index so it can be saved.
class UserJoint {
  final JointType type;
  final Entity a;
  final int ia;
  final Entity? b; // null for pins (anchored to the world)
  final int ib;
  final List<Stick> sticks = [];
  Particle? anchor; // world anchor for pins
  UserJoint(this.type, this.a, this.ia, this.b, this.ib);

  Particle get pa => a.particles[ia];
  Particle? get pb => b == null ? anchor : b!.particles[ib];
}

class Link {
  final Entity a, b;
  Link(this.a, this.b);
}

class Flame {
  double x, y, vx, vy, life;
  final Entity? source;
  Flame(this.x, this.y, this.vx, this.vy, this.life, this.source);
}

class _Undo {
  final Entity? entity;
  final UserJoint? joint;
  final Link? link;
  _Undo({this.entity, this.joint, this.link});
}

class Sandbox {
  final PhysicsWorld world = PhysicsWorld();
  final FxSystem fx = FxSystem();
  final List<Entity> entities = [];
  final List<UserJoint> joints = [];
  final List<Link> links = [];
  final List<Flame> flames = [];
  final List<_Undo> _undo = [];
  final math.Random rng = math.Random();

  GameMap map;
  MapEntity? mapEntity;
  double time = 0;
  double timeScale = 1;
  bool paused = false;
  double gravityMul = 1;
  int nextId = 1;
  int nextGroup = 1000;
  Entity? selected;
  double substep = 1 / 120.0;
  int maxEntities = 400;
  double _fireTick = 0;
  /// Called when something notable happens (for haptics).
  void Function(double strength)? onRumble;

  Sandbox(this.map) {
    world.onSensor = _onSensor;
    loadMap(map);
  }

  // ------------------------------------------------------------------ setup
  void loadMap(GameMap m) {
    map = m;
    if (mapEntity != null) {
      removeEntity(mapEntity!, force: true);
    }
    final me = MapEntity(m);
    _register(me);
    mapEntity = me;
    fx.statics = me.shapes;
    world.globalFriction = m.friction;
    applyGravity();
  }

  void applyGravity() {
    world.gravityY = map.gravity * gravityMul;
    fx.gravity = world.gravityY;
  }

  int newGroup() => nextGroup++;

  void _register(Entity e) {
    if (e.id == 0) e.id = nextId++;
    if (e.id >= nextId) nextId = e.id + 1;
    e.attach(this);
    e.spawnTime = time;
    entities.add(e);
    for (final p in e.particles) {
      world.addParticle(p);
    }
    for (final s in e.sticks) {
      world.addStick(s);
    }
    for (final s in e.shapes) {
      world.addShape(s);
    }
    for (final a in e.angles) {
      world.addAngle(a);
    }
  }

  /// Adds an entity to the world. Returns it for chaining.
  T add<T extends Entity>(T e, {bool undoable = false}) {
    _register(e);
    if (undoable) _undo.add(_Undo(entity: e));
    return e;
  }

  Entity? spawn(String defId, double x, double y,
      {Map<String, dynamic>? data, bool undoable = true}) {
    final def = Catalog.byId(defId);
    if (def == null) return null;
    if (dynamicCount >= maxEntities) return null;
    final e = def.build(x, y, data);
    liftClear(e);
    add(e, undoable: undoable);
    Sfx.play('pop', vol: 0.4);
    return e;
  }

  int get dynamicCount => entities.length - 1;

  /// Moves a freshly built entity straight up until it no longer overlaps
  /// level geometry or frozen objects, so it starts on top of the floor
  /// instead of inside it.
  void liftClear(Entity e) {
    final statics = [
      for (final s in world.shapes)
        if (s.enabled && !s.sensor && s.isStatic) s
    ];
    if (e.frozen || e.shapes.isEmpty) return;
    for (var k = 0; k < 500; k++) {
      if (!_overlapsAny(e, statics)) return;
      for (final p in e.particles) {
        p.y -= 4;
        p.py -= 4;
      }
    }
  }

  bool _overlapsAny(Entity e, List<Shape> statics) {
    for (final s in e.shapes) {
      s.computeAabb(1);
      final probes = <List<double>>[];
      final n = s.pts.length;
      for (var i = 0; i < n; i++) {
        final a = s.pts[i], b = s.pts[(i + 1) % n];
        probes.add([a.x, a.y]);
        probes.add([(a.x + b.x) / 2, (a.y + b.y) / 2]);
      }
      for (final t in statics) {
        if (identical(t.owner, e)) continue;
        if (s.maxX < t.minX || s.minX > t.maxX || s.maxY < t.minY || s.minY > t.maxY) continue;
        for (final q in probes) {
          if (t.containsPoint(q[0], q[1], s.radius + 1)) return true;
        }
        if (s.kind == ShapeKind.poly) {
          for (final q in t.pts) {
            if (s.containsPoint(q.x, q.y, 1)) return true;
          }
        }
      }
    }
    return false;
  }

  void removeEntity(Entity e, {bool force = false}) {
    if (e is MapEntity && !force) return;
    if (e.removed) return;
    e.removed = true;
    entities.remove(e);
    world.removeShapes(e.shapes);
    world.removeParticles(e.particles);
    for (final s in e.sticks) {
      world.removeStick(s);
    }
    joints.removeWhere((j) {
      final hit = identical(j.a, e) || identical(j.b, e);
      if (hit) _dropJoint(j);
      return hit;
    });
    links.removeWhere((l) => identical(l.a, e) || identical(l.b, e));
    _undo.removeWhere((u) =>
        identical(u.entity, e) ||
        (u.joint != null && (identical(u.joint!.a, e) || identical(u.joint!.b, e))) ||
        (u.link != null && (identical(u.link!.a, e) || identical(u.link!.b, e))));
    for (final o in entities) {
      if (o is Human && identical(o.held, e)) o.held = null;
    }
    if (identical(selected, e)) selected = null;
  }

  void clearAll() {
    for (final e in List<Entity>.from(entities)) {
      if (e is! MapEntity) removeEntity(e);
    }
    joints.clear();
    links.clear();
    flames.clear();
    _undo.clear();
    fx.clear();
    selected = null;
  }

  bool undo() {
    while (_undo.isNotEmpty) {
      final u = _undo.removeLast();
      if (u.entity != null && !u.entity!.removed) {
        removeEntity(u.entity!);
        return true;
      }
      if (u.joint != null && joints.contains(u.joint)) {
        removeJoint(u.joint!);
        return true;
      }
      if (u.link != null && links.contains(u.link)) {
        links.remove(u.link);
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------------ joints
  UserJoint? addJoint(JointType type, Entity a, int ia, Entity? b, int ib,
      {double? anchorX, double? anchorY, bool undoable = true, double? rest}) {
    if (ia < 0 || ia >= a.particles.length) return null;
    if (b != null && (ib < 0 || ib >= b.particles.length)) return null;
    final j = UserJoint(type, a, ia, b, ib);
    final pa = a.particles[ia];
    Particle pb;
    if (b == null) {
      final anchor = Particle(anchorX ?? pa.x, anchorY ?? pa.y, 0);
      j.anchor = anchor;
      world.addParticle(anchor);
      pb = anchor;
    } else {
      pb = b.particles[ib];
    }
    switch (type) {
      case JointType.rope:
        _jstick(j, pa, pb, StickKind.rope, 1.0, rest);
        break;
      case JointType.spring:
        _jstick(j, pa, pb, StickKind.spring, 0.06, rest);
        break;
      case JointType.pin:
        _jstick(j, pa, pb, StickKind.rigid, 1.0, 0);
        break;
      case JointType.grip:
        _jstick(j, pa, pb, StickKind.rigid, 1.0, rest ?? 0);
        break;
      case JointType.nail:
        _jstick(j, pa, pb, StickKind.rigid, 0.8, rest);
        j.sticks.first.breakForce = 0.6;
        break;
      case JointType.weld:
        // Weld: tie several particles of both bodies together rigidly and
        // stop them from colliding with each other.
        final bb = b!;
        final as_ = _nearestParticles(a, pb.x, pb.y, 2);
        final bs = _nearestParticles(bb, pa.x, pa.y, 2);
        for (final x in as_) {
          for (final y in bs) {
            _jstick(j, x, y, StickKind.rigid, 1.0, null);
          }
        }
        _mergeGroups(a, bb);
        break;
    }
    joints.add(j);
    if (undoable) _undo.add(_Undo(joint: j));
    return j;
  }

  void _jstick(UserJoint j, Particle a, Particle b, StickKind kind, double stiff, double? rest) {
    final s = Stick(a, b, rest: rest, stiffness: stiff, kind: kind)..tag = j;
    j.sticks.add(s);
    world.addStick(s);
  }

  List<Particle> _nearestParticles(Entity e, double x, double y, int n) {
    final ps = List<Particle>.from(e.particles);
    ps.sort((p, q) {
      final dp = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y);
      final dq = (q.x - x) * (q.x - x) + (q.y - y) * (q.y - y);
      return dp.compareTo(dq);
    });
    return ps.take(n).toList();
  }

  void _mergeGroups(Entity a, Entity b) {
    var g = 0;
    for (final s in a.shapes) {
      if (s.group != 0) g = s.group;
    }
    if (g == 0) {
      for (final s in b.shapes) {
        if (s.group != 0) g = s.group;
      }
    }
    if (g == 0) g = newGroup();
    final old = <int>{};
    for (final s in [...a.shapes, ...b.shapes]) {
      if (s.group != 0) old.add(s.group);
    }
    for (final e in entities) {
      for (final s in e.shapes) {
        if (old.contains(s.group) || identical(e, a) || identical(e, b)) s.group = g;
      }
    }
  }

  void _dropJoint(UserJoint j) {
    for (final s in j.sticks) {
      world.removeStick(s);
    }
    if (j.anchor != null) world.removeParticles([j.anchor!]);
  }

  void removeJoint(UserJoint j) {
    _dropJoint(j);
    joints.remove(j);
    if (j.type == JointType.grip) {
      for (final e in entities) {
        if (e is Human && identical(e.gripJoint, j)) {
          e.gripJoint = null;
          e.held = null;
        }
      }
    }
  }

  /// Removes user joints and wires close to a point. Returns how many.
  int cutAt(double x, double y, double r) {
    var n = 0;
    for (final j in List<UserJoint>.from(joints)) {
      final pa = j.pa, pb = j.pb;
      if (pb == null) continue;
      if (distPointSeg(x, y, pa.x, pa.y, pb.x, pb.y) < r) {
        removeJoint(j);
        n++;
      }
    }
    for (final l in List<Link>.from(links)) {
      if (distPointSeg(x, y, l.a.cx, l.a.cy, l.b.cx, l.b.cy) < r) {
        links.remove(l);
        n++;
      }
    }
    return n;
  }

  Link? addLink(Entity a, Entity b) {
    if (identical(a, b)) return null;
    for (final l in links) {
      if ((identical(l.a, a) && identical(l.b, b)) || (identical(l.a, b) && identical(l.b, a))) {
        return null;
      }
    }
    final l = Link(a, b);
    links.add(l);
    _undo.add(_Undo(link: l));
    return l;
  }

  // ------------------------------------------------------------------ queries
  Entity? entityAt(double x, double y, {double pad = 8, bool includeMap = false}) {
    final s = world.shapeAt(x, y, pad: pad, filter: (s) {
      final o = s.owner;
      if (o is MapEntity) return includeMap;
      return o is Entity;
    });
    return s?.owner as Entity?;
  }

  Shape? shapeAt(double x, double y, {double pad = 8}) {
    return world.shapeAt(x, y, pad: pad, filter: (s) => s.owner is! MapEntity);
  }

  int nearestParticleIndex(Entity e, double x, double y) {
    var best = -1;
    var bd = double.infinity;
    for (var i = 0; i < e.particles.length; i++) {
      final p = e.particles[i];
      final d = (p.x - x) * (p.x - x) + (p.y - y) * (p.y - y);
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  Iterable<Human> get humans => entities.whereType<Human>();

  /// True when the straight line between two points is not blocked by map
  /// geometry or frozen bodies.
  bool lineOfSight(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1, dy = y2 - y1;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return true;
    final hits = world.raycast(x1, y1, dx / len, dy / len, len,
        filter: (s) => s.owner is MapEntity || (s.owner is Entity && (s.owner as Entity).frozen));
    return hits.isEmpty;
  }

  // ------------------------------------------------------------------ combat
  void fireBullet(double ox, double oy, double dx, double dy,
      {double damage = 20,
      double force = 3,
      double range = 5000,
      double penetration = 1,
      Entity? source,
      Color color = const Color(0xFFFFE08A),
      DmgType type = DmgType.bullet,
      double width = 1.6,
      bool tracer = true,
      bool ignite = false}) {
    final holder = source is HeldItem ? (source as HeldItem).holder : null;
    final hits = world.raycast(ox, oy, dx, dy, range, filter: (s) {
      final o = s.owner;
      if (source != null && identical(o, source)) return false;
      if (holder != null && identical(o, holder)) return false;
      return true;
    });
    var power = penetration;
    var endT = range;
    for (final h in hits) {
      final o = h.shape.owner;
      if (o is MapEntity) {
        endT = h.t;
        fx.sparks(h.x, h.y, h.nx, h.ny, 4);
        fx.debris(h.x, h.y, 2, map.groundColor, speed: 200, size: 2.5);
        if (ignite) fx.fire(h.x, h.y, 4);
        break;
      }
      if (o is! Entity) continue;
      final e = o;
      final hit = Hit(h.x, h.y, dx, dy, damage * power, force * power, type,
          shape: h.shape, source: source);
      e.receiveHit(hit);
      if (ignite) e.ignite(4);
      final mi = matInfo[e is Human ? Mat.flesh : e.material]!;
      if (e is! Human) {
        if (mi.sparks) {
          fx.sparks(h.x, h.y, h.nx, h.ny, 5);
        } else if (e.material == Mat.glass) {
          fx.glass(h.x, h.y, 3);
        } else {
          fx.debris(h.x, h.y, 3, mi.color, speed: 220, size: 2.5);
        }
        Sfx.play(mi.impactSound, vol: 0.25, rate: 1.3);
      }
      if (hit.stopped) {
        endT = h.t;
        break;
      }
      final thick = math.max(3.0, h.exitT - h.t);
      power -= thick * mi.pierce;
      if (power <= 0.05) {
        endT = h.t;
        break;
      }
    }
    if (tracer) {
      fx.tracer(ox, oy, ox + dx * endT, oy + dy * endT, color: color, width: width);
    }
  }

  /// Radial blast. [power] is the velocity change (units/s) near the centre.
  void explode(double x, double y, double radius, double power,
      {double damage = 120, bool fire = true, Entity? source}) {
    fx.explosion(x, y, radius);
    Sfx.play(radius > 260 ? 'boom_big' : 'boom', vol: math.min(1.0, radius / 200));
    onRumble?.call(math.min(1.0, radius / 300));
    final r2 = radius * 1.4;
    for (final p in world.particles) {
      if (p.invMass == 0) continue;
      final dx = p.x - x, dy = p.y - y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > r2) continue;
      final fall = 1 - d / r2;
      final dv = power * fall * world.prevDt / (1 + p.mass * 0.02);
      final ux = d < 1e-3 ? 0.0 : dx / d, uy = d < 1e-3 ? -1.0 : dy / d;
      p.kick(ux * dv, uy * dv - dv * 0.15);
    }
    for (final e in List<Entity>.from(entities)) {
      if (e is MapEntity || e.removed || identical(e, source)) continue;
      var best = double.infinity;
      Shape? bs;
      for (final s in e.shapes) {
        final d = s.distanceTo(x, y);
        if (d < best) {
          best = d;
          bs = s;
        }
      }
      if (bs == null || best > radius) continue;
      var fall = 1 - best / radius;
      if (!lineOfSight(x, y, bs.centerX(), bs.centerY())) fall *= 0.3;
      final dx = bs.centerX() - x, dy = bs.centerY() - y;
      final d = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      e.receiveHit(Hit(bs.centerX(), bs.centerY(), dx / d, dy / d, damage * fall, 0,
          DmgType.explosion, shape: bs, source: source));
      if (fire && fall > 0.5) e.ignite(3);
    }
  }

  void shootFlame(double x, double y, double vx, double vy, Entity? source) {
    if (flames.length > 220) flames.removeAt(0);
    flames.add(Flame(x, y, vx, vy, 0.55 + rng.nextDouble() * 0.25, source));
  }

  void shockAt(Entity target, double damage, {double x = 0, double y = 0, bool arc = false}) {
    target.receiveHit(Hit(target.cx, target.cy, 0, 0, damage, 0, DmgType.electric));
  }

  // ------------------------------------------------------------------ update
  void update(double frameDt) {
    if (paused) return;
    final simDt = math.min(frameDt, 1 / 30) * timeScale;
    if (simDt <= 0) return;
    final n = math.max(1, (simDt / substep).ceil());
    final dt = simDt / n;
    for (var i = 0; i < n; i++) {
      for (final e in entities) {
        e.preStep(dt);
      }
      world.step(dt);
      _processImpacts();
    }
    time += simDt;
    for (final e in List<Entity>.from(entities)) {
      if (!e.removed) e.update(simDt);
    }
    _updatePower();
    _updateFire(simDt);
    _updateFlames(simDt);
    fx.update(simDt);
    // kill zone
    for (final e in List<Entity>.from(entities)) {
      if (e is MapEntity) continue;
      if (e.particles.isNotEmpty && e.cy > map.killY) removeEntity(e);
    }
  }

  double _lastImpactSound = 0;

  void _processImpacts() {
    for (final imp in world.impacts) {
      final ea = imp.a.owner, eb = imp.b.owner;
      if (ea is Entity) ea.onImpact(imp, imp.a, imp.b, imp.speed);
      if (eb is Entity) eb.onImpact(imp, imp.b, imp.a, imp.speed);
      if (imp.speed > 500 && time - _lastImpactSound > 0.05) {
        _lastImpactSound = time;
        final e = ea is MapEntity ? eb : ea;
        var snd = 'thud';
        if (e is Human) {
          snd = 'thud';
        } else if (e is Entity) {
          snd = matInfo[e.material]!.impactSound;
        }
        Sfx.play(snd, vol: math.min(1.0, imp.speed / 2500), rate: 0.9 + rng.nextDouble() * 0.3);
      }
    }
  }

  void _onSensor(Shape sensor, Shape other) {
    final o = sensor.owner;
    if (o is SensorListener) (o as SensorListener).onSensor(sensor, other);
  }

  void _updatePower() {
    for (final e in entities) {
      e.wasPowered = e.powered;
      e.powered = false;
    }
    if (links.isNotEmpty) {
      final adj = <Entity, List<Entity>>{};
      for (final l in links) {
        adj.putIfAbsent(l.a, () => []).add(l.b);
        adj.putIfAbsent(l.b, () => []).add(l.a);
      }
      final queue = <Entity>[];
      for (final e in entities) {
        if (e.isPowerSource && e.sourceOn) queue.add(e);
      }
      final seen = <Entity>{...queue};
      while (queue.isNotEmpty) {
        final e = queue.removeLast();
        for (final n in adj[e] ?? const <Entity>[]) {
          if (seen.add(n)) {
            n.powered = true;
            queue.add(n);
          } else if (!n.isPowerSource) {
            n.powered = true;
          }
        }
      }
    }
    for (final e in entities) {
      if (e.powered != e.wasPowered) e.onPowerChanged(e.powered);
    }
  }

  void _updateFire(double dt) {
    _fireTick += dt;
    final spread = _fireTick > 0.3;
    if (spread) _fireTick = 0;
    for (final e in List<Entity>.from(entities)) {
      if (e.burning <= 0 || e.removed) continue;
      e.burning -= dt;
      e.charred = math.min(1.0, e.charred + dt * 0.04);
      if (e.shapes.isNotEmpty && rng.nextDouble() < 0.6) {
        final s = e.shapes[rng.nextInt(e.shapes.length)];
        fx.fire(s.centerX(), s.centerY(), 1, size: 6);
        if (rng.nextDouble() < 0.15) fx.smoke(s.centerX(), s.centerY() - 10, 1, size: 6);
      }
      if (e is! Human) e.damage(dt * 2.5, DmgType.fire);
      if (e is Human) e.burnTick(dt);
      if (spread) {
        for (final s in e.shapes) {
          for (final o in world.shapesInRadius(s.centerX(), s.centerY(), 22)) {
            final oe = o.owner;
            if (oe is Entity && !identical(oe, e) && oe is! MapEntity && oe.burning <= 0) {
              if (rng.nextDouble() < 0.25 * (matInfo[oe.material]!.flammability + 0.2)) {
                oe.ignite(5);
              }
            }
          }
        }
      }
    }
  }

  void _updateFlames(double dt) {
    for (var i = flames.length - 1; i >= 0; i--) {
      final f = flames[i];
      f.life -= dt;
      if (f.life <= 0) {
        flames.removeAt(i);
        continue;
      }
      f.vy -= 200 * dt;
      f.vx *= 0.97;
      f.vy *= 0.97;
      final nx = f.x + f.vx * dt, ny = f.y + f.vy * dt;
      final s = world.shapeAt(nx, ny, pad: 6, filter: (s) => !identical(s.owner, f.source));
      if (s != null) {
        final o = s.owner;
        if (o is MapEntity) {
          f.vx *= -0.2;
          f.vy *= -0.2;
        } else if (o is Entity) {
          if (rng.nextDouble() < 0.35) o.ignite(5);
          o.receiveHit(Hit(nx, ny, 0, -1, 9 * dt * 10, 0.0, DmgType.fire, shape: s));
          f.life -= 0.15;
        }
      } else {
        f.x = nx;
        f.y = ny;
      }
      if (rng.nextDouble() < 0.7) fx.fire(f.x, f.y, 1, size: 6 + (0.8 - f.life) * 14);
    }
  }

  // ------------------------------------------------------------------ save/load
  Map<String, dynamic> toJson({String name = '', double camX = 0, double camY = 0, double zoom = 1}) {
    return {
      'format': 'ragbox-scene',
      'version': 1,
      'name': name,
      'map': map.id,
      'gravityMul': gravityMul,
      'time': time,
      'cam': [camX, camY, zoom],
      'nextId': nextId,
      'entities': [
        for (final e in entities)
          if (e is! MapEntity) e.toJson()
      ],
      'joints': [
        for (final j in joints)
          {
            't': j.type.index,
            'a': j.a.id,
            'ia': j.ia,
            'b': j.b?.id,
            'ib': j.ib,
            if (j.anchor != null) 'ax': j.anchor!.x,
            if (j.anchor != null) 'ay': j.anchor!.y,
            'rest': j.sticks.isNotEmpty ? j.sticks.first.rest : 0,
          }
      ],
      'links': [
        for (final l in links) [l.a.id, l.b.id]
      ],
    };
  }

  /// Rebuilds the scene from JSON. Unknown items are skipped.
  void loadJson(Map<String, dynamic> j) {
    clearAll();
    final mapId = j['map'] as String? ?? 'flat';
    loadMap(GameMaps.byId(mapId));
    gravityMul = (j['gravityMul'] as num?)?.toDouble() ?? 1;
    applyGravity();
    time = (j['time'] as num?)?.toDouble() ?? 0;
    final byId = <int, Entity>{};
    for (final raw in (j['entities'] as List? ?? const [])) {
      final ej = (raw as Map).cast<String, dynamic>();
      final def = Catalog.byId(ej['def'] as String? ?? '');
      if (def == null) continue;
      final data = (ej['d'] as Map?)?.cast<String, dynamic>();
      final e = def.build(0, 0, data);
      e.id = (ej['id'] as num?)?.toInt() ?? 0;
      e.restoreFromJson(ej);
      _register(e);
      byId[e.id] = e;
    }
    nextId = math.max(nextId, (j['nextId'] as num?)?.toInt() ?? nextId);
    for (final raw in (j['joints'] as List? ?? const [])) {
      final jj = (raw as Map).cast<String, dynamic>();
      final ti = (jj['t'] as num?)?.toInt() ?? 0;
      if (ti < 0 || ti >= JointType.values.length) continue;
      final a = byId[(jj['a'] as num?)?.toInt()];
      if (a == null) continue;
      final bid = (jj['b'] as num?)?.toInt();
      final b = bid == null ? null : byId[bid];
      final type = JointType.values[ti];
      if (bid != null && b == null) continue;
      if (b == null && type != JointType.pin && type != JointType.rope && type != JointType.spring) continue;
      final rest = (jj['rest'] as num?)?.toDouble();
      final uj = addJoint(type, a, (jj['ia'] as num?)?.toInt() ?? 0, b, (jj['ib'] as num?)?.toInt() ?? 0,
          anchorX: (jj['ax'] as num?)?.toDouble(),
          anchorY: (jj['ay'] as num?)?.toDouble(),
          undoable: false,
          rest: type == JointType.weld ? null : rest);
      if (uj != null && type == JointType.grip && a is Human && b != null) {
        a.restoreGrip(uj, b);
      }
    }
    for (final raw in (j['links'] as List? ?? const [])) {
      final l = raw as List;
      if (l.length < 2) continue;
      final a = byId[(l[0] as num).toInt()], b = byId[(l[1] as num).toInt()];
      if (a != null && b != null) links.add(Link(a, b));
    }
    _undo.clear();
  }
}

/// Items that can be held by a human (guns, melee weapons).
abstract class HeldItem {
  Human? holder;
  /// Index of the particle used as grip.
  int get gripIndex;
}

abstract class SensorListener {
  void onSensor(Shape mine, Shape other);
}
