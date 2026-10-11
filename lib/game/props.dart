import 'dart:math' as math;
import 'dart:ui';

import '../core/sfx.dart';
import '../engine/physics.dart';
import 'entity.dart';
import 'sandbox.dart';

enum PropShape { box, wheel }

enum PropStyle {
  crate, plank, beam, brick, glass, barrel, metalBox, ball, tire, pumpkin, fridge,
  boulder, block, girder, door, tv, sofa, cone, anvil, bowling, beachball, frag, ice, pallet, dumbbell
}

class PropDef {
  final String id;
  final String name;
  final PropShape shape;
  final double w, h; // box size or wheel diameter in w
  final double mass;
  final Mat mat;
  final Color? color;
  final double hp; // infinite when <= 0
  final PropStyle style;
  final double restitution;
  final double gravityScale;
  const PropDef(this.id, this.name,
      {this.shape = PropShape.box,
      this.w = 40,
      this.h = 40,
      this.mass = 20,
      this.mat = Mat.wood,
      this.color,
      this.hp = 0,
      this.style = PropStyle.crate,
      this.restitution = 0,
      this.gravityScale = 1});
}

class Props {
  static const List<PropDef> all = [
    PropDef('crate', 'Wooden Crate', w: 50, h: 50, mass: 20, hp: 90, style: PropStyle.crate),
    PropDef('crate_big', 'Big Crate', w: 90, h: 90, mass: 55, hp: 160, style: PropStyle.crate),
    PropDef('plank', 'Plank', w: 160, h: 12, mass: 8, hp: 60, style: PropStyle.plank),
    PropDef('long_plank', 'Long Plank', w: 320, h: 14, mass: 16, hp: 90, style: PropStyle.plank),
    PropDef('pallet', 'Pallet', w: 110, h: 16, mass: 12, hp: 70, style: PropStyle.pallet),
    PropDef('beam', 'Steel Beam', w: 260, h: 18, mass: 60, mat: Mat.metal, style: PropStyle.beam),
    PropDef('girder', 'Girder', w: 420, h: 26, mass: 140, mat: Mat.metal, style: PropStyle.girder),
    PropDef('brick', 'Brick', w: 30, h: 15, mass: 6, mat: Mat.stone, hp: 60, style: PropStyle.brick),
    PropDef('cinder', 'Concrete Block', w: 60, h: 40, mass: 40, mat: Mat.stone, hp: 200, style: PropStyle.block),
    PropDef('glass', 'Glass Pane', w: 14, h: 120, mass: 8, mat: Mat.glass, hp: 12, style: PropStyle.glass),
    PropDef('window', 'Window', w: 120, h: 90, mass: 14, mat: Mat.glass, hp: 15, style: PropStyle.glass),
    PropDef('metal_box', 'Metal Box', w: 50, h: 50, mass: 45, mat: Mat.metal, style: PropStyle.metalBox),
    PropDef('fridge', 'Fridge', w: 60, h: 130, mass: 80, mat: Mat.metal, style: PropStyle.fridge),
    PropDef('tv', 'Old TV', w: 60, h: 48, mass: 22, mat: Mat.plastic, hp: 40, style: PropStyle.tv),
    PropDef('sofa', 'Sofa', w: 150, h: 55, mass: 45, mat: Mat.wood, hp: 120, style: PropStyle.sofa),
    PropDef('door', 'Door', w: 12, h: 170, mass: 25, hp: 100, style: PropStyle.door),
    PropDef('anvil', 'Anvil', w: 60, h: 36, mass: 200, mat: Mat.metal, style: PropStyle.anvil),
    PropDef('dumbbell', 'Dumbbell', w: 70, h: 18, mass: 40, mat: Mat.metal, style: PropStyle.dumbbell),
    PropDef('cone', 'Traffic Cone', w: 28, h: 40, mass: 3, mat: Mat.rubber, style: PropStyle.cone),
    PropDef('ice_block', 'Ice Block', w: 60, h: 60, mass: 30, mat: Mat.ice, hp: 50, style: PropStyle.ice),
    PropDef('ball', 'Rubber Ball', shape: PropShape.wheel, w: 34, mass: 3, mat: Mat.rubber,
        color: Color(0xFFE53935), style: PropStyle.ball, restitution: 0.7),
    PropDef('beachball', 'Beach Ball', shape: PropShape.wheel, w: 60, mass: 1, mat: Mat.plastic,
        style: PropStyle.beachball, restitution: 0.6),
    PropDef('bowling', 'Bowling Ball', shape: PropShape.wheel, w: 30, mass: 30, mat: Mat.stone,
        style: PropStyle.bowling),
    PropDef('tire', 'Tire', shape: PropShape.wheel, w: 64, mass: 12, mat: Mat.rubber, style: PropStyle.tire,
        restitution: 0.3),
    PropDef('boulder', 'Boulder', shape: PropShape.wheel, w: 110, mass: 250, mat: Mat.stone, style: PropStyle.boulder),
    PropDef('pumpkin', 'Pumpkin', shape: PropShape.wheel, w: 42, mass: 6, mat: Mat.flesh, hp: 25,
        style: PropStyle.pumpkin),
  ];

