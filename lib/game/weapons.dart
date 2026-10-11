import 'dart:math' as math;
import 'dart:ui';

import '../core/sfx.dart';
import '../engine/physics.dart';
import 'entity.dart';
import 'human.dart';
import 'sandbox.dart';

enum Proj { bullet, rail, laser, rocket, grenade, flame, tesla, freeze, gravity, heal, bolt, nail, flare, plasma, water }

enum GunStyle {
  pistol, revolver, smg, rifle, battle, sniper, shotgun, autoShotgun, lmg, minigun, launcher,
  grenadeLauncher, flamer, laser, rail, tesla, freeze, gravity, medic, crossbow, flare, nail, plasma,
  deagle, dual, musket, uzi, carbine, antimat, blunder, waterGun
}

class GunDef {
  final String id, name, desc;
  final GunStyle style;
  final double length, height, mass;
  final double damage, rate, spread, force, recoil, range, pen;
  final int pellets;
  final bool auto;
  final Proj proj;
  final String sound;
  final Color tracer;
  const GunDef(this.id, this.name, this.desc,
      {required this.style,
      this.length = 40,
      this.height = 14,
      this.mass = 3,
      this.damage = 25,
      this.rate = 4,
      this.spread = 0.02,
      this.force = 2500,
      this.recoil = 600,
      this.range = 4500,
      this.pen = 1,
      this.pellets = 1,
      this.auto = false,
      this.proj = Proj.bullet,
      this.sound = 'pistol',
      this.tracer = const Color(0xFFFFE08A)});
}

class Guns {
  static const List<GunDef> all = [
    GunDef('pistol', 'Pistol', 'Reliable semi-auto sidearm.', style: GunStyle.pistol, length: 30, height: 18, mass: 2),
    GunDef('revolver', 'Revolver', 'Six-shooter with a heavy punch.',
        style: GunStyle.revolver, length: 36, height: 18, mass: 2.5, damage: 48, rate: 2, force: 4500, recoil: 1400, pen: 1.6, sound: 'heavy'),
    GunDef('deagle', 'Hand Cannon', 'Oversized pistol. Kicks like a mule.',
        style: GunStyle.deagle, length: 38, height: 20, mass: 3, damage: 60, rate: 1.6, force: 6000, recoil: 2000, pen: 2, sound: 'heavy'),
    GunDef('dual', 'Machine Pistol', 'Full-auto pistol. Sprays everywhere.',
        style: GunStyle.dual, length: 32, height: 18, mass: 2, damage: 14, rate: 16, spread: 0.08, auto: true, force: 1500, recoil: 350),
    GunDef('smg', 'SMG', 'Compact full-auto submachine gun.',
        style: GunStyle.smg, length: 48, height: 18, mass: 3, damage: 16, rate: 13, spread: 0.05, auto: true, force: 1800, recoil: 300, sound: 'smg'),
    GunDef('uzi', 'Compact SMG', 'Tiny, fast and inaccurate.',
        style: GunStyle.uzi, length: 34, height: 20, mass: 2.4, damage: 13, rate: 18, spread: 0.09, auto: true, force: 1400, recoil: 280, sound: 'smg'),
    GunDef('rifle', 'Assault Rifle', 'Versatile automatic rifle.',
        style: GunStyle.rifle, length: 70, height: 18, mass: 4, damage: 26, rate: 10, spread: 0.025, auto: true, force: 3000, recoil: 500, pen: 1.8, sound: 'rifle'),
    GunDef('carbine', 'Carbine', 'Short rifle with three-round bursts of power.',
        style: GunStyle.carbine, length: 60, height: 17, mass: 3.5, damage: 30, rate: 7, spread: 0.02, auto: true, force: 3200, recoil: 550, pen: 1.8, sound: 'rifle'),
    GunDef('battle', 'Battle Rifle', 'Hard-hitting semi-auto rifle.',
        style: GunStyle.battle, length: 78, height: 18, mass: 5, damage: 55, rate: 4, spread: 0.01, force: 5000, recoil: 1100, pen: 2.5, sound: 'rifle'),
    GunDef('sniper', 'Sniper Rifle', 'Long-range bolt action. Goes through people.',
        style: GunStyle.sniper, length: 100, height: 16, mass: 6, damage: 120, rate: 0.8, spread: 0.0, force: 9000, recoil: 2200, pen: 4, range: 9000, sound: 'sniper'),
    GunDef('antimat', 'Anti-Materiel Rifle', 'Punches through walls of bodies and metal.',
        style: GunStyle.antimat, length: 125, height: 20, mass: 12, damage: 260, rate: 0.5, spread: 0.0, force: 18000, recoil: 5000, pen: 9, range: 10000, sound: 'sniper'),
    GunDef('musket', 'Musket', 'Old flintlock. Slow, smoky and brutal.',
        style: GunStyle.musket, length: 105, height: 12, mass: 5, damage: 90, rate: 0.35, spread: 0.03, force: 7000, recoil: 1800, pen: 1.5, sound: 'heavy'),
    GunDef('shotgun', 'Shotgun', 'Pump action spread of pellets.',
        style: GunStyle.shotgun, length: 75, height: 16, mass: 4.5, damage: 16, rate: 1.2, spread: 0.12, pellets: 9, force: 2200, recoil: 1800, range: 1600, sound: 'shotgun'),
    GunDef('autoshotgun', 'Auto Shotgun', 'Drum-fed automatic shotgun.',
        style: GunStyle.autoShotgun, length: 72, height: 20, mass: 6, damage: 13, rate: 4, spread: 0.14, pellets: 7, auto: true, force: 1800, recoil: 1300, range: 1400, sound: 'shotgun'),
    GunDef('blunderbuss', 'Blunderbuss', 'Flared barrel full of scrap.',
        style: GunStyle.blunder, length: 70, height: 16, mass: 5, damage: 12, rate: 0.5, spread: 0.3, pellets: 16, force: 1800, recoil: 2500, range: 900, sound: 'shotgun'),
    GunDef('lmg', 'Light Machine Gun', 'Belt-fed suppression.',
        style: GunStyle.lmg, length: 92, height: 22, mass: 9, damage: 28, rate: 12, spread: 0.045, auto: true, force: 3200, recoil: 650, pen: 2, sound: 'rifle'),
    GunDef('minigun', 'Minigun', 'Rotary cannon. Shreds everything.',
        style: GunStyle.minigun, length: 96, height: 26, mass: 18, damage: 24, rate: 30, spread: 0.06, auto: true, force: 2800, recoil: 450, pen: 1.6, sound: 'smg'),
    GunDef('rpg', 'Rocket Launcher', 'Fires a rocket that explodes on contact.',
        style: GunStyle.launcher, length: 100, height: 20, mass: 8, rate: 0.7, proj: Proj.rocket, recoil: 900, sound: 'rocket'),
    GunDef('gl', 'Grenade Launcher', 'Lobs impact grenades.',
        style: GunStyle.grenadeLauncher, length: 62, height: 24, mass: 6, rate: 1.4, proj: Proj.grenade, recoil: 1200, sound: 'thump'),
    GunDef('flamer', 'Flamethrower', 'Hose things down with fire.',
        style: GunStyle.flamer, length: 78, height: 22, mass: 8, rate: 30, auto: true, proj: Proj.flame, recoil: 30, sound: 'flame'),
    GunDef('laser', 'Laser Rifle', 'Burning beam. Sets targets alight.',
        style: GunStyle.laser, length: 70, height: 18, mass: 4, damage: 30, rate: 6, spread: 0.0, auto: true, force: 500, recoil: 80, pen: 1.5, proj: Proj.laser, sound: 'laser', tracer: Color(0xFFFF1744)),
    GunDef('railgun', 'Railgun', 'Magnetic slug. Passes through everything in a line.',
        style: GunStyle.rail, length: 96, height: 22, mass: 10, damage: 200, rate: 0.6, spread: 0.0, force: 15000, recoil: 3500, pen: 30, range: 12000, proj: Proj.rail, sound: 'rail', tracer: Color(0xFF40C4FF)),
    GunDef('tesla', 'Tesla Gun', 'Chain lightning that jumps between targets.',
        style: GunStyle.tesla, length: 58, height: 24, mass: 5, damage: 30, rate: 3, proj: Proj.tesla, recoil: 100, range: 520, sound: 'zap'),
    GunDef('freeze', 'Cryo Ray', 'Freezes people solid for a while.',
        style: GunStyle.freeze, length: 58, height: 22, mass: 4, rate: 2, proj: Proj.freeze, recoil: 50, range: 1500, sound: 'laser', tracer: Color(0xFF80D8FF)),
    GunDef('gravgun', 'Gravity Gun', 'Activate to grab objects at range, activate again to launch them.',
        style: GunStyle.gravity, length: 62, height: 24, mass: 6, rate: 3, proj: Proj.gravity, recoil: 0, range: 900, sound: 'zap'),
    GunDef('medigun', 'Medi Beam', 'Heals and revives people. Repairs objects.',
        style: GunStyle.medic, length: 54, height: 22, mass: 3, damage: 18, rate: 6, auto: true, proj: Proj.heal, recoil: 0, range: 900, sound: 'heal', tracer: Color(0xFF69F0AE)),
    GunDef('crossbow', 'Crossbow', 'Bolts pin limbs to whatever is behind them.',
        style: GunStyle.crossbow, length: 62, height: 30, mass: 4, damage: 45, rate: 1, proj: Proj.bolt, recoil: 300, sound: 'bow'),
    GunDef('nailgun', 'Nail Gun', 'Fires nails that pin objects together.',
        style: GunStyle.nail, length: 44, height: 26, mass: 3, damage: 12, rate: 6, auto: true, proj: Proj.nail, recoil: 120, sound: 'click'),
    GunDef('flaregun', 'Flare Gun', 'Burning flare that ignites what it touches.',
        style: GunStyle.flare, length: 32, height: 20, mass: 1.5, rate: 1, proj: Proj.flare, recoil: 300, sound: 'thump'),
    GunDef('plasma', 'Plasma Cannon', 'Glowing bolts that burst on impact.',
        style: GunStyle.plasma, length: 70, height: 26, mass: 7, rate: 3, proj: Proj.plasma, recoil: 500, sound: 'laser', tracer: Color(0xFFE040FB)),
    GunDef('watergun', 'Water Blaster', 'Puts out fires and knocks things around.',
        style: GunStyle.waterGun, length: 50, height: 26, mass: 1.2, rate: 24, auto: true, proj: Proj.water, recoil: 10, range: 700, sound: 'click'),
  ];