  static PropDef? byId(String id) {
    for (final d in all) {
      if (d.id == id) return d;
    }
    return null;
  }
}

/// A generic rigid object: crates, planks, balls, glass...
class Prop extends Entity {
  PropDef def;
  late List<Particle> body;
  late Shape shape;
  double w, h;
  Color? colorOverride;

  Prop(this.def, double x, double y, {String? defId, double rot = 0, double? w, double? h, Color? color})
      : w = w ?? def.w,
        h = h ?? def.h,
        colorOverride = color,
        super(defId ?? def.id, material: def.mat) {
    if (def.hp > 0) {
      hp = def.hp;
      maxHp = def.hp;
    }
    if (def.shape == PropShape.wheel) {
      final r = this.w / 2;
      final sides = r > 40 ? 14 : 10;
      final ps = makeWheel(x, y, r, def.mass, sides);
      body = ps.sublist(1);
      shape = addPoly(body, restitution: def.restitution);
    } else {
      body = makeBox(x, y, this.w, this.h, def.mass, rot: rot);
      shape = addPoly(body, restitution: def.restitution);
    }
    for (final p in particles) {
      p.gravityScale = def.gravityScale;
    }
  }

  Color get baseColor => colorOverride ?? def.color ?? matInfo[def.mat]!.color;

  @override
  String get name => def.name;

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    if (!hp.isFinite) return;
    final th = def.mat == Mat.glass ? 380.0 : (def.mat == Mat.ice ? 600.0 : 900.0);
    if (speed > th) damage((speed - th) / (def.mat == Mat.glass ? 10 : 25), DmgType.blunt);
  }

  @override
  void receiveHit(Hit h) {
    super.receiveHit(h);
    if (def.style == PropStyle.pumpkin && h.type == DmgType.bullet && attached) {
      sb.fx.blood(h.x, h.y, h.dx, h.dy, 6, const Color(0xFFF08A24));
    }
  }

  @override
  void destroy() {
    if (removed || !attached) return;
    final s = sb;
    final c = baseColor;
    final vx0 = vx, vy0 = vy;
    if (def.mat == Mat.glass || def.mat == Mat.ice) {
      s.fx.glass(cx, cy, 24);
      Sfx.play('glass', vol: 0.9);
    } else {
      s.fx.debris(cx, cy, 10, c, speed: 300, size: 5);
      Sfx.play(matInfo[def.mat]!.impactSound, vol: 0.8, rate: 0.7);
    }
    // split boxes into 4 fragments (only if large enough)
    if (def.shape == PropShape.box && w * h > 900 && w > 12 && h > 12) {
      final f = BoxFrame()..from(body);
      final ang = math.atan2(f.uy, f.ux);
      for (var i = 0; i < 4; i++) {
        final lx = (i % 2 == 0 ? -0.25 : 0.25) * w;
        final ly = (i < 2 ? -0.25 : 0.25) * h;
        final frag = Prop(fragDef(def), f.wx(lx, ly), f.wy(lx, ly),
            defId: 'frag', rot: ang, w: w / 2 - 1, h: h / 2 - 1, color: c)
          ..fragOf = def.id;
        frag.charred = charred;
        s.add(frag);
        for (final p in frag.particles) {
          p.px = p.x - vx0 - (s.rng.nextDouble() - 0.5) * 2;
          p.py = p.y - vy0 - (s.rng.nextDouble() - 0.5) * 2;
        }
      }
    } else if (def.style == PropStyle.pumpkin) {
      s.fx.blood(cx, cy, 0, -1, 25, const Color(0xFFF08A24), speed: 350);
    }
    s.removeEntity(this);
  }

  String? fragOf;

  static PropDef fragDef(PropDef parent) => PropDef('frag', 'Debris',
      mass: parent.mass / 4,
      mat: parent.mat,
      hp: parent.mat == Mat.glass ? 0 : 30,
      style: PropStyle.frag,
      w: parent.w / 2,
      h: parent.h / 2);

  @override
  Map<String, dynamic> saveData() => {
        if (defId == 'frag') ...{
          'w': w,
          'h': h,
          'of': fragOf ?? 'crate',
          'c': baseColor.toARGB32(),
        }
      };

  @override
  void render(Canvas c, RenderCtx r) {
    final col = darken(baseColor, charred);
    if (def.shape == PropShape.wheel) {
      _renderWheel(c, col);
    } else {
      inBox(c, body, () => _renderBox(c, col));
    }
    if (r.selected) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 / r.zoom
        ..color = const Color(0xFFE53935);
      c.drawPath(polyPath(body), p);
    }
  }

  void _renderWheel(Canvas c, Color col) {
    final hub = particles[0];
    final rim = body[0];
    final ang = math.atan2(rim.y - hub.y, rim.x - hub.x);
    final r = w / 2;
    c.save();
    c.translate(hub.x, hub.y);
    c.rotate(ang);
    final o = Paint()..color = outline;
    c.drawCircle(Offset.zero, r + 1.5, o);
    final p = Paint()..color = col;
    switch (def.style) {
      case PropStyle.tire:
        c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF26262A));
        c.drawCircle(Offset.zero, r * 0.55, Paint()..color = const Color(0xFF9EA4AB));
        c.drawCircle(Offset.zero, r * 0.2, Paint()..color = const Color(0xFF555A60));
        final sp = Paint()
          ..color = const Color(0xFF555A60)
          ..strokeWidth = 3;
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          c.drawLine(Offset.zero, Offset(math.cos(a) * r * 0.5, math.sin(a) * r * 0.5), sp);
        }
        break;
      case PropStyle.beachball:
        const cols = [Color(0xFFE53935), Color(0xFFFFFFFF), Color(0xFF1E88E5), Color(0xFFFFEB3B)];
        for (var i = 0; i < 6; i++) {
          c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r), i * math.pi / 3, math.pi / 3, true,
              Paint()..color = cols[i % 4]);
        }
        break;
      case PropStyle.bowling:
        c.drawCircle(Offset.zero, r, Paint()..color = const Color(0xFF283593));
        final hp = Paint()..color = const Color(0xFF0D0D1A);
        c.drawCircle(Offset(r * 0.3, -r * 0.3), 2.5, hp);
        c.drawCircle(Offset(r * 0.5, -r * 0.05), 2.5, hp);
        c.drawCircle(Offset(r * 0.15, -r * 0.55), 2.5, hp);
        break;
      case PropStyle.pumpkin:
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 1.8),
            Paint()..color = darken(const Color(0xFFE67E22), charred));
        final lp = Paint()
          ..color = const Color(0xFFB85C10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        c.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 0.9, height: r * 1.8), lp);
        c.drawRect(Rect.fromLTWH(-2, -r - 6, 4, 8), Paint()..color = const Color(0xFF4E7D2A));
        break;
      case PropStyle.boulder:
        c.drawCircle(Offset.zero, r, p);
        final spot = Paint()..color = darken(col, 0.3);
        c.drawCircle(Offset(-r * 0.3, -r * 0.2), r * 0.2, spot);
        c.drawCircle(Offset(r * 0.35, r * 0.25), r * 0.15, spot);
        break;
      default:
        c.drawCircle(Offset.zero, r, p);
        c.drawCircle(Offset(-r * 0.3, -r * 0.3), r * 0.25, Paint()..color = const Color(0x55FFFFFF));
    }
    c.restore();
  }

  void _renderBox(Canvas c, Color col) {
    final hw = w / 2, hh = h / 2;
    final rect = Rect.fromLTRB(-hw, -hh, hw, hh);
    final fill = Paint()..color = col;
    final line = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final detail = Paint()
      ..color = darken(col, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    switch (def.style) {
      case PropStyle.crate:
        c.drawRect(rect, fill);
        final inset = math.min(w, h) * 0.12;
        c.drawRect(rect.deflate(inset), detail);
        c.drawLine(Offset(-hw + inset, -hh + inset), Offset(hw - inset, hh - inset), detail);
        c.drawLine(Offset(-hw + inset, hh - inset), Offset(hw - inset, -hh + inset), detail);
        break;
      case PropStyle.plank:
      case PropStyle.door:
        c.drawRect(rect, fill);
        final gl = Paint()
          ..color = darken(col, 0.2)
          ..strokeWidth = 1;
        if (w > h) {
          c.drawLine(Offset(-hw + 6, -hh * 0.3), Offset(hw - 6, -hh * 0.3), gl);
          c.drawLine(Offset(-hw + 20, hh * 0.35), Offset(hw - 30, hh * 0.35), gl);
        } else {
          c.drawRect(Rect.fromLTRB(-hw + 2, -hh + 10, hw - 2, -hh * 0.1), detail);
          c.drawRect(Rect.fromLTRB(-hw + 2, hh * 0.1, hw - 2, hh - 10), detail);
          c.drawCircle(Offset(0, 0), 2.5, Paint()..color = const Color(0xFFD4A537));
        }
        break;
      case PropStyle.pallet:
        for (var i = 0; i < 5; i++) {
          final x = -hw + i * w / 4.0 - (i == 4 ? 12 : 0);
          c.drawRect(Rect.fromLTWH(x, -hh, 12, h), fill);
        }
        c.drawRect(Rect.fromLTRB(-hw, -hh, hw, -hh + 4), fill);
        c.drawRect(Rect.fromLTRB(-hw, hh - 4, hw, hh), fill);
        break;
      case PropStyle.beam:
      case PropStyle.girder:
        c.drawRect(rect, fill);
        final lp = Paint()..color = darken(col, 0.25);
        c.drawRect(Rect.fromLTRB(-hw, -hh, hw, -hh + h * 0.22), lp);
        c.drawRect(Rect.fromLTRB(-hw, hh - h * 0.22, hw, hh), lp);
        if (def.style == PropStyle.girder) {
          final zp = Paint()
            ..color = darken(col, 0.3)
            ..strokeWidth = 2.5;
          for (var x = -hw; x < hw - h; x += h) {
            c.drawLine(Offset(x, hh - h * 0.22), Offset(x + h * 0.5, -hh + h * 0.22), zp);
            c.drawLine(Offset(x + h * 0.5, -hh + h * 0.22), Offset(x + h, hh - h * 0.22), zp);
          }
        }
        final bp = Paint()..color = darken(col, 0.5);
        for (var x = -hw + 8; x < hw; x += 40) {
          c.drawCircle(Offset(x, 0), 1.6, bp);
        }
        break;
      case PropStyle.brick:
      case PropStyle.block:
        c.drawRect(rect, fill);
        if (def.style == PropStyle.block) {
          c.drawRect(Rect.fromLTRB(-hw * 0.7, -hh * 0.6, -hw * 0.1, hh * 0.6), Paint()..color = darken(col, 0.3));
          c.drawRect(Rect.fromLTRB(hw * 0.1, -hh * 0.6, hw * 0.7, hh * 0.6), Paint()..color = darken(col, 0.3));
        } else {
          c.drawRect(rect.deflate(2), Paint()..color = darken(const Color(0xFFA0482E), charred));
        }
        break;
      case PropStyle.glass:
      case PropStyle.ice:
        c.drawRect(rect, fill);
        final hl = Paint()
          ..color = const Color(0x88FFFFFF)
          ..strokeWidth = 2;
        c.drawLine(Offset(-hw * 0.5, -hh * 0.8), Offset(hw * 0.2, -hh * 0.2), hl);
        c.drawLine(Offset(-hw * 0.1, -hh * 0.8), Offset(hw * 0.5, -hh * 0.35), hl);
        if (hp < maxHp && maxHp.isFinite) {
          final cp = Paint()
            ..color = const Color(0xCCFFFFFF)
            ..strokeWidth = 1;
          final k = 1 - hp / maxHp;
          c.drawLine(Offset(0, 0), Offset(hw * k, -hh * 0.6 * k), cp);
          c.drawLine(Offset(0, 0), Offset(-hw * 0.8 * k, hh * 0.4 * k), cp);
          c.drawLine(Offset(0, 0), Offset(hw * 0.3 * k, hh * 0.8 * k), cp);
        }
        break;
      case PropStyle.barrel:
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), fill);
        break;
      case PropStyle.metalBox:
        c.drawRect(rect, fill);
        c.drawRect(rect.deflate(5), detail);
        final rp = Paint()..color = darken(col, 0.5);
        for (final o in [Offset(-hw + 3, -hh + 3), Offset(hw - 3, -hh + 3), Offset(hw - 3, hh - 3), Offset(-hw + 3, hh - 3)]) {
          c.drawCircle(o, 1.6, rp);
        }
        break;
      case PropStyle.fridge:
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), Paint()..color = darken(const Color(0xFFE8ECEF), charred));
        c.drawLine(Offset(-hw, -hh * 0.3), Offset(hw, -hh * 0.3), detail);
        c.drawRect(Rect.fromLTWH(hw - 10, -hh * 0.8, 4, 22), Paint()..color = const Color(0xFF8A929C));
        c.drawRect(Rect.fromLTWH(hw - 10, -hh * 0.15, 4, 30), Paint()..color = const Color(0xFF8A929C));
        break;
      case PropStyle.tv:
        c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), Paint()..color = darken(const Color(0xFF5D4037), charred));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw + 6, -hh + 6, hw * 0.45, hh - 6), const Radius.circular(8)),
            Paint()..color = hp < maxHp * 0.5 ? const Color(0xFF111111) : const Color(0xFF3E5F6B));
        c.drawCircle(Offset(hw * 0.7, -hh * 0.3), 3, Paint()..color = const Color(0xFF222222));
        c.drawCircle(Offset(hw * 0.7, hh * 0.1), 3, Paint()..color = const Color(0xFF222222));
        break;
      case PropStyle.sofa:
        final sc = darken(const Color(0xFF8E3B46), charred);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh * 0.2, hw, hh), const Radius.circular(8)), Paint()..color = sc);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw + 12, -hh, hw - 12, hh * 0.1), const Radius.circular(8)),
            Paint()..color = darken(sc, 0.15));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh * 0.5, -hw + 16, hh), const Radius.circular(6)),
            Paint()..color = darken(sc, 0.25));
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(hw - 16, -hh * 0.5, hw, hh), const Radius.circular(6)),
            Paint()..color = darken(sc, 0.25));
        break;
      case PropStyle.anvil:
        final anvil = Path()
          ..moveTo(-hw, -hh)
          ..lineTo(hw, -hh)
          ..lineTo(hw * 0.6, -hh * 0.2)
          ..lineTo(hw * 0.3, -hh * 0.2)
          ..lineTo(hw * 0.4, hh)
          ..lineTo(-hw * 0.4, hh)
          ..lineTo(-hw * 0.3, -hh * 0.2)
          ..lineTo(-hw * 0.8, -hh * 0.3)
          ..close();
        c.drawPath(anvil, Paint()..color = darken(const Color(0xFF3C4148), charred));
        c.drawPath(anvil, line);
        return;
      case PropStyle.dumbbell:
        final bar = Paint()..color = const Color(0xFF9EA4AB);
        c.drawRect(Rect.fromLTRB(-hw, -3, hw, 3), bar);
        final wp = Paint()..color = const Color(0xFF26262A);
        c.drawRect(Rect.fromLTRB(-hw, -hh, -hw + 16, hh), wp);
        c.drawRect(Rect.fromLTRB(hw - 16, -hh, hw, hh), wp);
        return;
      case PropStyle.cone:
        final path = Path()
          ..moveTo(-hw, hh)
          ..lineTo(-3, -hh)
          ..lineTo(3, -hh)
          ..lineTo(hw, hh)
          ..close();
        c.drawPath(path, Paint()..color = darken(const Color(0xFFFF6D00), charred));
        c.drawLine(Offset(-hw * 0.55, 0), Offset(hw * 0.55, 0),
            Paint()
              ..color = const Color(0xFFFFFFFF)
              ..strokeWidth = 5);
        c.drawPath(path, line);
        return;
      default:
        c.drawRect(rect, fill);
    }
    c.drawRect(rect, line);
  }
}