  static GunDef? byId(String id) {
    for (final g in all) {
      if (g.id == id) return g;
    }
    return null;
  }
}

/// Shared aiming logic for held items with a rigid box body.
mixin AimBody on Entity {
  late List<Particle> body;
  late Particle grip;
  double aimTimer = 0;
  double aimX = 0, aimY = 0;
  final List<List<double>> restLocal = [];

  void captureRest(double gx, double gy) {
    // local coordinates (in box frame) of all particles, relative to grip
    final f = BoxFrame()..from(body);
    restLocal.clear();
    for (final p in particles) {
      final dx = p.x - f.cx, dy = p.y - f.cy;
      restLocal.add([dx * f.ux + dy * f.uy - gx, dx * f.vx + dy * f.vy - gy]);
    }
  }

  /// Seconds left during which the player's finger owns the aim.
  double playerAimT = 0;

  void aimAt(double x, double y, double dt) {
    if (playerAimT > 0) return; // the player is aiming this weapon
    aimX = x;
    aimY = y;
    aimTimer = 0.35;
  }

  /// Aim set by the player's second finger; overrides AI aiming.
  void playerAim(double x, double y) {
    aimX = x;
    aimY = y;
    aimTimer = 0.25;
    playerAimT = 0.25;
  }

  /// Mirrors the weapon around its grip when aiming the other way, so it
  /// never ends up upside down.
  void keepUpright(double x, double y) {
    final f = BoxFrame()..from(body);
    final ang = math.atan2(y - grip.y, x - grip.x);
    if (f.handed * math.cos(ang) < -0.25) mirrorAround(grip.x);
  }

  void mirrorAround(double x) {
    for (final p in particles) {
      p.x = 2 * x - p.x;
      p.px = 2 * x - p.px;
    }
  }

  void applyAim(double dt) {
    if (aimTimer <= 0) return;
    final f = BoxFrame()..from(body);
    final ang = math.atan2(aimY - grip.y, aimX - grip.x);
    final cs = math.cos(ang), sn = math.sin(ang);
    final hd = f.handed;
    const kp = 1400.0, kd = 45.0;
    for (var i = 0; i < particles.length && i < restLocal.length; i++) {
      final p = particles[i];
      if (identical(p, grip)) continue;
      final lx = restLocal[i][0], ly = restLocal[i][1] * hd;
      final tx = grip.x + lx * cs - ly * sn;
      final ty = grip.y + lx * sn + ly * cs;
      final vx = (p.x - p.px) / dt, vy = (p.y - p.py) / dt;
      p.ax += (tx - p.x) * kp - vx * kd;
      p.ay += (ty - p.y) * kp - vy * kd;
    }
  }

  double aimError(double x, double y) {
    final f = BoxFrame()..from(body);
    final want = math.atan2(y - grip.y, x - grip.x);
    final have = math.atan2(f.uy, f.ux);
    var d = (want - have).abs() % (math.pi * 2);
    if (d > math.pi) d = math.pi * 2 - d;
    return d;
  }
}

class Gun extends Entity with AimBody implements HeldItem, Shooter {
  final GunDef def;
  double cooldown = 0;
  @override
  Human? holder;
  Entity? _gravHeld;
  double _spin = 0;

  Gun(this.def, double x, double y) : super(def.id, material: Mat.metal) {
    body = makeBox(x, y, def.length, def.height, def.mass * 0.85);
    final gx = -def.length * 0.22, gy = def.height * 0.3;
    final f = BoxFrame()..from(body);
    grip = addP(f.wx(gx, gy), f.wy(gx, gy), def.mass * 0.15);
    for (final p in body) {
      addStick(grip, p);
    }
    addPoly(body);
    captureRest(gx, gy);
  }

  @override
  int get gripIndex => particles.indexOf(grip);

  @override
  String get name => def.name;

  BoxFrame get frame => BoxFrame()..from(body);

  @override
  void use() {
    if (def.auto) {
      activated = !activated;
      if (!activated) _releaseGrav();
    } else if (def.proj == Proj.gravity) {
      activated = !activated;
      if (!activated) _releaseGrav(launch: true);
    } else {
      tryFire();
    }
  }

  @override
  void aiTrigger() {
    if (def.proj == Proj.gravity) return;
    tryFire();
  }

  @override
  void onPowerChanged(bool now) {
    if (def.auto) {
      activated = now;
    } else if (now) {
      tryFire();
    }
  }