// ---------------------------------------------------------------------------
// Explosives

enum BombKind { grenade, dynamite, c4, mine, nuke, molotov, barrel, gas, sticky, firework, cluster, holy }

class Bomb extends Entity {
  final BombKind kind;
  late List<Particle> body;
  double w, h;
  double fuse = -1; // seconds until detonation, -1 = not lit
  bool exploded = false;
  bool armed = false;
  double _beep = 0;
  final String label;

  Bomb(this.kind, double x, double y, String defId, this.label) :
        w = _size(kind).width,
        h = _size(kind).height,
        super(defId, material: kind == BombKind.barrel || kind == BombKind.gas ? Mat.explosive : Mat.metal) {
    final mass = switch (kind) {
      BombKind.barrel => 40.0,
      BombKind.nuke => 300.0,
      BombKind.gas => 15.0,
      BombKind.mine => 8.0,
      _ => 4.0,
    };
    body = makeBox(x, y, w, h, mass);
    addPoly(body, friction: kind == BombKind.sticky ? 3.0 : -1);
    hp = kind == BombKind.barrel || kind == BombKind.gas ? 40 : 60;
    maxHp = hp;
    if (kind == BombKind.mine) armed = true;
  }

  static Size _size(BombKind k) => switch (k) {
        BombKind.grenade => const Size(16, 20),
        BombKind.dynamite => const Size(36, 10),
        BombKind.c4 => const Size(34, 20),
        BombKind.mine => const Size(40, 10),
        BombKind.nuke => const Size(160, 60),
        BombKind.molotov => const Size(12, 34),
        BombKind.barrel => const Size(44, 64),
        BombKind.gas => const Size(22, 56),
        BombKind.sticky => const Size(20, 14),
        BombKind.firework => const Size(10, 46),
        BombKind.cluster => const Size(22, 22),
        BombKind.holy => const Size(20, 24),
      };

  @override
  String get name => label;

  @override
  bool get canBurn => kind != BombKind.nuke;

  @override
  void use() {
    switch (kind) {
      case BombKind.grenade:
      case BombKind.cluster:
      case BombKind.holy:
        if (fuse < 0) {
          fuse = kind == BombKind.holy ? 3.0 : 3.0;
          Sfx.play('click', vol: 0.6);
        }
        break;
      case BombKind.dynamite:
      case BombKind.firework:
        if (fuse < 0) fuse = kind == BombKind.firework ? 1.5 : 4.0;
        break;
      case BombKind.c4:
      case BombKind.nuke:
      case BombKind.barrel:
      case BombKind.gas:
        detonate();
        break;
      case BombKind.sticky:
        if (fuse < 0) fuse = 2.5;
        break;
      case BombKind.mine:
        armed = !armed;
        break;
      case BombKind.molotov:
        detonate();
        break;
    }
  }

  @override
  void onPowerChanged(bool now) {
    if (now) {
      if (kind == BombKind.mine) {
        detonate();
      } else {
        use();
      }
    }
  }

  @override
  void ignite([double seconds = 6]) {
    if (kind == BombKind.dynamite || kind == BombKind.firework) {
      if (fuse < 0) fuse = kind == BombKind.firework ? 1.0 : 2.5;
      return;
    }
    if (kind == BombKind.barrel || kind == BombKind.gas) {
      super.ignite(seconds);
      if (fuse < 0) fuse = 2.0 + (attached ? sb.rng.nextDouble() * 2 : 0);
    }
  }