  @override
  void preStep(double dt) {
    if (aimTimer > 0) applyAim(dt);
    final g = _gravHeld;
    if (g != null && activated) {
      if (g.removed) {
        _gravHeld = null;
        return;
      }
      final f = frame;
      final hx = f.wx(def.length / 2 + 70, 0), hy = f.wy(def.length / 2 + 70, 0);
      for (final p in g.particles) {
        final vx = (p.x - p.px) / dt, vy = (p.y - p.py) / dt;
        final gx = g.cx, gy = g.cy;
        p.ax += (hx - gx) * 60 - vx * 8 - sb.world.gravityX * p.gravityScale;
        p.ay += (hy - gy) * 60 - vy * 8 - sb.world.gravityY * p.gravityScale;
      }
    }
  }

  @override
  void update(double dt) {
    if (holder != null && (holder!.removed || !identical(holder!.held, this))) holder = null;
    if (aimTimer > 0) aimTimer -= dt;
    if (playerAimT > 0) playerAimT -= dt;
    cooldown -= dt;
    if (def.style == GunStyle.minigun && on) _spin += dt * 30;
    if (def.auto && on) tryFire();
    if (def.proj == Proj.gravity && activated && _gravHeld == null) {
      // try to grab something
      final f = frame;
      final hits = sb.world.raycast(f.wx(def.length / 2, 0), f.wy(def.length / 2, 0), f.ux, f.uy, def.range,
          filter: (s) => !identical(s.owner, this) && !identical(s.owner, holder));
      for (final h in hits) {
        final o = h.shape.owner;
        if (o is Entity && o.particles.isNotEmpty && !o.frozen && o.totalMass < 2000 &&
            o.particles.first.invMass > 0) {
          _gravHeld = o;
          Sfx.play('zap', vol: 0.4, rate: 1.4);
          break;
        }
        if (o != null && o is! Entity) break;
        if (o is Entity && (o.frozen || o.particles.first.invMass == 0)) break;
      }
    }
  }

  void _releaseGrav({bool launch = false}) {
    final g = _gravHeld;
    _gravHeld = null;
    if (g == null || g.removed || !launch) return;
    final f = frame;
    final dv = 2400 * stepDt;
    for (final p in g.particles) {
      p.kick(f.ux * dv, f.uy * dv);
    }
    Sfx.play('thump', vol: 0.7);
  }

  void tryFire() {
    if (cooldown > 0 || !attached) return;
    cooldown = 1 / def.rate;
    fire();
  }

  void fire() {
    final s = sb;
    final f = frame;
    final mx = f.wx(def.length / 2 + 2, -def.height * 0.15);
    final my = f.wy(def.length / 2 + 2, -def.height * 0.15);
    final baseAng = math.atan2(f.uy, f.ux);
    final spreadMul = holder != null ? 1.0 : 1.2;
    void flash() {
      s.fx.flash(mx, my, 10 + def.damage * 0.12);
    }

    switch (def.proj) {
      case Proj.bullet:
      case Proj.rail:
      case Proj.laser:
        for (var i = 0; i < def.pellets; i++) {
          final a = baseAng + (s.rng.nextDouble() - 0.5) * 2 * def.spread * spreadMul;
          s.fireBullet(mx, my, math.cos(a), math.sin(a),
              damage: def.damage,
              force: def.force,
              range: def.range,
              penetration: def.pen,
              source: this,
              color: def.tracer,
              type: def.proj == Proj.laser ? DmgType.laser : DmgType.bullet,
              width: def.proj == Proj.rail ? 4 : (def.proj == Proj.laser ? 2.5 : 1.6),
              ignite: def.proj == Proj.laser);
        }
        if (def.proj == Proj.bullet) {
          flash();
          if (def.style != GunStyle.musket) {
            s.fx.shell(f.wx(-2, -def.height / 2), f.wy(-2, -def.height / 2), f.ux);
          } else {
            s.fx.smoke(mx, my, 6, size: 8, color: const Color(0x99CCCCCC));
          }
        } else if (def.proj == Proj.rail) {
          s.fx.flash(mx, my, 24, color: const Color(0xFF80D8FF));
        } else {
          s.fx.flash(mx, my, 8, color: const Color(0xFFFF5252));
        }
        break;
      case Proj.rocket:
        {
          final r = Missile(MissileKind.rocket, mx + f.ux * 10, my + f.uy * 10, baseAng);
          s.add(r);
          r.launch(f.ux * 900, f.uy * 900);
          s.fx.smoke(f.wx(-def.length / 2, 0), f.wy(-def.length / 2, 0), 8, size: 10);
        }
        break;
      case Proj.grenade:
        {
          final r = Missile(MissileKind.grenade, mx, my, baseAng);
          s.add(r);
          r.launch(f.ux * 1100, f.uy * 1100);
          flash();
        }
        break;
      case Proj.flare:
        {
          final r = Missile(MissileKind.flare, mx, my, baseAng);
          s.add(r);
          r.launch(f.ux * 1300, f.uy * 1300);
          flash();
        }
        break;
      case Proj.plasma:
        {
          final r = Missile(MissileKind.plasma, mx, my, baseAng);
          s.add(r);
          r.launch(f.ux * 1600, f.uy * 1600);
          s.fx.flash(mx, my, 14, color: const Color(0xFFE040FB));
        }
        break;
      case Proj.bolt:
      case Proj.nail:
        {
          final kind = def.proj == Proj.bolt ? MissileKind.bolt : MissileKind.nail;
          final r = Missile(kind, mx, my, baseAng);
          s.add(r);
          final sp = def.proj == Proj.bolt ? 2200.0 : 1700.0;
          r.launch(f.ux * sp, f.uy * sp);
          r.damageValue = def.damage;
        }
        break;
      case Proj.flame:
        for (var i = 0; i < 2; i++) {
          final a = baseAng + (s.rng.nextDouble() - 0.5) * 0.25;
          final sp = 520 + s.rng.nextDouble() * 160;
          s.shootFlame(mx, my, math.cos(a) * sp + vx / stepDt * 0.5, math.sin(a) * sp, this);
        }
        break;
      case Proj.water:
        {
        for (var i = 0; i < 2; i++) {
          final a = baseAng + (s.rng.nextDouble() - 0.5) * 0.08;
          final sp = 700 + s.rng.nextDouble() * 200;
          s.fx.water(mx, my, math.cos(a) * sp, math.sin(a) * sp);
        }
        final hits = s.world.raycast(mx, my, f.ux, f.uy, def.range,
            filter: (sh) => !identical(sh.owner, this) && !identical(sh.owner, holder));
        if (hits.isNotEmpty) {
          final o = hits.first.shape.owner;
          if (o is Entity) {
            o.burning = 0;
            if (o is Human) o.burning = 0;
            o.applyImpulseAt(hits.first.shape, hits.first.x, hits.first.y, f.ux * 400, f.uy * 400);
          }
        }
        }
        break;
      case Proj.tesla:
        _tesla(mx, my, f);
        break;
      case Proj.freeze:
        {
        final hits = s.world.raycast(mx, my, f.ux, f.uy, def.range,
            filter: (sh) => !identical(sh.owner, this) && !identical(sh.owner, holder));
        var end = def.range;
        for (final h in hits) {
          final o = h.shape.owner;
          end = h.t;
          if (o is Human) {
            o.receiveHit(Hit(h.x, h.y, f.ux, f.uy, 0, 0, DmgType.cold, shape: h.shape));
          } else if (o is Entity) {
            o.burning = 0;
          }
          break;
        }
        s.fx.tracer(mx, my, mx + f.ux * end, my + f.uy * end, color: def.tracer, width: 5, life: 0.25);
        s.fx.smoke(mx + f.ux * end, my + f.uy * end, 3, size: 6, color: const Color(0x88E1F5FE));
        }
        break;
      case Proj.heal:
        {
        final hits = s.world.raycast(mx, my, f.ux, f.uy, def.range,
            filter: (sh) => !identical(sh.owner, this) && !identical(sh.owner, holder));
        var end = def.range;
        if (hits.isNotEmpty) {
          final h = hits.first;
          end = h.t;
          final o = h.shape.owner;
          if (o is Human) {
            o.heal(def.damage);
          } else if (o is Entity && o.hp.isFinite) {
            o.hp = math.min(o.maxHp, o.hp + def.damage);
            o.burning = 0;
          }
          s.fx.sparks(h.x, h.y, 0, -1, 2, color: const Color(0xFF69F0AE));
        }
        s.fx.tracer(mx, my, mx + f.ux * end, my + f.uy * end, color: def.tracer, width: 3, life: 0.12);
        }
        break;
      case Proj.gravity:
        activated = !activated;
        if (!activated) _releaseGrav(launch: true);
        return;
    }
    // recoil
    final rk = def.recoil * stepDt / math.max(1.0, totalMass) * (holder != null ? 0.5 : 1.0);
    for (final p in body) {
      p.kick(-f.ux * rk, -f.uy * rk - rk * 0.25);
    }
    if (holder != null) holder!.panic = 0;
    Sfx.play(def.sound, vol: 0.8, rate: 0.95 + s.rng.nextDouble() * 0.1);
    // nearby cowards get scared by gunfire
    for (final h in s.humans) {
      if (identical(h, holder)) continue;
      if (h.type.behavior == Behavior.coward && (h.cx - mx).abs() < 500 && def.proj == Proj.bullet) {
        h.panic = math.max(h.panic, 1.5);
      }
    }
  }