  @override
  void damage(double amount, DmgType type) {
    hp -= amount;
    if (hp <= 0) detonate();
  }

  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    final o = other.owner;
    if (kind == BombKind.mine && armed && speed > 120) {
      detonate();
      return;
    }
    if (kind == BombKind.molotov && speed > 450) {
      detonate();
      return;
    }
    if (kind == BombKind.sticky && o is Entity && fuse >= 0 && attached) {
      // stick to whatever we hit
      if (!_stuck) {
        _stuck = true;
        final idx = sb.nearestParticleIndex(o, imp.x, imp.y);
        if (idx >= 0 && o.particles[idx].invMass > 0) {
          sb.addJoint(JointType.nail, this, 0, o, idx, undoable: false);
        } else {
          setFrozen(true);
        }
      }
      return;
    }
    if (speed > 1600 && (kind == BombKind.barrel || kind == BombKind.gas)) {
      damage((speed - 1600) / 15, DmgType.blunt);
    }
  }

  bool _stuck = false;

  @override
  void update(double dt) {
    if (exploded) return;
    if (kind == BombKind.firework && fuse >= 0) {
      // rocket upward along its long axis
      final f = BoxFrame()..from(body);
      final dirx = -f.vx, diry = -f.vy; // top of the firework
      for (final p in body) {
        p.ax += dirx * 2600;
        p.ay += diry * 2600;
      }
      if (attached) sb.fx.sparks(f.wx(0, h / 2), f.wy(0, h / 2), -dirx, -diry, 2);
    }
    if (kind == BombKind.mine && armed) {
      _beep -= dt;
      if (_beep <= 0) _beep = 1.2;
    }
    if (fuse >= 0) {
      fuse -= dt;
      if ((kind == BombKind.dynamite || kind == BombKind.firework) && attached) {
        final f = BoxFrame()..from(body);
        sb.fx.sparks(f.wx(w / 2, 0), f.wy(w / 2, 0), 0, -1, 1);
      }
      if (fuse <= 0) detonate();
    }
  }

  void detonate() {
    if (exploded || !attached) return;
    exploded = true;
    final s = sb;
    final x = cx, y = cy;
    s.removeEntity(this);
    switch (kind) {
      case BombKind.grenade:
        s.explode(x, y, 170, 2600, damage: 140, source: this);
        for (var i = 0; i < 10; i++) {
          final a = s.rng.nextDouble() * math.pi * 2;
          s.fireBullet(x, y, math.cos(a), math.sin(a), damage: 18, force: 900, range: 260, tracer: false);
        }
        break;
      case BombKind.dynamite:
        s.explode(x, y, 220, 3200, damage: 180, source: this);
        break;
      case BombKind.c4:
        s.explode(x, y, 280, 4200, damage: 260, source: this);
        break;
      case BombKind.sticky:
        s.explode(x, y, 150, 2600, damage: 160, source: this);
        break;
      case BombKind.mine:
        s.explode(x, y - 10, 180, 3800, damage: 200, source: this);
        break;
      case BombKind.nuke:
        s.explode(x, y, 1400, 9000, damage: 2000, source: this);
        s.fx.explosion(x, y - 200, 900);
        s.fx.explosion(x, y - 500, 600);
        for (final e in List<Entity>.from(s.entities)) {
          if (!e.removed && (e.cx - x).abs() < 2200) e.ignite(8);
        }
        break;
      case BombKind.molotov:
        s.fx.glass(x, y, 10);
        Sfx.play('glass', vol: 0.8);
        Sfx.play('flame', vol: 0.8);
        for (var i = 0; i < 40; i++) {
          final a = -math.pi / 2 + (s.rng.nextDouble() - 0.5) * 2.6;
          final sp = 100 + s.rng.nextDouble() * 300;
          s.shootFlame(x, y, math.cos(a) * sp, math.sin(a) * sp * 0.5, null);
        }
        for (final e in List<Entity>.from(s.entities)) {
          if (e.removed) continue;
          for (final sh in e.shapes) {
            if (sh.distanceTo(x, y) < 110) {
              e.ignite(8);
              break;
            }
          }
        }
        break;
      case BombKind.barrel:
        s.explode(x, y, 240, 3400, damage: 170, source: this);
        break;
      case BombKind.gas:
        s.explode(x, y, 180, 3000, damage: 130, source: this);
        break;
      case BombKind.firework:
        s.fx.explosion(x, y, 60);
        const cols = [Color(0xFFFF5252), Color(0xFF69F0AE), Color(0xFF40C4FF), Color(0xFFFFD740), Color(0xFFE040FB)];
        for (var k = 0; k < 3; k++) {
          s.fx.sparks(x, y, 0, -1, 40, color: cols[s.rng.nextInt(cols.length)]);
        }
        s.explode(x, y, 60, 600, damage: 25, fire: false, source: this);
        break;
      case BombKind.cluster:
        s.explode(x, y, 120, 2000, damage: 90, source: this);
        for (var i = 0; i < 6; i++) {
          final b = Bomb(BombKind.sticky, x + (s.rng.nextDouble() - 0.5) * 30, y - 10, 'bomb_sticky', 'Bomblet');
          s.add(b);
          final a = -math.pi / 2 + (s.rng.nextDouble() - 0.5) * 2.4;
          final sp = (300 + s.rng.nextDouble() * 400) * s.world.prevDt;
          for (final p in b.particles) {
            p.kick(math.cos(a) * sp, math.sin(a) * sp);
          }
          b.fuse = 1.0 + s.rng.nextDouble() * 1.2;
        }
        break;
      case BombKind.holy:
        s.explode(x, y, 420, 6000, damage: 600, source: this);
        s.fx.flash(x, y, 500, color: const Color(0xFFFFF8E1), life: 0.5);
        break;
    }
    // humans close to big blasts get thrown into a panic
    for (final hmn in s.humans) {
      if ((hmn.cx - x).abs() < 700) hmn.panic = math.max(hmn.panic, 2.0);
    }
  }

  @override
  Map<String, dynamic> saveData() => {'fuse': fuse, 'armed': armed};

  @override
  void loadData(Map<String, dynamic> d) {
    fuse = (d['fuse'] as num?)?.toDouble() ?? -1;
    armed = d['armed'] == true || (kind == BombKind.mine && d['armed'] == null);
  }

  @override
  void render(Canvas c, RenderCtx r) {
    inBox(c, body, () {
      final hw = w / 2, hh = h / 2;
      final rect = Rect.fromLTRB(-hw, -hh, hw, hh);
      final line = Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      Paint p(Color col) => Paint()..color = darken(col, charred);
      switch (kind) {
        case BombKind.grenade:
        case BombKind.holy:
          final col = kind == BombKind.holy ? const Color(0xFFFFD54F) : const Color(0xFF4B5320);
          c.drawOval(Rect.fromLTRB(-hw, -hh + 4, hw, hh), p(col));
          c.drawOval(Rect.fromLTRB(-hw, -hh + 4, hw, hh), line);
          c.drawRect(Rect.fromLTRB(-3, -hh, 3, -hh + 5), p(const Color(0xFF8A929C)));
          if (kind == BombKind.holy) {
            final cp = Paint()
              ..color = const Color(0xFF8D6E00)
              ..strokeWidth = 2;
            c.drawLine(const Offset(0, -2), const Offset(0, 8), cp);
            c.drawLine(const Offset(-4, 1), const Offset(4, 1), cp);
          } else {
            c.drawLine(Offset(3, -hh + 2), Offset(hw + 2, -hh + 7),
                Paint()
                  ..color = const Color(0xFF8A929C)
                  ..strokeWidth = 1.5);
          }
          break;
        case BombKind.cluster:
          c.drawCircle(Offset.zero, hw, p(const Color(0xFF37474F)));
          c.drawCircle(Offset.zero, hw, line);
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3;
            c.drawCircle(Offset(math.cos(a) * hw * 0.55, math.sin(a) * hw * 0.55), 2.5, p(const Color(0xFFFFB300)));
          }
          break;
        case BombKind.dynamite:
          for (var i = 0; i < 3; i++) {
            final y0 = -hh + i * h / 3;
            c.drawRect(Rect.fromLTRB(-hw, y0, hw - 4, y0 + h / 3), p(const Color(0xFFC62828)));
          }
          c.drawRect(Rect.fromLTRB(-hw, -hh, hw - 4, hh), line);
          c.drawLine(Offset(hw - 4, 0), Offset(hw + 4, -4),
              Paint()
                ..color = const Color(0xFF6D4C41)
                ..strokeWidth = 1.4);
          break;
        case BombKind.c4:
          c.drawRect(rect, p(const Color(0xFFD7CCA1)));
          c.drawRect(Rect.fromLTRB(-hw * 0.5, -hh * 0.6, hw * 0.5, hh * 0.6), p(const Color(0xFF263238)));
          c.drawCircle(Offset(hw * 0.25, 0), 2, Paint()..color = on ? const Color(0xFFFF1744) : const Color(0xFF660000));
          c.drawRect(rect, line);
          break;
        case BombKind.sticky:
          c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), p(const Color(0xFF7CB342)));
          c.drawCircle(Offset.zero, 2.5, Paint()..color = fuse >= 0 ? const Color(0xFFFF1744) : const Color(0xFF33691E));
          break;
        case BombKind.mine:
          c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), p(const Color(0xFF3E4A2E)));
          final blink = armed && (r.time * 2).floor() % 2 == 0;
          c.drawCircle(Offset(0, -hh + 2), 2.5, Paint()..color = blink ? const Color(0xFFFF1744) : const Color(0xFF331111));
          c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), line);
          break;
        case BombKind.nuke:
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw + 20, -hh, hw, hh), Radius.circular(hh)),
              p(const Color(0xFF4E5B47)));
          final fins = Path()
            ..moveTo(-hw + 30, -hh * 0.5)
            ..lineTo(-hw, -hh)
            ..lineTo(-hw, hh)
            ..lineTo(-hw + 30, hh * 0.5)
            ..close();
          c.drawPath(fins, p(const Color(0xFF3A4535)));
          c.drawCircle(const Offset(10, 0), hh * 0.45, p(const Color(0xFFFFD600)));
          final tp = Paint()..color = const Color(0xFF111111);
          for (var i = 0; i < 3; i++) {
            c.drawArc(Rect.fromCircle(center: const Offset(10, 0), radius: hh * 0.4), i * math.pi * 2 / 3,
                math.pi / 3, true, tp);
          }
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw + 20, -hh, hw, hh), Radius.circular(hh)), line);
          break;
        case BombKind.molotov:
          c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-hw, -hh + 10, hw, hh), const Radius.circular(4)),
              Paint()..color = const Color(0xBB6D9B3A));
          c.drawRect(Rect.fromLTRB(-hw * 0.4, -hh, hw * 0.4, -hh + 12), Paint()..color = const Color(0xBB6D9B3A));
          c.drawRect(Rect.fromLTRB(-2, -hh - 6, 2, -hh + 2), Paint()..color = const Color(0xFFEEEEEE));
          break;
        case BombKind.barrel:
          c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), p(const Color(0xFFB71C1C)));
          final bp = Paint()
            ..color = darken(const Color(0xFF7F0000), charred)
            ..strokeWidth = 3;
          c.drawLine(Offset(-hw, -hh * 0.4), Offset(hw, -hh * 0.4), bp);
          c.drawLine(Offset(-hw, hh * 0.4), Offset(hw, hh * 0.4), bp);
          final tri = Path()
            ..moveTo(0, -9)
            ..lineTo(9, 7)
            ..lineTo(-9, 7)
            ..close();
          c.drawPath(tri, Paint()..color = const Color(0xFFFFD600));
          c.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), line);
          break;
        case BombKind.gas:
          c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(hw)), p(const Color(0xFF1565C0)));
          c.drawRect(Rect.fromLTRB(-4, -hh - 5, 4, -hh + 2), p(const Color(0xFF8A929C)));
          c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(hw)), line);
          break;
        case BombKind.firework:
          c.drawRect(Rect.fromLTRB(-hw, -hh + 10, hw, hh), p(const Color(0xFF7B1FA2)));
          final tip = Path()
            ..moveTo(-hw, -hh + 10)
            ..lineTo(0, -hh)
            ..lineTo(hw, -hh + 10)
            ..close();
          c.drawPath(tip, p(const Color(0xFFFFD740)));
          c.drawRect(Rect.fromLTRB(-hw, -hh + 10, hw, hh), line);
          break;
      }
    });
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