  void _tesla(double mx, double my, BoxFrame f) {
    final s = sb;
    final hitSet = <Entity>{this};
    if (holder != null) hitSet.add(holder!);
    var x = mx, y = my;
    var dirx = f.ux, diry = f.uy;
    var hitAny = false;
    for (var jump = 0; jump < 4; jump++) {
      Entity? best;
      var bd = jump == 0 ? def.range : 260.0;
      for (final e in s.entities) {
        if (hitSet.contains(e) || e.removed || e.particles.isEmpty) continue;
        if (!(e.conductive || e is Human)) continue;
        if (e.frozen && e is! Human) continue;
        final dx = e.cx - x, dy = e.cy - y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > bd) continue;
        if (jump == 0) {
          final dot = (dx * dirx + dy * diry) / math.max(1.0, d);
          if (dot < 0.8) continue;
        }
        bd = d;
        best = e;
      }
      if (best == null) break;
      hitAny = true;
      final tx = best.cx, ty = best.cy;
      s.fx.arc(x, y, tx, ty);
      best.receiveHit(Hit(tx, ty, 0, 0, def.damage * (1 - jump * 0.15), 0, DmgType.electric));
      best.powered = true;
      hitSet.add(best);
      dirx = tx - x;
      diry = ty - y;
      x = tx;
      y = ty;
    }
    if (!hitAny) {
      final ex = mx + f.ux * 120 + (s.rng.nextDouble() - 0.5) * 60;
      final ey = my + f.uy * 120 + (s.rng.nextDouble() - 0.5) * 60;
      s.fx.arc(mx, my, ex, ey);
    }
  }

  @override
  Map<String, dynamic> saveData() => {};

  @override
  void render(Canvas c, RenderCtx r) {
    inBox(c, body, () => GunArt.draw(c, def, darken, charred, on, _spin));
    if (r.selected) {
      c.drawPath(
          polyPath(body),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / r.zoom
            ..color = const Color(0xFFE53935));
    }
  }
}