/// A helium balloon: lifts whatever it is tied to.
class Balloon extends Entity {
  late Particle top;
  final Color color;
  Balloon(double x, double y, this.color) : super('balloon', material: Mat.rubber) {
    top = addP(x, y, 0.4)..gravityScale = -2.6;
    final knot = addP(x, y + 22, 0.15)..gravityScale = -1.5;
    addStick(top, knot);
    addCapsule(top, top, 18, friction: 0.3).tag = 'balloon';
    hp = 1;
    maxHp = 1;
  }

  @override
  String get name => 'Balloon';

  @override
  Map<String, dynamic> saveData() => {'c': color.toARGB32()};

  @override
  void damage(double amount, DmgType type) {
    if (amount > 0.3) pop();
  }

  @override
  void ignite([double seconds = 6]) => pop();

  void pop() {
    if (!attached || removed) return;
    Sfx.play('pop', vol: 0.9, rate: 1.5);
    sb.fx.debris(top.x, top.y, 6, color, speed: 200, size: 4);
    sb.removeEntity(this);
  }

  @override
  void render(Canvas c, RenderCtx r) {
    final k = particles[1];
    c.drawLine(Offset(top.x, top.y + 18), Offset(k.x, k.y),
        Paint()
          ..color = const Color(0xFFDDDDDD)
          ..strokeWidth = 1);
    c.drawOval(Rect.fromCenter(center: Offset(top.x, top.y), width: 34, height: 40), Paint()..color = outline);
    c.drawOval(Rect.fromCenter(center: Offset(top.x, top.y), width: 31, height: 37), Paint()..color = color);
    c.drawOval(Rect.fromCenter(center: Offset(top.x - 6, top.y - 8), width: 7, height: 10),
        Paint()..color = const Color(0x66FFFFFF));
    if (r.selected) {
      c.drawCircle(Offset(top.x, top.y), 24,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / r.zoom
            ..color = const Color(0xFFE53935));
    }
  }
}

/// A static or dynamic block drawn with the Build tool.
class Block extends Entity {
  double w, h;
  late List<Particle> body;
  Color color;
  final bool isStatic;

  Block(double x, double y, this.w, this.h, {this.isStatic = false, Mat mat = Mat.stone, Color? color, double rot = 0})
      : color = color ?? matInfo[mat]!.color,
        super(isStatic ? 'wall' : 'block', material: mat) {
    final mass = isStatic ? 0.0 : math.max(4.0, w * h / 120);
    body = makeBox(x, y, w, h, mass, rot: rot);
    addPoly(body);
    if (isStatic) {
      frozen = true;
    }
  }

  @override
  String get name => isStatic ? 'Wall' : 'Block';

  @override
  void setFrozen(bool f) {
    if (isStatic) return;
    super.setFrozen(f);
  }

  @override
  Map<String, dynamic> saveData() => {'w': w, 'h': h, 'mat': material.index, 'c': color.toARGB32()};

  @override
  void render(Canvas c, RenderCtx r) {
    inBox(c, body, () {
      final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
      c.drawRect(rect, Paint()..color = darken(color, charred));
      final hatch = Paint()
        ..color = darken(color, 0.25)
        ..strokeWidth = 1;
      if (isStatic) {
        for (var x = -w / 2; x < w / 2; x += 14) {
          c.drawLine(Offset(x, -h / 2), Offset(math.min(w / 2, x + h * 0.3), h / 2), hatch);
        }
      }
      c.drawRect(
          rect,
          Paint()
            ..color = outline
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    });
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