/// Procedural gun art drawn in the gun's local frame (centred, +x = muzzle).
class GunArt {
  static void draw(Canvas c, GunDef d, Color Function(Color, double) dk, double charred, bool on, double spin) {
    final L = d.length, H = d.height;
    final hl = L / 2, hh = H / 2;
    final metal = dk(const Color(0xFF3A3F46), charred);
    final dark = dk(const Color(0xFF22252A), charred);
    final wood = dk(const Color(0xFF7A4B2A), charred);
    final light = dk(const Color(0xFF8A929C), charred);
    Color accent = const Color(0xFF8F2B2B);
    void box(double x0, double y0, double x1, double y1, Color col, [double rr = 1.5]) {
      rrect(c, x0, y0, x1 - x0, y1 - y0, rr, col, stroke: 1.2);
    }

    void grip(double x, Color col, {double w = 0.18, double slant = 0.12}) {
      final path = Path()
        ..moveTo(x, -hh * 0.1)
        ..lineTo(x + L * w, -hh * 0.1)
        ..lineTo(x + L * w - L * slant, hh)
        ..lineTo(x - L * slant, hh)
        ..close();
      c.drawPath(path, Paint()..color = col);
      c.drawPath(
          path,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    switch (d.style) {
      case GunStyle.pistol:
      case GunStyle.deagle:
      case GunStyle.dual:
      case GunStyle.flare:
        grip(-hl + L * 0.12, d.style == GunStyle.flare ? dk(const Color(0xFFE65100), charred) : dark, w: 0.32, slant: 0.1);
        box(-hl, -hh, hl, -hh + H * 0.45, d.style == GunStyle.flare ? dk(const Color(0xFFFF6D00), charred) : metal);
        if (d.style == GunStyle.dual) box(-hl * 0.1, -hh * 0.1, hl * 0.25, hh * 0.9, dark);
        if (d.style == GunStyle.flare) box(hl * 0.2, -hh * 1.05, hl, -hh * 0.05, dk(const Color(0xFFFF6D00), charred), 4);
        break;
      case GunStyle.revolver:
        grip(-hl + L * 0.05, wood, w: 0.28, slant: 0.14);
        box(-hl + L * 0.15, -hh, -hl + L * 0.5, -hh + H * 0.55, metal, 3);
        box(-hl + L * 0.45, -hh, hl, -hh + H * 0.28, metal);
        c.drawCircle(Offset(-hl + L * 0.32, -hh + H * 0.27), H * 0.18, Paint()..color = light);
        break;
      case GunStyle.smg:
      case GunStyle.uzi:
        box(-hl, -hh, hl - L * 0.1, -hh + H * 0.45, metal);
        box(hl - L * 0.1, -hh + H * 0.1, hl, -hh + H * 0.3, dark);
        box(-hl * 0.1, -hh * 0.1, hl * 0.12, hh, dark);
        grip(-hl + L * 0.2, dark, w: 0.18, slant: 0.08);
        if (d.style == GunStyle.smg) box(-hl - 2, -hh + 2, -hl + L * 0.12, -hh + H * 0.35, dark);
        break;
      case GunStyle.rifle:
      case GunStyle.carbine:
      case GunStyle.battle:
      case GunStyle.lmg:
        box(-hl, -hh, -hl + L * 0.25, hh * 0.6, d.style == GunStyle.battle ? wood : dark, 3);
        box(-hl + L * 0.22, -hh, hl - L * 0.25, -hh + H * 0.5, metal);
        box(hl - L * 0.26, -hh + H * 0.12, hl, -hh + H * 0.32, dark);
        grip(-hl + L * 0.3, dark, w: 0.08, slant: 0.05);
        if (d.style == GunStyle.lmg) {
          box(-hl + L * 0.42, -hh * 0.1, -hl + L * 0.6, hh, dk(const Color(0xFF4B5320), charred), 3);
          box(hl - L * 0.3, -hh * 1.2, hl - L * 0.24, -hh, dark);
        } else {
          final mag = Path()
            ..moveTo(-hl + L * 0.42, -hh + H * 0.5)
            ..lineTo(-hl + L * 0.5, -hh + H * 0.5)
            ..lineTo(-hl + L * 0.54, hh)
            ..lineTo(-hl + L * 0.46, hh)
            ..close();
          c.drawPath(mag, Paint()..color = dark);
        }
        box(-hl + L * 0.35, -hh - 4, -hl + L * 0.5, -hh, dark);
        break;
      case GunStyle.sniper:
      case GunStyle.antimat:
      case GunStyle.musket:
        final stock = d.style == GunStyle.antimat ? dark : wood;
        box(-hl, -hh * 0.6, -hl + L * 0.3, hh, stock, 3);
        box(-hl + L * 0.28, -hh * 0.6, hl, -hh * 0.6 + H * 0.35, d.style == GunStyle.musket ? wood : metal);
        box(-hl + L * 0.28, -hh * 0.55, hl, -hh * 0.55 + H * 0.2, metal);
        if (d.style != GunStyle.musket) {
          box(-hl + L * 0.3, -hh - 2, -hl + L * 0.55, -hh * 0.6, dark, 3);
          c.drawCircle(Offset(-hl + L * 0.55, -hh * 0.8 - 1), 2.5, Paint()..color = const Color(0xFF40C4FF));
        }
        grip(-hl + L * 0.3, stock, w: 0.06, slant: 0.04);
        if (d.style == GunStyle.antimat) box(hl - 8, -hh * 0.8, hl, -hh * 0.1, dark);
        break;
      case GunStyle.shotgun:
      case GunStyle.autoShotgun:
      case GunStyle.blunder:
        box(-hl, -hh * 0.5, -hl + L * 0.3, hh, wood, 3);
        box(-hl + L * 0.28, -hh, hl, -hh + H * 0.3, metal);
        box(-hl + L * 0.4, -hh + H * 0.3, hl - L * 0.1, -hh + H * 0.55, d.style == GunStyle.blunder ? metal : wood);
        if (d.style == GunStyle.autoShotgun) {
          c.drawCircle(Offset(-hl + L * 0.45, hh * 0.3), H * 0.35, Paint()..color = dark);
        }
        if (d.style == GunStyle.blunder) {
          final flare = Path()
            ..moveTo(hl - 10, -hh)
            ..lineTo(hl, -hh - 5)
            ..lineTo(hl, -hh + H * 0.3 + 5)
            ..lineTo(hl - 10, -hh + H * 0.3)
            ..close();
          c.drawPath(flare, Paint()..color = dk(const Color(0xFFB08D57), charred));
        }
        grip(-hl + L * 0.28, wood, w: 0.06, slant: 0.04);
        break;
      case GunStyle.minigun:
        box(-hl, -hh, -hl + L * 0.35, hh, metal, 4);
        c.save();
        final y0 = -hh * 0.6, y1 = hh * 0.6;
        for (var i = 0; i < 3; i++) {
          final ph = spin + i * math.pi * 2 / 3;
          final y = (y0 + y1) / 2 + math.sin(ph) * (y1 - y0) / 2;
          box(-hl + L * 0.3, y - 2.5, hl, y + 2.5, math.cos(ph) > 0 ? light : dark, 2);
        }
        c.restore();
        box(-hl + L * 0.15, hh * 0.3, -hl + L * 0.3, hh + 6, dark);
        accent = const Color(0xFFFFB300);
        box(-hl + 4, -hh + 4, -hl + 12, -hh + 10, accent);
        break;
      case GunStyle.launcher:
        box(-hl, -hh, hl, hh * 0.4, dk(const Color(0xFF4B5320), charred), 6);
        box(hl - 10, -hh - 2, hl, hh * 0.4 + 2, dark, 2);
        box(-hl * 0.2, hh * 0.4, -hl * 0.05, hh, dark);
        box(hl * 0.1, hh * 0.4, hl * 0.25, hh, dark);
        box(-hl * 0.1, -hh - 6, hl * 0.15, -hh, dark);
        break;
      case GunStyle.grenadeLauncher:
        box(-hl, -hh * 0.3, -hl + L * 0.3, hh * 0.7, dark, 3);
        c.drawCircle(Offset(-hl + L * 0.45, 0), hh * 0.9, Paint()..color = metal);
        c.drawCircle(Offset(-hl + L * 0.45, 0), hh * 0.9,
            Paint()
              ..style = PaintingStyle.stroke
              ..color = outline
              ..strokeWidth = 1.2);
        box(-hl + L * 0.55, -hh * 0.5, hl, hh * 0.3, metal, 4);
        grip(-hl + L * 0.3, dark, w: 0.08, slant: 0.04);
        break;
      case GunStyle.flamer:
        box(-hl, -hh * 0.3, -hl + L * 0.25, hh * 0.6, dark, 3);
        box(-hl + L * 0.2, -hh, hl - L * 0.15, -hh + H * 0.4, metal);
        box(hl - L * 0.15, -hh - 2, hl, -hh + H * 0.45, dark, 2);
        box(-hl + L * 0.35, -hh + H * 0.4, -hl + L * 0.6, hh, dk(const Color(0xFFB71C1C), charred), 5);
        if (on) c.drawCircle(Offset(hl + 2, -hh + H * 0.2), 3, Paint()..color = const Color(0xFF40C4FF));
        break;
      case GunStyle.laser:
      case GunStyle.plasma:
      case GunStyle.rail:
      case GunStyle.freeze:
      case GunStyle.tesla:
      case GunStyle.gravity:
      case GunStyle.medic:
        final glow = switch (d.style) {
          GunStyle.laser => const Color(0xFFFF1744),
          GunStyle.plasma => const Color(0xFFE040FB),
          GunStyle.rail => const Color(0xFF40C4FF),
          GunStyle.freeze => const Color(0xFF80D8FF),
          GunStyle.tesla => const Color(0xFF9FE7FF),
          GunStyle.gravity => const Color(0xFFFF9100),
          _ => const Color(0xFF69F0AE),
        };
        final shell = d.style == GunStyle.medic ? dk(const Color(0xFFEEEEEE), charred) : dk(const Color(0xFF2E3238), charred);
        box(-hl, -hh * 0.5, -hl + L * 0.28, hh * 0.6, shell, 4);
        box(-hl + L * 0.25, -hh, hl - L * 0.12, -hh + H * 0.6, shell, 4);
        box(-hl + L * 0.3, -hh + H * 0.18, hl - L * 0.16, -hh + H * 0.36, glow, 2);
        if (d.style == GunStyle.tesla) {
          for (var i = 0; i < 3; i++) {
            c.drawCircle(Offset(hl - L * 0.1 + i * 3.0, -hh + H * 0.3), 4.0 - i, Paint()..color = light);
          }
        } else if (d.style == GunStyle.gravity) {
          box(hl - L * 0.14, -hh - 3, hl, -hh + 4, light, 2);
          box(hl - L * 0.14, -hh + H * 0.5, hl, -hh + H * 0.5 + 7, light, 2);
        } else {
          box(hl - L * 0.14, -hh + H * 0.1, hl, -hh + H * 0.45, dark, 2);
        }
        grip(-hl + L * 0.32, dark, w: 0.1, slant: 0.05);
        if (d.style == GunStyle.medic) {
          final cp = Paint()..color = const Color(0xFFE53935);
          c.drawRect(Rect.fromCenter(center: Offset(-hl + L * 0.14, 0), width: 8, height: 2.6), cp);
          c.drawRect(Rect.fromCenter(center: Offset(-hl + L * 0.14, 0), width: 2.6, height: 8), cp);
        }
        if (on) {
          c.drawCircle(Offset(hl + 1, -hh + H * 0.27), 4, Paint()..color = glow.withValues(alpha: 0.7));
        }
        break;
      case GunStyle.crossbow:
        box(-hl, -2, hl - 6, 3, wood, 2);
        final bow = Paint()
          ..color = dark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        c.drawArc(Rect.fromCenter(center: Offset(hl - 14, 0), width: 16, height: H), -math.pi / 2, math.pi, false, bow);
        c.drawLine(Offset(hl - 14, -hh), Offset(-hl * 0.1, 0),
            Paint()
              ..color = const Color(0xFFDDDDDD)
              ..strokeWidth = 1);
        c.drawLine(Offset(hl - 14, hh), Offset(-hl * 0.1, 0),
            Paint()
              ..color = const Color(0xFFDDDDDD)
              ..strokeWidth = 1);
        grip(-hl + L * 0.2, wood, w: 0.1, slant: 0.05);
        break;
      case GunStyle.nail:
        box(-hl, -hh, hl - 6, -hh + H * 0.45, dk(const Color(0xFFFFC107), charred), 3);
        box(hl - 8, -hh + 3, hl, -hh + H * 0.35, dark);
        grip(-hl + L * 0.25, dark, w: 0.22, slant: 0.06);
        box(-hl + 2, -hh + H * 0.45, -hl + L * 0.2, -hh + H * 0.6, dark);
        break;
      case GunStyle.waterGun:
        box(-hl, -hh, hl - 6, -hh + H * 0.45, dk(const Color(0xFF29B6F6), charred), 5);
        box(hl - 8, -hh + 3, hl, -hh + H * 0.3, dk(const Color(0xFFFF7043), charred), 2);
        c.drawCircle(Offset(-hl * 0.2, -hh - 3), 8, Paint()..color = dk(const Color(0xFF4FC3F7), charred));
        grip(-hl + L * 0.25, dk(const Color(0xFFFF7043), charred), w: 0.2, slant: 0.08);
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Melee

enum MeleeStyle { knife, machete, sword, katana, axe, hammer, sledge, bat, crowbar, spear, mace, chainsaw, pan, shovel, scythe, wrench }

class MeleeDef {
  final String id, name, desc;
  final MeleeStyle style;
  final double length, width, mass, dmg;
  final bool sharp;
  const MeleeDef(this.id, this.name, this.desc,
      {required this.style, this.length = 60, this.width = 8, this.mass = 2, this.dmg = 1, this.sharp = false});
}

class Melees {
  static const List<MeleeDef> all = [
    MeleeDef('knife', 'Knife', 'Small and sharp.', style: MeleeStyle.knife, length: 32, width: 6, mass: 0.6, dmg: 1.0, sharp: true),
    MeleeDef('machete', 'Machete', 'Wide chopping blade.', style: MeleeStyle.machete, length: 62, width: 9, mass: 1.4, dmg: 1.3, sharp: true),
    MeleeDef('sword', 'Longsword', 'Double-edged blade.', style: MeleeStyle.sword, length: 100, width: 8, mass: 2.5, dmg: 1.5, sharp: true),
    MeleeDef('katana', 'Katana', 'Curved razor blade. Severs limbs.', style: MeleeStyle.katana, length: 96, width: 6, mass: 1.6, dmg: 2.0, sharp: true),
    MeleeDef('axe', 'Fire Axe', 'Heavy wedge on a pole.', style: MeleeStyle.axe, length: 80, width: 22, mass: 3, dmg: 1.7, sharp: true),
    MeleeDef('scythe', 'Scythe', 'Long reach, longer blade.', style: MeleeStyle.scythe, length: 130, width: 30, mass: 3.5, dmg: 1.8, sharp: true),
    MeleeDef('spear', 'Spear', 'Pointy reach weapon.', style: MeleeStyle.spear, length: 150, width: 6, mass: 2.5, dmg: 1.4, sharp: true),
    MeleeDef('hammer', 'Hammer', 'Carpenter\'s hammer.', style: MeleeStyle.hammer, length: 44, width: 16, mass: 1.2, dmg: 1.1),
    MeleeDef('sledge', 'Sledgehammer', 'Massive crushing blows.', style: MeleeStyle.sledge, length: 100, width: 24, mass: 8, dmg: 1.6),
    MeleeDef('bat', 'Baseball Bat', 'Classic home-run swing.', style: MeleeStyle.bat, length: 84, width: 9, mass: 1.6, dmg: 1.1),
    MeleeDef('crowbar', 'Crowbar', 'Hooked steel bar.', style: MeleeStyle.crowbar, length: 70, width: 8, mass: 2, dmg: 1.2),
    MeleeDef('mace', 'Mace', 'Spiked iron ball on a handle.', style: MeleeStyle.mace, length: 72, width: 22, mass: 4, dmg: 1.6),
    MeleeDef('pan', 'Frying Pan', 'Surprisingly effective.', style: MeleeStyle.pan, length: 56, width: 26, mass: 1.8, dmg: 1.0),
    MeleeDef('shovel', 'Shovel', 'Dig, smack, repeat.', style: MeleeStyle.shovel, length: 96, width: 18, mass: 2.2, dmg: 1.2),
    MeleeDef('wrench', 'Pipe Wrench', 'Heavy adjustable wrench.', style: MeleeStyle.wrench, length: 50, width: 14, mass: 2, dmg: 1.1),
    MeleeDef('chainsaw', 'Chainsaw', 'Activate to rev. Cuts anything it touches.', style: MeleeStyle.chainsaw, length: 80, width: 20, mass: 6, dmg: 1.0, sharp: true),
  ];

  static MeleeDef? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}

class Melee extends Entity with AimBody implements HeldItem {
  final MeleeDef def;
  @override
  Human? holder;
  double _sawTick = 0;
  double _hitCd = 0;

  Melee(this.def, double x, double y) : super(def.id, material: Mat.metal) {
    body = makeBox(x, y, def.length, def.width, def.mass * 0.9);
    final gx = -def.length * 0.38, gy = 0.0;
    final f = BoxFrame()..from(body);
    grip = addP(f.wx(gx, gy), f.wy(gx, gy), def.mass * 0.1);
    for (final p in body) {
      addStick(grip, p);
    }
    addPoly(body, friction: 0.5);
    captureRest(gx, gy);
  }

  @override
  int get gripIndex => particles.indexOf(grip);

  @override
  String get name => def.name;

  @override
  void use() {
    if (def.style == MeleeStyle.chainsaw) {
      activated = !activated;
      if (activated) Sfx.play('saw', vol: 0.6);
    } else {
      // a quick jab forward
      final f = BoxFrame()..from(body);
      final dv = 900 * stepDt;
      for (final p in particles) {
        p.kick(f.ux * dv, f.uy * dv);
      }
    }
  }

  @override
  void preStep(double dt) {
    if (aimTimer > 0) applyAim(dt);
  }

  @override
  void update(double dt) {
    if (holder != null && (holder!.removed || !identical(holder!.held, this))) holder = null;
    if (aimTimer > 0) aimTimer -= dt;
    if (playerAimT > 0) playerAimT -= dt;
    _hitCd -= dt;
    if (def.style == MeleeStyle.chainsaw && on) {
      _sawTick -= dt;
      if (_sawTick <= 0) {
        _sawTick = 0.08;
        final f = BoxFrame()..from(body);
        for (var k = 0; k < 4; k++) {
          final lx = def.length * (0.0 + k * 0.15);
          final x = f.wx(lx, 0), y = f.wy(lx, 0);
          for (final sh in sb.world.shapesInRadius(x, y, def.width * 0.7)) {
            final o = sh.owner;
            if (o is! Entity || identical(o, this) || identical(o, holder)) continue;
            o.receiveHit(Hit(x, y, f.vx, f.vy, 9, 300, DmgType.sharp, shape: sh, source: this));
            sb.fx.sparks(x, y, -f.vx, -f.vy, 1);
          }
        }
        if (sb.rng.nextDouble() < 0.3) Sfx.play('saw', vol: 0.35, rate: 1 + sb.rng.nextDouble() * 0.2);
      }
    }
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    final o = other.owner;
    if (o is! Entity || identical(o, holder) || _hitCd > 0) return;
    if (speed < 220) return;
    _hitCd = 0.12;
    final dmg = (speed / 30) * def.dmg * (0.6 + def.mass * 0.15);
    o.receiveHit(Hit(imp.x, imp.y, -imp.nx, -imp.ny, dmg, speed * def.mass * 0.6,
        def.sharp ? DmgType.sharp : DmgType.blunt,
        shape: other, source: this));
    if (o is! Human && def.style == MeleeStyle.pan) Sfx.play('clang', vol: 0.8, rate: 1.4);
  }

  @override
  void render(Canvas c, RenderCtx r) {
    inBox(c, body, () => _art(c));
    if (r.selected) {
      c.drawPath(
          polyPath(body),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 / r.zoom
            ..color = const Color(0xFFE53935));
    }
  }

  void _art(Canvas c) {
    final L = def.length, W = def.width;
    final hl = L / 2, hw = W / 2;
    final steel = darken(const Color(0xFFC9CED6), charred);
    final dark = darken(const Color(0xFF2A2D33), charred);
    final wood = darken(const Color(0xFF8B5A2B), charred);
    void bx(double x0, double y0, double x1, double y1, Color col, [double r = 1.5]) =>
        rrect(c, x0, y0, x1 - x0, y1 - y0, r, col, stroke: 1.1);
    switch (def.style) {
      case MeleeStyle.knife:
      case MeleeStyle.machete:
      case MeleeStyle.sword:
      case MeleeStyle.katana:
        final handle = def.style == MeleeStyle.katana ? 0.28 : 0.3;
        bx(-hl, -hw * 0.5, -hl + L * handle, hw * 0.5, def.style == MeleeStyle.katana ? dark : wood, 2);
        final blade = Path()
          ..moveTo(-hl + L * handle, -hw)
          ..lineTo(hl - W, -hw)
          ..lineTo(hl, def.style == MeleeStyle.katana ? -hw : 0)
          ..lineTo(hl - W * 0.3, hw * 0.6)
          ..lineTo(-hl + L * handle, hw * 0.6)
          ..close();
        c.drawPath(blade, Paint()..color = steel);
        c.drawPath(
            blade,
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1);
        if (def.style == MeleeStyle.sword) bx(-hl + L * handle - 3, -hw * 2, -hl + L * handle + 3, hw * 2, dark);
        break;
      case MeleeStyle.axe:
      case MeleeStyle.scythe:
        bx(-hl, -2.5, hl, 2.5, wood);
        final head = Path();
        if (def.style == MeleeStyle.axe) {
          head
            ..moveTo(hl - 18, -3)
            ..lineTo(hl - 4, -hw)
            ..lineTo(hl, -hw)
            ..lineTo(hl, hw)
            ..lineTo(hl - 4, hw)
            ..lineTo(hl - 18, 3)
            ..close();
          c.drawPath(head, Paint()..color = darken(const Color(0xFFC62828), charred));
        } else {
          head
            ..moveTo(hl - 4, -2)
            ..quadraticBezierTo(hl - 20, -hw * 1.1, hl - 70, -hw * 0.9)
            ..quadraticBezierTo(hl - 25, -hw * 0.5, hl - 4, 2)
            ..close();
          c.drawPath(head, Paint()..color = steel);
        }
        c.drawPath(
            head,
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1);
        break;
      case MeleeStyle.spear:
        bx(-hl, -2.5, hl - 18, 2.5, wood);
        final tip = Path()
          ..moveTo(hl - 20, -hw)
          ..lineTo(hl, 0)
          ..lineTo(hl - 20, hw)
          ..close();
        c.drawPath(tip, Paint()..color = steel);
        break;
      case MeleeStyle.hammer:
      case MeleeStyle.sledge:
        bx(-hl, -2.5, hl - 8, 2.5, wood);
        bx(hl - 14, -hw, hl, hw, dark, 2);
        break;
      case MeleeStyle.bat:
        final bat = Path()
          ..moveTo(-hl, -2)
          ..lineTo(hl * 0.1, -hw * 0.6)
          ..lineTo(hl, -hw)
          ..lineTo(hl, hw)
          ..lineTo(hl * 0.1, hw * 0.6)
          ..lineTo(-hl, 2)
          ..close();
        c.drawPath(bat, Paint()..color = darken(const Color(0xFFD7B47A), charred));
        c.drawPath(
            bat,
            Paint()
              ..color = outline
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1);
        break;
      case MeleeStyle.crowbar:
        bx(-hl + 6, -2, hl, 2, darken(const Color(0xFFC62828), charred));
        bx(-hl, -hw, -hl + 6, 0, darken(const Color(0xFFC62828), charred));
        break;
      case MeleeStyle.mace:
        bx(-hl, -2.5, hl - 14, 2.5, wood);
        c.drawCircle(Offset(hl - hw, 0), hw * 0.75, Paint()..color = dark);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          c.drawLine(Offset(hl - hw + math.cos(a) * hw * 0.6, math.sin(a) * hw * 0.6),
              Offset(hl - hw + math.cos(a) * hw, math.sin(a) * hw),
              Paint()
                ..color = steel
                ..strokeWidth = 2);
        }
        break;
      case MeleeStyle.pan:
        bx(-hl, -2.5, -hl + L * 0.5, 2.5, dark);
        c.drawOval(Rect.fromLTRB(-hl + L * 0.45, -hw, hl, hw), Paint()..color = dark);
        c.drawOval(Rect.fromLTRB(-hl + L * 0.5, -hw * 0.75, hl - 4, hw * 0.75), Paint()..color = const Color(0xFF3C4148));
        break;
      case MeleeStyle.shovel:
        bx(-hl, -2.5, hl - 24, 2.5, wood);
        bx(hl - 26, -hw, hl, hw, steel, 5);
        break;
      case MeleeStyle.wrench:
        bx(-hl, -3, hl - 10, 3, darken(const Color(0xFFC62828), charred));
        bx(hl - 14, -hw, hl, -hw * 0.2, dark);
        bx(hl - 14, hw * 0.2, hl - 4, hw, dark);
        break;
      case MeleeStyle.chainsaw:
        bx(-hl, -hw, -hl + L * 0.4, hw, darken(const Color(0xFFFF6F00), charred), 4);
        bx(-hl + L * 0.38, -hw * 0.5, hl, hw * 0.5, steel, hw * 0.5);
        final tp = Paint()..color = dark;
        final double off = on ? (DateTime.now().millisecondsSinceEpoch / 20) % 6 : 0.0;
        for (var x = -hl + L * 0.4 + off; x < hl - 4; x += 6) {
          c.drawRect(Rect.fromLTWH(x, -hw * 0.6, 3, 2), tp);
          c.drawRect(Rect.fromLTWH(x, hw * 0.6 - 2, 3, 2), tp);
        }
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Projectiles

enum MissileKind { rocket, grenade, bolt, nail, flare, plasma }

class Missile extends Entity {
  final MissileKind kind;
  late List<Particle> body;
  double life = 8;
  double damageValue = 40;
  bool done = false;
  double w, h;

  Missile(this.kind, double x, double y, double ang)
      : w = _dims(kind).width,
        h = _dims(kind).height,
        super('missile_${kind.name}', material: Mat.metal) {
    final mass = switch (kind) {
      MissileKind.rocket => 3.0,
      MissileKind.grenade => 1.2,
      MissileKind.bolt => 0.5,
      MissileKind.nail => 0.15,
      MissileKind.flare => 0.4,
      MissileKind.plasma => 0.5,
    };
    body = makeBox(x, y, w, h, mass, rot: ang);
    addPoly(body, friction: 0.4);
    if (kind == MissileKind.plasma || kind == MissileKind.rocket) {
      for (final p in particles) {
        p.gravityScale = kind == MissileKind.plasma ? 0 : 0.3;
      }
    }
    if (kind == MissileKind.flare) life = 12;
    if (kind == MissileKind.nail || kind == MissileKind.bolt) life = 25;
  }

  static Size _dims(MissileKind k) => switch (k) {
        MissileKind.rocket => const Size(34, 9),
        MissileKind.grenade => const Size(12, 10),
        MissileKind.bolt => const Size(40, 3),
        MissileKind.nail => const Size(18, 2),
        MissileKind.flare => const Size(10, 8),
        MissileKind.plasma => const Size(14, 14),
      };

  @override
  String get name => kind.name;

  @override
  bool get canBurn => false;

  void launch(double vx, double vy) {
    final dt = attached ? sb.world.prevDt : 1 / 120.0;
    for (final p in particles) {
      p.px = p.x - vx * dt;
      p.py = p.y - vy * dt;
    }
  }

  @override
  void update(double dt) {
    life -= dt;
    final f = BoxFrame()..from(body);
    switch (kind) {
      case MissileKind.rocket:
        for (final p in body) {
          p.ax += f.ux * 2200;
          p.ay += f.uy * 2200;
        }
        sb.fx.fire(f.wx(-w / 2, 0), f.wy(-w / 2, 0), 1, size: 5);
        if (sb.rng.nextDouble() < 0.6) sb.fx.smoke(f.wx(-w / 2, 0), f.wy(-w / 2, 0), 1, size: 6);
        break;
      case MissileKind.flare:
        sb.fx.fire(cx, cy, 1, size: 6);
        if (sb.rng.nextDouble() < 0.2) sb.fx.sparks(cx, cy, 0, -1, 1, color: const Color(0xFFFF5252));
        for (final sh in sb.world.shapesInRadius(cx, cy, 16)) {
          final o = sh.owner;
          if (o is Entity && !identical(o, this)) o.ignite(5);
        }
        break;
      case MissileKind.plasma:
        if (sb.rng.nextDouble() < 0.5) sb.fx.sparks(cx, cy, -f.ux, -f.uy, 1, color: const Color(0xFFE040FB));
        break;
      default:
        break;
    }
    if (life <= 0 && !done) {
      if (kind == MissileKind.rocket || kind == MissileKind.grenade || kind == MissileKind.plasma) {
        _boom();
      } else if (kind != MissileKind.nail && kind != MissileKind.bolt) {
        sb.removeEntity(this);
      }
    }
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    if (done) return;
    final o = other.owner;
    switch (kind) {
      case MissileKind.rocket:
      case MissileKind.grenade:
      case MissileKind.plasma:
        if (speed > 150) _boom();
        break;
      case MissileKind.bolt:
      case MissileKind.nail:
        if (speed < 400 || o is! Entity) return;
        done = true;
        o.receiveHit(Hit(imp.x, imp.y, -imp.nx, -imp.ny, damageValue, 300, DmgType.sharp, shape: other, source: this));
        // pin: weld the bolt to what it hit
        if (o.removed) return;
        final idx = sb.nearestParticleIndex(o, imp.x, imp.y);
        if (idx < 0) return;
        if (o.particles[idx].invMass == 0) {
          setFrozen(true);
        } else {
          sb.addJoint(JointType.nail, this, 0, o, idx, undoable: false);
          sb.addJoint(JointType.nail, this, 1, o, idx, undoable: false);
        }
        // nails also pin the hit object to whatever is behind it
        if (kind == MissileKind.nail || kind == MissileKind.bolt) {
          final f = BoxFrame()..from(body);
          final bx = imp.x + f.ux * 18, by = imp.y + f.uy * 18;
          final behind = sb.world.shapeAt(bx, by, pad: 4,
              filter: (s) => !identical(s.owner, this) && !identical(s.owner, o));
          if (behind != null) {
            final b = behind.owner;
            if (b is Entity) {
              final bi = sb.nearestParticleIndex(b, bx, by);
              if (bi >= 0) {
                if (b.particles[bi].invMass == 0) {
                  // pinned to the world
                  sb.addJoint(JointType.pin, o, idx, null, 0, anchorX: o.particles[idx].x, anchorY: o.particles[idx].y, undoable: false);
                } else {
                  sb.addJoint(JointType.nail, o, idx, b, bi, undoable: false);
                }
              }
            }
          }
        }
        Sfx.play('thud', vol: 0.5, rate: 1.6);
        break;
      default:
        break;
    }
  }

  void _boom() {
    if (done || !attached) return;
    done = true;
    final x = cx, y = cy;
    final s = sb;
    s.removeEntity(this);
    switch (kind) {
      case MissileKind.rocket:
        s.explode(x, y, 200, 3200, damage: 170, source: this);
        break;
      case MissileKind.grenade:
        s.explode(x, y, 150, 2600, damage: 120, source: this);
        break;
      case MissileKind.plasma:
        s.explode(x, y, 90, 1600, damage: 70, fire: true, source: this);
        s.fx.flash(x, y, 60, color: const Color(0xFFE040FB), life: 0.2);
        break;
      default:
        break;
    }
  }

  @override
  Map<String, dynamic> saveData() => {'life': life, 'done': done, 'dmg': damageValue};

  @override
  void loadData(Map<String, dynamic> d) {
    life = (d['life'] as num?)?.toDouble() ?? life;
    done = d['done'] == true;
    damageValue = (d['dmg'] as num?)?.toDouble() ?? damageValue;
  }

  @override
  void render(Canvas c, RenderCtx r) {
    inBox(c, body, () {
      final hw = w / 2, hh = h / 2;
      switch (kind) {
        case MissileKind.rocket:
          rrect(c, -hw, -hh, w - 8, h, 3, const Color(0xFF5D6B4A));
          final tip = Path()
            ..moveTo(hw - 8, -hh)
            ..lineTo(hw, 0)
            ..lineTo(hw - 8, hh)
            ..close();
          c.drawPath(tip, Paint()..color = const Color(0xFFB71C1C));
          break;
        case MissileKind.grenade:
          c.drawOval(Rect.fromLTRB(-hw, -hh, hw, hh), Paint()..color = outline);
          c.drawOval(Rect.fromLTRB(-hw + 1, -hh + 1, hw - 1, hh - 1), Paint()..color = const Color(0xFF8D9440));
          break;
        case MissileKind.bolt:
        case MissileKind.nail:
          c.drawRect(Rect.fromLTRB(-hw, -hh, hw, hh), Paint()..color = const Color(0xFF9EA4AB));
          if (kind == MissileKind.bolt) {
            c.drawRect(Rect.fromLTRB(-hw, -hh - 2, -hw + 6, hh + 2), Paint()..color = const Color(0xFFE53935));
          } else {
            c.drawRect(Rect.fromLTRB(-hw, -hh - 1.5, -hw + 2, hh + 1.5), Paint()..color = const Color(0xFF9EA4AB));
          }
          break;
        case MissileKind.flare:
          c.drawCircle(Offset.zero, 7, Paint()..color = const Color(0x66FF5252));
          c.drawCircle(Offset.zero, 4, Paint()..color = const Color(0xFFFFCDD2));
          break;
        case MissileKind.plasma:
          c.drawCircle(Offset.zero, 10, Paint()..color = const Color(0x55E040FB));
          c.drawCircle(Offset.zero, 6, Paint()..color = const Color(0xFFF3C5FF));
          break;
      }
    });
  }
}
