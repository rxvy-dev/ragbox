import 'dart:math' as math;
import 'dart:ui';

import '../core/sfx.dart';
import '../engine/physics.dart';
import 'entity.dart';
import 'sandbox.dart';

enum Behavior { passive, coward, hostile, soldier, berserk }

enum Face { normal, visor, skull, zombie, alien, mask }

class HumanType {
  final String id;
  final String name;
  final String desc;
  final Color skin, shirt, pants, shoes, hair;
  final int hairStyle; // 0 none, 1 short, 2 long, 3 mohawk, 4 helmet, 5 hood, 6 crown, 7 dome
  final bool longSleeves;
  final double scale, massMul, hpMul, strength, speed;
  final double armorHead, armorTorso, armorArms, armorLegs;
  final Color armorColor;
  final Color blood;
  final bool bleeds, robotic, skeleton, undead, fireproof, coldproof, infectious;
  final int team;
  final Behavior behavior;
  final Face face;
  final double flammability;
  final double gravityScale;

  const HumanType({
    required this.id,
    required this.name,
    required this.desc,
    this.skin = const Color(0xFFE0A47A),
    this.shirt = const Color(0xFF3D5A80),
    this.pants = const Color(0xFF2B2D42),
    this.shoes = const Color(0xFF1B1B1E),
    this.hair = const Color(0xFF3B2416),
    this.hairStyle = 1,
    this.longSleeves = false,
    this.scale = 1,
    this.massMul = 1,
    this.hpMul = 1,
    this.strength = 1,
    this.speed = 120,
    this.armorHead = 0,
    this.armorTorso = 0,
    this.armorArms = 0,
    this.armorLegs = 0,
    this.armorColor = const Color(0xFF59606B),
    this.blood = const Color(0xFF9E1B1B),
    this.bleeds = true,
    this.robotic = false,
    this.skeleton = false,
    this.undead = false,
    this.fireproof = false,
    this.coldproof = false,
    this.infectious = false,
    this.team = 0,
    this.behavior = Behavior.passive,
    this.face = Face.normal,
    this.flammability = 0.2,
    this.gravityScale = 1,
  });

  HumanType copyWith({
    String? id,
    String? name,
    Color? skin,
    Color? shirt,
    Color? pants,
    Color? hair,
    int? hairStyle,
    double? scale,
    double? hpMul,
    double? armor,
    int? team,
    Behavior? behavior,
    double? speed,
  }) {
    return HumanType(
      id: id ?? this.id,
      name: name ?? this.name,
      desc: desc,
      skin: skin ?? this.skin,
      shirt: shirt ?? this.shirt,
      pants: pants ?? this.pants,
      shoes: shoes,
      hair: hair ?? this.hair,
      hairStyle: hairStyle ?? this.hairStyle,
      longSleeves: longSleeves,
      scale: scale ?? this.scale,
      massMul: massMul,
      hpMul: hpMul ?? this.hpMul,
      strength: strength,
      speed: speed ?? this.speed,
      armorHead: armor ?? armorHead,
      armorTorso: armor ?? armorTorso,
      armorArms: armor ?? armorArms,
      armorLegs: armor ?? armorLegs,
      armorColor: armorColor,
      blood: blood,
      bleeds: bleeds,
      robotic: robotic,
      skeleton: skeleton,
      undead: undead,
      fireproof: fireproof,
      coldproof: coldproof,
      infectious: infectious,
      team: team ?? this.team,
      behavior: behavior ?? this.behavior,
      face: face,
      flammability: flammability,
      gravityScale: gravityScale,
    );
  }
}

class HumanTypes {
  static const human = HumanType(
      id: 'human', name: 'Civilian', desc: 'Ordinary person. Panics when danger is near.',
      behavior: Behavior.coward);
  static const zombie = HumanType(
    id: 'zombie',
    name: 'Zombie',
    desc: 'Undead. Hunts the living, ignores blood loss. Bites infect.',
    skin: Color(0xFF7FA068),
    shirt: Color(0xFF5B4B3A),
    pants: Color(0xFF3A3F2E),
    hair: Color(0xFF2A2A1A),
    blood: Color(0xFF4F6B1E),
    undead: true,
    infectious: true,
    team: 1,
    behavior: Behavior.hostile,
    face: Face.zombie,
    speed: 70,
    hpMul: 1.3,
  );

  static const List<HumanType> all = [
    human,
    HumanType(
      id: 'worker',
      name: 'Worker',
      desc: 'Hard hat and overalls. Stands his ground.',
      shirt: Color(0xFFE07A1F),
      pants: Color(0xFF2F4B7C),
      hairStyle: 4,
      hair: Color(0xFFF2C12E),
      armorHead: 0.4,
      behavior: Behavior.passive,
      skin: Color(0xFFC68B62),
    ),
    HumanType(
      id: 'soldier',
      name: 'Soldier',
      desc: 'Body armour and helmet. Uses any gun you hand him against hostiles.',
      shirt: Color(0xFF4B5320),
      pants: Color(0xFF3B4220),
      hairStyle: 4,
      hair: Color(0xFF3B4220),
      longSleeves: true,
      armorHead: 0.6,
      armorTorso: 0.55,
      armorColor: Color(0xFF2F3418),
      behavior: Behavior.soldier,
      hpMul: 1.2,
      skin: Color(0xFFB07A55),
    ),
    HumanType(
      id: 'swat',
      name: 'Riot Officer',
      desc: 'Heavy armour everywhere. Hunts hostiles.',
      shirt: Color(0xFF1E1F24),
      pants: Color(0xFF1E1F24),
      hairStyle: 4,
      hair: Color(0xFF111111),
      longSleeves: true,
      armorHead: 0.8,
      armorTorso: 0.8,
      armorArms: 0.5,
      armorLegs: 0.5,
      armorColor: Color(0xFF30333A),
      behavior: Behavior.soldier,
      face: Face.mask,
      hpMul: 1.4,
      massMul: 1.2,
    ),
    HumanType(
      id: 'knight',
      name: 'Knight',
      desc: 'Full plate armour. Slow and very tough.',
      shirt: Color(0xFF9AA3AD),
      pants: Color(0xFF9AA3AD),
      shoes: Color(0xFF6F7882),
      hairStyle: 7,
      hair: Color(0xFFB9C1CA),
      longSleeves: true,
      armorHead: 0.95,
      armorTorso: 0.95,
      armorArms: 0.9,
      armorLegs: 0.9,
      armorColor: Color(0xFFB9C1CA),
      behavior: Behavior.hostile,
      team: 3,
      face: Face.visor,
      massMul: 1.6,
      hpMul: 1.5,
      speed: 80,
      flammability: 0,
    ),
    HumanType(
      id: 'firefighter',
      name: 'Firefighter',
      desc: 'Fireproof suit. Walks through flames.',
      shirt: Color(0xFFB8860B),
      pants: Color(0xFF8B6914),
      hairStyle: 4,
      hair: Color(0xFFB3261E),
      longSleeves: true,
      fireproof: true,
      flammability: 0,
      armorHead: 0.3,
      behavior: Behavior.passive,
    ),
    HumanType(
      id: 'astronaut',
      name: 'Astronaut',
      desc: 'Pressure suit. Resists cold and fire.',
      shirt: Color(0xFFEDEDED),
      pants: Color(0xFFEDEDED),
      shoes: Color(0xFF9A9A9A),
      hairStyle: 7,
      hair: Color(0xFFEDEDED),
      longSleeves: true,
      face: Face.visor,
      coldproof: true,
      fireproof: true,
      armorHead: 0.5,
      armorTorso: 0.2,
      flammability: 0,
      behavior: Behavior.passive,
    ),
    zombie,
    HumanType(
      id: 'skeleton',
      name: 'Skeleton',
      desc: 'Brittle bones, no blood. Falls apart easily.',
      skin: Color(0xFFE8E2CF),
      skeleton: true,
      bleeds: false,
      undead: true,
      hairStyle: 0,
      face: Face.skull,
      team: 1,
      behavior: Behavior.hostile,
      hpMul: 0.6,
      massMul: 0.6,
      flammability: 0,
    ),
    HumanType(
      id: 'android',
      name: 'Android',
      desc: 'Synthetic worker. Sparks instead of blood, shrugs off fire.',
      skin: Color(0xFFC9CED6),
      shirt: Color(0xFF8C939E),
      pants: Color(0xFF5E646D),
      shoes: Color(0xFF3A3F46),
      hairStyle: 0,
      robotic: true,
      bleeds: false,
      blood: Color(0xFF222222),
      face: Face.visor,
      hpMul: 1.6,
      massMul: 1.3,
      fireproof: true,
      flammability: 0,
      behavior: Behavior.passive,
    ),
    HumanType(
      id: 'droid',
      name: 'Combat Droid',
      desc: 'Hostile machine. Attacks every organic.',
      skin: Color(0xFF3A3F46),
      shirt: Color(0xFF8F2B2B),
      pants: Color(0xFF2A2D33),
      shoes: Color(0xFF15171A),
      hairStyle: 0,
      robotic: true,
      bleeds: false,
      blood: Color(0xFF222222),
      face: Face.visor,
      armorTorso: 0.6,
      armorHead: 0.6,
      armorColor: Color(0xFF8F2B2B),
      hpMul: 1.8,
      massMul: 1.5,
      fireproof: true,
      flammability: 0,
      team: 2,
      behavior: Behavior.soldier,
    ),
    HumanType(
      id: 'alien',
      name: 'Alien',
      desc: 'Lanky visitor with green blood and low-gravity jumps.',
      skin: Color(0xFF8BD17C),
      shirt: Color(0xFF3B2A5A),
      pants: Color(0xFF2A1F40),
      hairStyle: 0,
      blood: Color(0xFF3FCF3F),
      face: Face.alien,
      scale: 1.05,
      massMul: 0.8,
      gravityScale: 0.7,
      team: 4,
      behavior: Behavior.coward,
    ),
    HumanType(
      id: 'giant',
      name: 'Giant',
      desc: 'Enormous and strong. Hard to knock over.',
      shirt: Color(0xFF6B4226),
      pants: Color(0xFF3E2A1A),
      hairStyle: 2,
      hair: Color(0xFF5A3A1A),
      scale: 1.6,
      massMul: 1.0,
      hpMul: 3,
      strength: 1.4,
      speed: 90,
      behavior: Behavior.berserk,
      team: 5,
    ),
    HumanType(
      id: 'gnome',
      name: 'Gnome',
      desc: 'Tiny, quick and fragile.',
      shirt: Color(0xFF2E7D32),
      pants: Color(0xFF5D4037),
      hairStyle: 5,
      hair: Color(0xFFC62828),
      scale: 0.6,
      hpMul: 0.5,
      speed: 150,
      behavior: Behavior.coward,
    ),
    HumanType(
      id: 'mummy',
      name: 'Mummy',
      desc: 'Wrapped undead. Extremely flammable.',
      skin: Color(0xFFD8CBA8),
      shirt: Color(0xFFD8CBA8),
      pants: Color(0xFFCFC09A),
      shoes: Color(0xFFBFAF88),
      hairStyle: 0,
      longSleeves: true,
      undead: true,
      bleeds: false,
      team: 1,
      behavior: Behavior.hostile,
      face: Face.zombie,
      flammability: 1.0,
      speed: 60,
    ),
    HumanType(
      id: 'cyborg',
      name: 'Cyborg',
      desc: 'Half machine. Armoured torso, still bleeds.',
      shirt: Color(0xFF263238),
      pants: Color(0xFF37474F),
      hairStyle: 3,
      hair: Color(0xFF00BCD4),
      armorTorso: 0.7,
      armorArms: 0.4,
      armorColor: Color(0xFF90A4AE),
      hpMul: 1.4,
      behavior: Behavior.soldier,
    ),
    HumanType(
      id: 'ninja',
      name: 'Ninja',
      desc: 'Fast melee fighter. Attacks anyone.',
      shirt: Color(0xFF16161A),
      pants: Color(0xFF16161A),
      shoes: Color(0xFF0E0E10),
      hairStyle: 5,
      hair: Color(0xFF16161A),
      longSleeves: true,
      face: Face.mask,
      speed: 190,
      strength: 1.2,
      behavior: Behavior.berserk,
      team: 6,
    ),
    HumanType(
      id: 'king',
      name: 'Monarch',
      desc: 'Wears a crown. Expects to be protected.',
      shirt: Color(0xFF6A1B9A),
      pants: Color(0xFF4A148C),
      hairStyle: 6,
      hair: Color(0xFFFFC107),
      longSleeves: true,
      behavior: Behavior.coward,
    ),
    HumanType(
      id: 'brute',
      name: 'Brute',
      desc: 'Muscle-bound hostile thug with fists of iron.',
      skin: Color(0xFF9C6B4E),
      shirt: Color(0xFF7B1F1F),
      pants: Color(0xFF263238),
      hairStyle: 3,
      hair: Color(0xFF111111),
      massMul: 1.4,
      hpMul: 1.8,
      strength: 1.3,
      behavior: Behavior.hostile,
      team: 7,
    ),
    HumanType(
      id: 'dummy',
      name: 'Crash Dummy',
      desc: 'Test dummy. Never panics, never bleeds.',
      skin: Color(0xFFF2D04B),
      shirt: Color(0xFFF2D04B),
      pants: Color(0xFFF2D04B),
      shoes: Color(0xFF222222),
      hairStyle: 0,
      longSleeves: true,
      bleeds: false,
      face: Face.mask,
      hpMul: 2,
      behavior: Behavior.passive,
      strength: 0,
    ),
  ];

  static HumanType byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => human);

  /// Builds a type from a custom character config map.
  static HumanType fromConfig(Map<String, dynamic> c) {
    final base = byId(c['base'] as String? ?? 'human');
    Color? col(String k) => c[k] == null ? null : Color((c[k] as num).toInt());
    final b = c['behavior'] as String?;
    return base.copyWith(
      id: 'custom',
      name: c['name'] as String? ?? 'Custom',
      skin: col('skin'),
      shirt: col('shirt'),
      pants: col('pants'),
      hair: col('hair'),
      hairStyle: (c['hairStyle'] as num?)?.toInt(),
      scale: (c['scale'] as num?)?.toDouble(),
      hpMul: (c['hpMul'] as num?)?.toDouble(),
      armor: (c['armor'] as num?)?.toDouble(),
      team: (c['team'] as num?)?.toInt(),
      behavior: b == null
          ? null
          : Behavior.values.firstWhere((v) => v.name == b, orElse: () => base.behavior),
    );
  }
}

// Particle indices
const int pH = 0, pN = 1, pS = 2, pP = 3, pEL = 4, pHL = 5, pER = 6, pHR = 7;
const int pKL = 8, pFL = 9, pKR = 10, pFR = 11;

// Limb (shape) indices
const int lHead = 0, lUTorso = 1, lLTorso = 2, lUArmL = 3, lLArmL = 4, lUArmR = 5,
    lLArmR = 6, lULegL = 7, lLLegL = 8, lULegR = 9, lLLegR = 10;

const List<String> limbNames = [
  'Head', 'Chest', 'Abdomen', 'Upper arm', 'Forearm', 'Upper arm', 'Forearm',
  'Thigh', 'Shin', 'Thigh', 'Shin'
];

class Wound {
  final int limb;
  final double t, side;
  Wound(this.limb, this.t, this.side);
}

class Human extends Entity {
  HumanType type;
  Map<String, dynamic>? customCfg;
  static int _groupSeq = 1;
  int group = 0;
  int facing = 1;

  final List<double> limbHp = List<double>.filled(11, 0);
  final List<double> limbMax = List<double>.filled(11, 0);
  final List<bool> severed = List<bool>.filled(11, false);
  final List<int> severOrder = [];
  final List<Wound> wounds = [];
  double blood = 100;
  double bleed = 0;
  double pain = 0;
  double stun = 0;
  double spasm = 0;
  double frozenIce = 0;
  bool dead = false;
  bool infected = false;
  double reanimate = 0;
  double _think = 0;
  double _attackCd = 0;
  double _walkPhase = 0;
  int moveDir = 0;
  Human? target;
  double panic = 0;
  double _voiceCd = 0;
  List<List<double>>? _savedLimits;

  Entity? held;
  UserJoint? gripJoint;
  final List<int> _heldGroups = [];

  late List<AngleLimit> _limits; // neck, spine, kneeL, kneeR, elbowL, elbowR, hipL, hipR, shL, shR

  Human(double x, double y, this.type, {String defId = 'human', this.customCfg, int facing = 1})
      : super(defId, material: Mat.flesh) {
    _build(x, y);
    if (facing < 0) flip();
  }

  @override
  bool get isHuman => true;
  @override
  String get name => type.name;
  @override
  bool get canBurn => type.flammability > 0 && !type.fireproof;
  @override
  bool get conductive => true;

  double get s => type.scale;
  bool get alive => !dead;
  bool get conscious => !dead && stun <= 0 && frozenIce <= 0 && blood > 30;
  double get health {
    var t = 0.0, m = 0.0;
    for (var i = 0; i < 11; i++) {
      t += limbHp[i].clamp(0.0, limbMax[i]);
      m += limbMax[i];
    }
    return dead ? 0 : (t / m).clamp(0.0, 1.0);
  }

  void _build(double x, double y) {
    group = _groupSeq++;
    if (_groupSeq > 990) _groupSeq = 1;
    final sc = s;
    final mm = type.massMul * sc * sc;
    // feet at y, facing right
    Particle P(double dx, double dy, double m) {
      final p = addP(x + dx * sc, y + dy * sc, m * mm);
      p.gravityScale = type.gravityScale;
      return p;
    }

    final head = P(2, -168, 5);
    final neck = P(0, -150, 6);
    final spine = P(0, -122, 10);
    final pelvis = P(0, -92, 10);
    final elL = P(-2, -122, 2.5);
    final haL = P(2, -96, 1.5);
    final elR = P(4, -122, 2.5);
    final haR = P(8, -96, 1.5);
    final knL = P(-3, -47, 5);
    final ftL = P(-5, -3, 3);
    final knR = P(5, -47, 5);
    final ftR = P(7, -3, 3);

    addStick(head, neck);
    addStick(neck, spine);
    addStick(spine, pelvis);
    addStick(neck, pelvis, stiffness: 0.6);
    addStick(neck, elL);
    addStick(elL, haL);
    addStick(neck, elR);
    addStick(elR, haR);
    addStick(pelvis, knL);
    addStick(knL, ftL);
    addStick(pelvis, knR);
    addStick(knR, ftR);

    const pi = math.pi;
    final neckL = addAngle(head, neck, spine, pi - 0.6, pi + 0.6, stiffness: 0.6, target: pi);
    final spineL = addAngle(neck, spine, pelvis, pi - 0.45, pi + 0.45, stiffness: 0.6, target: pi);
    final kneeL = addAngle(pelvis, knL, ftL, pi - 0.05, pi + 2.5, stiffness: 0.5, target: pi);
    final kneeR = addAngle(pelvis, knR, ftR, pi - 0.05, pi + 2.5, stiffness: 0.5, target: pi);
    final elbL = addAngle(neck, elL, haL, pi - 2.6, pi + 0.05, stiffness: 0.5, target: pi - 0.3);
    final elbR = addAngle(neck, elR, haR, pi - 2.6, pi + 0.05, stiffness: 0.5, target: pi - 0.3);
    final hipL = addAngle(spine, pelvis, knL, pi - 1.9, pi + 0.6, stiffness: 0.5, target: pi);
    final hipR = addAngle(spine, pelvis, knR, pi - 1.9, pi + 0.6, stiffness: 0.5, target: pi);
    final shL = addAngle(head, neck, elL, 0.15, pi * 2 - 0.15, stiffness: 0.3, target: pi - 0.1);
    final shR = addAngle(head, neck, elR, 0.15, pi * 2 - 0.15, stiffness: 0.3, target: pi - 0.15);
    _limits = [neckL, spineL, kneeL, kneeR, elbL, elbR, hipL, hipR, shL, shR];

    final f = 0.9;
    Shape cap(Particle a, Particle b, double r, int limb) {
      final sh = addCapsule(a, b, r * sc, friction: f, tag: limb);
      sh.group = group;
      return sh;
    }

    cap(head, head, 11, lHead);
    cap(neck, spine, 9.5, lUTorso);
    cap(spine, pelvis, 9, lLTorso);
    cap(neck, elL, 4.8, lUArmL);
    cap(elL, haL, 4.3, lLArmL);
    cap(neck, elR, 4.8, lUArmR);
    cap(elR, haR, 4.3, lLArmR);
    cap(pelvis, knL, 6.3, lULegL);
    cap(knL, ftL, 5.4, lLLegL);
    cap(pelvis, knR, 6.3, lULegR);
    cap(knR, ftR, 5.4, lLLegR);

    const base = [60.0, 120.0, 110.0, 50.0, 45.0, 50.0, 45.0, 70.0, 60.0, 70.0, 60.0];
    for (var i = 0; i < 11; i++) {
      limbMax[i] = base[i] * type.hpMul * (type.skeleton ? 0.6 : 1);
      limbHp[i] = limbMax[i];
    }
  }

  double armorOf(int limb) {
    switch (limb) {
      case lHead:
        return type.armorHead;
      case lUTorso:
      case lLTorso:
        return type.armorTorso;
      case lUArmL:
      case lLArmL:
      case lUArmR:
      case lLArmR:
        return type.armorArms;
      default:
        return type.armorLegs;
    }
  }

  // ------------------------------------------------------------------ flip
  @override
  void flip() {
    final c = cx;
    super.flip();
    facing = -facing;
    final h = held;
    if (h != null && !h.removed) {
      for (final p in h.particles) {
        p.x = 2 * c - p.x;
        p.px = 2 * c - p.px;
      }
      if (h is Flippable) (h as Flippable).mirrored = !(h as Flippable).mirrored;
    }
  }

  // ------------------------------------------------------------------ holding
  bool canGrab(Entity item) =>
      alive && !severed[lLArmR] && !severed[lUArmR] && held == null && item is HeldItem;

  void grab(Entity item) {
    if (!canGrab(item)) return;
    final hi = item as HeldItem;
    if (hi.holder != null) hi.holder!.drop();
    final hand = particles[pHR];
    final gp = item.particles[hi.gripIndex];
    // move the entire item so its grip sits in the hand
    final ox = hand.x - gp.x, oy = hand.y - gp.y;
    for (final p in item.particles) {
      p.moveTo(p.x + ox, p.y + oy);
    }
    final j = sb.addJoint(JointType.grip, this, pHR, item, hi.gripIndex, undoable: false, rest: 0);
    if (j == null) return;
    gripJoint = j;
    held = item;
    hi.holder = this;
    _heldGroups
      ..clear()
      ..addAll(item.shapes.map((s) => s.group));
    for (final sh in item.shapes) {
      sh.group = group;
    }
    Sfx.play('click', vol: 0.5);
  }

  void restoreGrip(UserJoint j, Entity item) {
    if (item is! HeldItem) return;
    gripJoint = j;
    held = item;
    (item as HeldItem).holder = this;
    _heldGroups
      ..clear()
      ..addAll(item.shapes.map((s) => s.group));
    for (final sh in item.shapes) {
      sh.group = group;
    }
  }

  void drop() {
    final h = held;
    if (gripJoint != null && attached) {
      final j = gripJoint!;
      gripJoint = null;
      sb.removeJoint(j);
    }
    if (h != null) {
      for (var i = 0; i < h.shapes.length; i++) {
        h.shapes[i].group = i < _heldGroups.length ? _heldGroups[i] : 0;
      }
      if (h is HeldItem) (h as HeldItem).holder = null;
    }
    held = null;
  }

  @override
  void use() {
    // Activating a human makes them use what they hold.
    final h = held;
    if (h != null) h.use();
  }

  // ------------------------------------------------------------------ damage
  @override
  void damage(double amount, DmgType type) {
    // generic damage without a hit location goes to the torso
    _damageLimb(lUTorso, amount, type);
  }

  @override
  void receiveHit(Hit h) {
    if (removed) return;
    final limb = (h.shape?.tag is int) ? h.shape!.tag as int : lUTorso;
    if (h.type == DmgType.heal) {
      heal(h.damage);
      return;
    }
    if (h.type == DmgType.cold) {
      if (!type.coldproof) freeze(8);
      return;
    }
    var dmg = h.damage;
    final armor = armorOf(limb);
    if (h.type == DmgType.bullet && armor > 0) {
      if (sb.rng.nextDouble() < armor * 0.75 && dmg < 120) {
        // ricochet
        h.stopped = true;
        sb.fx.sparks(h.x, h.y, -h.dx, -h.dy, 6);
        Sfx.play('clang', vol: 0.35, rate: 1.4);
        dmg *= 0.08;
        pain += 5;
        _impulse(h, limb, 0.4);
        _damageLimb(limb, dmg, h.type);
        return;
      }
      dmg *= (1 - armor * 0.5);
    } else if (h.type == DmgType.sharp || h.type == DmgType.blunt) {
      dmg *= (1 - armor * 0.7);
    } else if (h.type == DmgType.explosion) {
      dmg *= (1 - armor * 0.35);
    }
    if (h.type == DmgType.fire && type.fireproof) dmg = 0;
    if (h.type == DmgType.electric) {
      spasm = math.max(spasm, 1.2);
      if (type.robotic) dmg *= 1.6;
      sb.fx.sparks(h.x, h.y, 0, -1, 4, color: const Color(0xFF9FE7FF));
    }
    if (h.type == DmgType.bullet && limb == lHead) dmg *= 2.5;
    if (h.type == DmgType.fire || h.type == DmgType.laser) {
      if (!type.fireproof) ignite(h.type == DmgType.laser ? 3 : 1.2);
    }

    final wasDead = dead;
    _damageLimb(limb, dmg, h.type);
    if (h.force != 0 || h.type == DmgType.bullet) _impulse(h, limb, 1);

    // wounds & blood
    final bloody = type.bleeds && (h.type == DmgType.bullet || h.type == DmgType.sharp ||
        h.type == DmgType.explosion || h.type == DmgType.laser || h.type == DmgType.crush);
    if (h.type == DmgType.bullet || h.type == DmgType.sharp || h.type == DmgType.laser) {
      final sh = h.shape;
      if (sh != null && wounds.length < 60) {
        final a = sh.pts[0], b = sh.pts[1];
        final t = projT(h.x, h.y, a.x, a.y, b.x, b.y);
        final cxw = a.x + (b.x - a.x) * t, cyw = a.y + (b.y - a.y) * t;
        var nx = -(b.y - a.y), ny = b.x - a.x;
        final l = math.sqrt(nx * nx + ny * ny);
        double side = 0;
        if (l > 1e-6) {
          nx /= l;
          ny /= l;
          side = ((h.x - cxw) * nx + (h.y - cyw) * ny) / math.max(1.0, sh.radius);
        }
        wounds.add(Wound(limb, t, side.clamp(-0.8, 0.8)));
      }
    }
    if (bloody && dmg > 0.5) {
      final still = h.dx == 0 && h.dy == 0;
      sb.fx.blood(h.x, h.y, still ? 0.0 : h.dx, still ? -1.0 : h.dy,
          (4 + dmg / 4).round().clamp(3, 30), type.blood);
      sb.fx.blood(h.x, h.y, -h.dx, -h.dy, (2 + dmg / 10).round().clamp(1, 8), type.blood, speed: 150);
      bleed += dmg * 0.04;
      Sfx.play('squish', vol: math.min(0.7, 0.2 + dmg / 80), rate: 0.9 + sb.rng.nextDouble() * 0.3);
    } else if (type.robotic && dmg > 1) {
      sb.fx.sparks(h.x, h.y, -h.dx, -h.dy, 6);
      Sfx.play('clang', vol: 0.3, rate: 1.2);
    } else if (type.skeleton && dmg > 1) {
      sb.fx.debris(h.x, h.y, 3, const Color(0xFFE8E2CF), speed: 200, size: 2);
    }

    // dismemberment
    if (sb.fx.gore || type.skeleton || type.robotic) {
      final severe = (h.type == DmgType.sharp && dmg > 35) ||
          (h.type == DmgType.explosion && dmg > 55) ||
          (h.type == DmgType.bullet && dmg > 90) ||
          (type.skeleton && dmg > 25);
      if (severe && limbHp[limb] <= 0) sever(limb);
      if (h.type == DmgType.explosion && dmg > 150 && sb.fx.gore && !type.robotic) {
        gib();
        return;
      }
    }
    if (!wasDead && dead) _onDeath();
  }

  void _impulse(Hit h, int limb, double mul) {
    final sh = shapes.firstWhere((x) => x.tag == limb, orElse: () => shapes[lUTorso]);
    final dt = stepDt;
    final f = h.force * mul;
    for (final p in sh.pts.toSet()) {
      if (p.invMass == 0) continue;
      // light limbs fly, heavy bodies less so
      p.kick(h.dx * f * p.invMass * dt * 0.5, h.dy * f * p.invMass * dt * 0.5);
    }
    // a little to the core so the whole body reacts
    final core = particles[pS];
    if (core.invMass > 0) {
      core.kick(h.dx * f * core.invMass * dt * 0.25, h.dy * f * core.invMass * dt * 0.25);
    }
  }

  void _damageLimb(int limb, double dmg, DmgType t) {
    if (dmg <= 0) return;
    limbHp[limb] -= dmg;
    pain += dmg * (type.undead || type.robotic ? 0.2 : 1.0);
    if (dmg > 25 && !type.undead && !type.robotic) stun = math.max(stun, dmg / 40);
    if (dead) return;
    if (limb == lHead && limbHp[lHead] <= 0) _die();
    if ((limb == lUTorso || limb == lLTorso) &&
        limbHp[lUTorso] + limbHp[lLTorso] <= 0) {
      _die();
    }
    if (!type.undead && pain > 140) stun = math.max(stun, 2.5);
  }

  void _die() {
    if (dead) return;
    dead = true;
    for (final l in angles) {
      l.muscle = 0;
    }
  }

  void _onDeath() {
    if (infected && !type.undead) reanimate = 5;
    if (!type.robotic && !type.skeleton) Sfx.play('groan', vol: 0.5, rate: 0.8 + type.scale * 0.1);
  }

  void heal(double amount) {
    for (var i = 0; i < 11; i++) {
      if (severed[i]) continue;
      limbHp[i] = math.min(limbMax[i], limbHp[i] + amount);
    }
    blood = math.min(100.0, blood + amount);
    bleed = 0;
    pain = 0;
    stun = 0;
    burning = 0;
    if (frozenIce > 0) thaw();
    if (dead && !severed[lHead] && limbHp[lHead] > 0 && limbHp[lUTorso] + limbHp[lLTorso] > 0) {
      dead = false;
      wounds.clear();
    }
    if (amount >= 999) {
      wounds.clear();
      charred = 0;
    }
  }

  void kill() {
    limbHp[lHead] = 0;
    _die();
    _onDeath();
  }

  void freeze(double secs) {
    if (frozenIce > 0) {
      frozenIce = math.max(frozenIce, secs);
      return;
    }
    frozenIce = secs;
    burning = 0;
    _savedLimits = [
      for (final l in angles) [l.min, l.max]
    ];
    for (final l in angles) {
      final c = l.current();
      l.min = c - 0.02;
      l.max = c + 0.02;
      l.stiffness = 1;
    }
    Sfx.play('glass', vol: 0.4, rate: 1.6);
  }

  void thaw() {
    frozenIce = 0;
    final sv = _savedLimits;
    if (sv != null && sv.length == angles.length) {
      for (var i = 0; i < angles.length; i++) {
        angles[i].min = sv[i][0];
        angles[i].max = sv[i][1];
        angles[i].stiffness = 0.5;
      }
    }
    _savedLimits = null;
  }

  void burnTick(double dt) {
    if (type.fireproof) {
      burning = 0;
      return;
    }
    _damageLimb(lUTorso, dt * 6, DmgType.fire);
    panic = 2;
  }

  /// Detach a limb (head, arms at shoulder, legs at hip, or lower limbs).
  void sever(int limb) {
    if (severed[limb] || limb == lUTorso || limb == lLTorso) return;
    severed[limb] = true;
    severOrder.add(limb);
    final world = attached ? sb.world : null;
    Particle? joint;
    Particle? partner;
    switch (limb) {
      case lHead:
        joint = particles[pN];
        partner = particles[pH];
        break;
      case lUArmL:
        joint = particles[pN];
        partner = particles[pEL];
        severed[lLArmL] = true;
        break;
      case lUArmR:
        joint = particles[pN];
        partner = particles[pER];
        severed[lLArmR] = true;
        break;
      case lLArmL:
        joint = particles[pEL];
        partner = particles[pHL];
        break;
      case lLArmR:
        joint = particles[pER];
        partner = particles[pHR];
        break;
      case lULegL:
        joint = particles[pP];
        partner = particles[pKL];
        severed[lLLegL] = true;
        break;
      case lULegR:
        joint = particles[pP];
        partner = particles[pKR];
        severed[lLLegR] = true;
        break;
      case lLLegL:
        joint = particles[pKL];
        partner = particles[pFL];
        break;
      case lLLegR:
        joint = particles[pKR];
        partner = particles[pFR];
        break;
    }
    if (joint == null || partner == null) return;
    final j = joint, pt = partner;
    // remove the stick between joint and partner, plus angle limits using both
    final dead_ = sticks.where((st) =>
        (identical(st.a, j) && identical(st.b, pt)) || (identical(st.a, pt) && identical(st.b, j))).toList();
    for (final st in dead_) {
      sticks.remove(st);
      world?.removeStick(st);
    }
    final deadA = angles.where((a) =>
        (identical(a.a, pt) || identical(a.c, pt)) && identical(a.b, j) ||
        (identical(a.b, pt) && (identical(a.a, j) || identical(a.c, j))) ||
        (limb == lHead && identical(a.a, pt))).toList();
    for (final a in deadA) {
      a.enabled = false;
    }
    if (limb != lHead) {
      // the severed capsule needs its own copy of the joint particle
      final clone = addP(j.x, j.y, j.mass * 0.5);
      clone.px = j.px;
      clone.py = j.py;
      clone.gravityScale = j.gravityScale;
      final sh = shapes.firstWhere((x) => x.tag == limb);
      for (var i = 0; i < 2; i++) {
        if (identical(sh.pts[i], j)) sh.pts[i] = clone;
      }
      addStick(clone, pt);
    }
    if (attached) {
      if (type.bleeds) {
        sb.fx.blood(j.x, j.y, 0, -1, 25, type.blood, speed: 350);
        bleed += 4;
      } else if (type.robotic) {
        sb.fx.sparks(j.x, j.y, 0, -1, 14);
      }
      Sfx.play('squish', vol: 0.8, rate: 0.7);
    }
    if (limb == lHead) {
      _die();
      if (attached) _onDeath();
    }
    if (held != null && (limb == lUArmR || limb == lLArmR)) drop();
  }

  void gib() {
    if (!attached) return;
    final c = Color.lerp(type.skin, type.blood, 0.5)!;
    for (final p in particles) {
      sb.fx.blood(p.x, p.y, 0, -1, 8, type.blood, speed: 500);
      sb.fx.debris(p.x, p.y, 2, c, speed: 500, size: 5);
    }
    Sfx.play('squish', vol: 1, rate: 0.6);
    drop();
    sb.removeEntity(this);
  }

  // ------------------------------------------------------------------ impacts
  @override
  void onImpact(Impact imp, Shape mine, Shape other, double speed) {
    final limb = mine.tag is int ? mine.tag as int : lUTorso;
    if (other.tag == 'spike') {
      final dmg = 25 + speed / 30;
      receiveHit(Hit(imp.x, imp.y, -imp.nx, -imp.ny, dmg, 0, DmgType.sharp, shape: mine));
      // impale: slow the limb down
      for (final p in mine.pts) {
        p.px = p.x - p.vx * 0.2;
        p.py = p.y - p.vy * 0.2;
      }
      return;
    }
    if (speed > 700) {
      final dmg = (speed - 700) / 22;
      final wasDead = dead;
      _damageLimb(limb, dmg, DmgType.blunt);
      if (dmg > 30 && type.bleeds) {
        sb.fx.blood(imp.x, imp.y, imp.nx, imp.ny, (dmg / 5).round().clamp(2, 20), type.blood);
        bleed += dmg * 0.02;
      }
      if (dmg > 60 && (limb != lUTorso && limb != lLTorso) && (type.skeleton || dmg > 110)) {
        sever(limb);
      }
      if (dmg > 10) Sfx.play('thud', vol: math.min(1.0, dmg / 60), rate: 0.8);
      if (!wasDead && dead) _onDeath();
    }
  }

  // ------------------------------------------------------------------ control
  bool _grounded() {
    final f = sb.world.frame;
    for (final i in [pFL, pFR, pKL, pKR]) {
      final p = particles[i];
      if (f - p.touchFrame < 8 && p.touchNy < -0.4) return true;
    }
    return false;
  }

  /// Called before every physics sub step: applies muscle forces.
  @override
  void preStep(double dt) {
    if (frozen || removed) return;
    final str = (type.strength * _strengthFactor()).clamp(0.0, 1.6);
    for (final l in _limits) {
      l.muscle = dead || frozenIce > 0 ? 0.0 : (0.01 + 0.03 * str).clamp(0.0, 1.0);
    }
    if (str <= 0.01 || !conscious) return;
    if (!_grounded()) return;
    final g = sb.world.gravityY.abs();
    if (g < 1) return; // no standing in zero gravity
    final ps = particles;
    final fl = ps[pFL], fr = ps[pFR];
    final legsOk = !severed[lULegL] && !severed[lULegR] && !severed[lLLegL] && !severed[lLLegR];
    if (!legsOk) return;
    final footX = (fl.x + fr.x) / 2;
    final groundY = math.max(fl.y, fr.y);
    final sc = s;
    final lean = moveDir * 10.0 * sc;
    final kp = 260.0 * str;
    final kd = 22.0 * math.sqrt(str);
    void pd(Particle p, double tx, double ty, double kx, double ky, double maxUp) {
      final vx = (p.x - p.px) / dt, vy = (p.y - p.py) / dt;
      var ax = (tx - p.x) * kx - vx * kd;
      var ay = (ty - p.y) * ky - vy * kd;
      if (ay < -maxUp) ay = -maxUp;
      if (ay > g) ay = g;
      ax = ax.clamp(-1200.0, 1200.0);
      p.ax += ax;
      p.ay += ay;
    }

    // The stand-up force on the core parts stays below the whole body's
    // weight, so it can never lift the person off the ground.
    final upMax = g * 1.5; // 4 core parts at 1.5g ≈ 85% of total body weight
    final pelvisY = groundY - 89 * sc;
    pd(ps[pP], footX + lean * 0.5, pelvisY, kp * 0.6, kp, upMax);
    pd(ps[pN], footX + lean, groundY - 148 * sc, kp * 0.8, kp, upMax);
    pd(ps[pH], footX + lean + 2 * facing * sc, groundY - 166 * sc, kp * 0.8, kp, upMax);
    pd(ps[pS], footX + lean * 0.8, groundY - 121 * sc, kp * 0.5, kp * 0.7, upMax);
    // keep feet apart and planted
    final spread = 14.0 * sc;
    final dxf = fr.x - fl.x;
    if (moveDir == 0) {
      if (dxf.abs() < spread) {
        final push = (spread - dxf.abs()) * 30;
        final sgn = dxf >= 0 ? 1.0 : -1.0;
        fl.ax -= push * sgn;
        fr.ax += push * sgn;
      }
      fl.ay += 300;
      fr.ay += 300;
    } else {
      // walking: move pelvis and swing feet
      final speed = type.speed * sc * (panic > 0 ? 1.6 : 1.0);
      final pv = (ps[pP].x - ps[pP].px) / dt;
      final push = (moveDir * speed - pv) * 6.0;
      ps[pP].ax += push;
      ps[pN].ax += push;
      ps[pS].ax += push;
      for (var i = 0; i < 2; i++) {
        final ft = i == 0 ? fl : fr;
        final ph = _walkPhase + i * math.pi;
        final tx = ps[pP].x + moveDir * 20 * sc * math.sin(ph);
        final lift = math.max(0.0, math.cos(ph));
        final vx = (ft.x - ft.px) / dt;
        ft.ax += (tx - ft.x) * 160 - vx * 10;
        ft.ay += -lift * g * 2.4 + (1 - lift) * 400;
      }
    }
  }

  double _strengthFactor() {
    if (dead) return 0;
    var f = 1.0;
    if (stun > 0) return 0;
    if (frozenIce > 0) return 0;
    f *= (blood / 100).clamp(0.0, 1.0);
    final legs = (limbHp[lULegL] > 0 ? 1 : 0) + (limbHp[lULegR] > 0 ? 1 : 0) +
        (limbHp[lLLegL] > 0 ? 1 : 0) + (limbHp[lLLegR] > 0 ? 1 : 0);
    if (legs < 3) f *= 0.15;
    if (spasm > 0) f *= 0.3;
    return f;
  }

  @override
  void update(double dt) {
    if (removed) return;
    if (gripJoint != null && !sb.joints.contains(gripJoint)) {
      gripJoint = null;
      held = null;
    }
    if (held != null && held!.removed) held = null;
    _attackCd -= dt;
    _voiceCd -= dt;
    if (stun > 0) stun -= dt;
    pain = math.max(0.0, pain - dt * 12);
    if (spasm > 0) {
      spasm -= dt;
      for (final p in particles) {
        if (sb.rng.nextDouble() < 0.3) {
          p.kick((sb.rng.nextDouble() - 0.5) * 2.5, (sb.rng.nextDouble() - 0.5) * 2.5);
        }
      }
    }
    if (frozenIce > 0) {
      frozenIce -= dt;
      if (frozenIce <= 0) thaw();
    }
    if (panic > 0) panic -= dt;
    if (bleed > 0 && type.bleeds) {
      blood -= bleed * dt;
      bleed = math.max(0.0, bleed - dt * 0.15);
      if (sb.rng.nextDouble() < bleed * dt * 3 && wounds.isNotEmpty) {
        final w = wounds[sb.rng.nextInt(wounds.length)];
        final sh = shapes[w.limb];
        final a = sh.pts[0], b = sh.pts[1];
        sb.fx.blood(a.x + (b.x - a.x) * w.t, a.y + (b.y - a.y) * w.t, 0, 1, 1, type.blood, speed: 40);
      }
      if (blood <= 0 && !dead && !type.undead) {
        blood = 0;
        _die();
        _onDeath();
      }
    }
    if (type.undead && !dead) {
      // slow regeneration
      for (var i = 0; i < 11; i++) {
        if (!severed[i] && limbHp[i] < limbMax[i]) limbHp[i] += dt * 2;
      }
    }
    if (dead && reanimate > 0) {
      reanimate -= dt;
      if (reanimate <= 0) _rise();
    }
    if (dead && held != null && sb.rng.nextDouble() < dt * 0.5) drop();

    _walkPhase += dt * (moveDir != 0 ? 9.0 * (type.speed / 120) : 0.0);

    _think -= dt;
    if (_think <= 0) {
      _think = 0.2 + sb.rng.nextDouble() * 0.1;
      _ai();
    }
    _act(dt);
  }

  void _rise() {
    type = HumanTypes.zombie.copyWith(
      skin: Color.lerp(type.skin, HumanTypes.zombie.skin, 0.7),
      shirt: type.shirt,
      pants: type.pants,
      hair: type.hair,
      hairStyle: type.hairStyle,
      scale: type.scale,
    );
    defIdOverride = 'zombie';
    dead = false;
    infected = false;
    for (var i = 0; i < 11; i++) {
      if (!severed[i]) limbHp[i] = limbMax[i] * 0.6;
    }
    if (limbHp[lHead] <= 0) limbHp[lHead] = 20;
    blood = 100;
    bleed = 0;
    stun = 0;
    Sfx.play('groan', vol: 0.8, rate: 0.6);
  }

  String? defIdOverride;

  bool _isEnemy(Human o) {
    if (identical(o, this) || o.dead || o.removed) return false;
    if (type.behavior == Behavior.berserk) return true;
    if (o.type.team == type.team) return false;
    // soldiers only fight things that are hostile, or hostile teams
    if (type.behavior == Behavior.soldier) {
      return o.type.behavior == Behavior.hostile ||
          o.type.behavior == Behavior.berserk ||
          (o.type.behavior == Behavior.soldier && o.type.team != type.team);
    }
    return true;
  }

  void _ai() {
    moveDir = 0;
    if (!conscious || dead) {
      target = null;
      return;
    }
    if (burning > 0 && !type.fireproof && type.behavior != Behavior.hostile) {
      panic = 1.5;
    }
    final b = type.behavior;
    final hx = particles[pN].x, hy = particles[pN].y;
    if (b == Behavior.hostile || b == Behavior.berserk || b == Behavior.soldier) {
      Human? best;
      var bd = 1600.0;
      for (final o in sb.humans) {
        if (!_isEnemy(o)) continue;
        final d = (o.cx - hx).abs() + (o.cy - hy).abs() * 1.5;
        if (d < bd) {
          bd = d;
          best = o;
        }
      }
      target = best;
    }
    if (panic > 0) {
      moveDir = sb.rng.nextBool() ? 1 : -1;
      if (_voiceCd <= 0 && type.bleeds) {
        _voiceCd = 2.5;
        Sfx.play('yell', vol: 0.35, rate: 0.9 + sb.rng.nextDouble() * 0.4 + (1 - type.scale) * 0.5);
      }
      return;
    }
    if (b == Behavior.coward) {
      Human? threat;
      var bd = 450.0;
      for (final o in sb.humans) {
        if (o.dead || identical(o, this)) continue;
        final hostile = o.type.behavior == Behavior.hostile || o.type.behavior == Behavior.berserk;
        if (!hostile || o.type.team == type.team) continue;
        final d = (o.cx - hx).abs();
        if (d < bd) {
          bd = d;
          threat = o;
        }
      }
      if (threat != null) moveDir = threat.cx < hx ? 1 : -1;
      return;
    }
    final t = target;
    if (t == null) return;
    final dx = t.particles[pN].x - hx;
    final hasGun = held is Shooter;
    if (b == Behavior.soldier && hasGun) {
      final want = dx > 0 ? 1 : -1;
      if (want != facing && _grounded()) flip();
      if (dx.abs() > 900) moveDir = want;
      return;
    }
    // melee approach
    final reach = 34 * s + (held != null ? 30 : 0);
    if (dx.abs() > reach) {
      moveDir = dx > 0 ? 1 : -1;
      if (moveDir != facing && _grounded()) flip();
    }
  }

  void _act(double dt) {
    final t = target;
    if (t == null || !conscious || dead || t.removed) return;
    final hand = particles[pHR];
    final sh = particles[pN];
    final tx = t.particles[pS].x, ty = t.particles[pS].y;
    final h = held;
    if (h is Shooter) {
      final sx = (h as Shooter);
      final aimX = t.particles[pN].x, aimY = t.particles[pN].y - 4;
      sx.aimAt(aimX, aimY, dt);
      final dx = aimX - sh.x, dy = aimY - sh.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 1400 && sx.aimError(aimX, aimY) < 0.12 && sb.lineOfSight(sh.x, sh.y - 5, aimX, aimY)) {
        sx.aiTrigger();
      }
      // raise the arm toward the target
      final ux = dx / math.max(1.0, d), uy = dy / math.max(1.0, d);
      final hx2 = sh.x + ux * 30 * s, hy2 = sh.y + uy * 30 * s;
      hand.ax += (hx2 - hand.x) * 900;
      hand.ay += (hy2 - hand.y) * 900;
      return;
    }
    // melee
    final dx = tx - sh.x, dy = ty - sh.y;
    final d = math.sqrt(dx * dx + dy * dy);
    final reach = 40 * s + (h != null ? 30 : 0);
    if (d < reach + 10 && _attackCd <= 0) {
      _attackCd = (h != null ? 0.7 : 0.9) / (type.speed / 120).clamp(0.6, 1.6);
      final ux = dx / math.max(1.0, d), uy = dy / math.max(1.0, d);
      // swing the hand forward hard
      hand.kick(ux * 6 * s, uy * 6 * s - 1);
      if (h == null) {
        // fists / bites
        final bite = type.infectious;
        final limbShape = _closestLimb(t, hand.x, hand.y);
        final dmg = (bite ? 12 : 8) * type.strength * (0.6 + 0.4 * s) * type.massMul;
        t.receiveHit(Hit(hand.x, hand.y, ux, uy, dmg, 900 * type.strength * type.scale,
            bite ? DmgType.sharp : DmgType.blunt,
            shape: limbShape, source: this));
        if (bite && !t.type.undead && !t.type.robotic && !t.type.skeleton) t.infected = true;
        Sfx.play(bite ? 'squish' : 'thud', vol: 0.6, rate: 1.2);
      }
    }
  }

  Shape _closestLimb(Human o, double x, double y) {
    Shape best = o.shapes[lUTorso];
    var bd = double.infinity;
    for (final sh in o.shapes) {
      final d = sh.distanceTo(x, y);
      if (d < bd) {
        bd = d;
        best = sh;
      }
    }
    return best;
  }

  // ------------------------------------------------------------------ render
  @override
  void render(Canvas c, RenderCtx r) {
    final ps = particles;
    final ice = frozenIce > 0;
    Color tint(Color col) {
      var x = darken(col, charred);
      if (ice) x = Color.lerp(x, const Color(0xFFBFE6FF), 0.55)!;
      return x;
    }

    final skin = tint(type.skin);
    final shirt = tint(type.shirt);
    final pants = tint(type.pants);
    final shoes = tint(type.shoes);
    final far = 0.82;
    Color dim(Color col) => Color.lerp(col, const Color(0xFF000000), 1 - far)!;

    void limb(int idx, Color col, {Color? armor}) {
      if (idx >= shapes.length) return;
      final sh = shapes[idx];
      final a = sh.pts[0], b = sh.pts[1];
      if (type.skeleton) {
        drawCapsule(c, a.x, a.y, b.x, b.y, sh.radius * 0.45, col, stroke: 1.2);
        return;
      }
      drawCapsule(c, a.x, a.y, b.x, b.y, sh.radius, col);
      if (armor != null) {
        final mx = a.x + (b.x - a.x) * 0.15, my = a.y + (b.y - a.y) * 0.15;
        final nx = a.x + (b.x - a.x) * 0.85, ny = a.y + (b.y - a.y) * 0.85;
        drawCapsule(c, mx, my, nx, ny, sh.radius + 1.6, armor, stroke: 1.2);
      }
    }

    final armorCol = tint(type.armorColor);
    Color? arm(double a) => a >= 0.3 ? armorCol : null;
    final sleeves = type.longSleeves;

    // far side (left limbs)
    limb(lULegL, dim(pants), armor: arm(type.armorLegs) == null ? null : dim(armorCol));
    limb(lLLegL, dim(pants), armor: arm(type.armorLegs) == null ? null : dim(armorCol));
    _foot(c, ps[pKL], ps[pFL], dim(shoes), lLLegL);
    limb(lUArmL, dim(shirt), armor: arm(type.armorArms) == null ? null : dim(armorCol));
    limb(lLArmL, dim(sleeves ? shirt : skin), armor: arm(type.armorArms) == null ? null : dim(armorCol));
    _hand(c, lLArmL, dim(skin));

    // torso
    limb(lLTorso, Color.lerp(shirt, pants, 0.35)!, armor: arm(type.armorTorso));
    limb(lUTorso, shirt, armor: arm(type.armorTorso));
    if (type.skeleton) _ribs(c);

    // head
    _head(c, skin);

    // near side
    limb(lULegR, pants, armor: arm(type.armorLegs));
    limb(lLLegR, pants, armor: arm(type.armorLegs));
    _foot(c, ps[pKR], ps[pFR], shoes, lLLegR);
    limb(lUArmR, shirt, armor: arm(type.armorArms));
    limb(lLArmR, sleeves ? shirt : skin, armor: arm(type.armorArms));
    _hand(c, lLArmR, skin);

    // wounds
    if (wounds.isNotEmpty && !type.robotic && !type.skeleton) {
      final wp = Paint()..color = Color.lerp(type.blood, const Color(0xFF000000), 0.35)!;
      for (final w in wounds) {
        if (w.limb >= shapes.length) continue;
        final sh = shapes[w.limb];
        final a = sh.pts[0], b = sh.pts[1];
        var nx = -(b.y - a.y), ny = b.x - a.x;
        final l = math.sqrt(nx * nx + ny * ny);
        if (l > 1e-6) {
          nx /= l;
          ny /= l;
        } else {
          nx = 0;
          ny = 0;
        }
        final x = a.x + (b.x - a.x) * w.t + nx * w.side * sh.radius;
        final y = a.y + (b.y - a.y) * w.t + ny * w.side * sh.radius;
        c.drawCircle(Offset(x, y), 1.8 * s, wp);
      }
    }
    if (r.selected) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / r.zoom
        ..color = const Color(0xFFE53935);
      c.drawCircle(Offset(ps[pH].x, ps[pH].y), 16 * s, p);
    }
  }

  void _foot(Canvas c, Particle knee, Particle foot, Color col, int limb) {
    if (type.skeleton) return;
    final dx = foot.x - knee.x, dy = foot.y - knee.y;
    final l = math.sqrt(dx * dx + dy * dy);
    if (l < 1e-6) return;
    // foot points perpendicular to the shin, toward facing
    final fx = -dy / l * facing, fy = dx / l * facing;
    final r = 4.0 * s;
    drawCapsule(c, foot.x, foot.y, foot.x + fx * 9 * s, foot.y + fy * 9 * s, r, col, stroke: 1.2);
  }

  void _hand(Canvas c, int limb, Color col) {
    final sh = shapes[limb];
    final p = sh.pts[1];
    final paint = Paint()..color = col;
    c.drawCircle(Offset(p.x, p.y), 4.6 * s, Paint()..color = outline);
    c.drawCircle(Offset(p.x, p.y), 3.6 * s, paint);
  }

  void _ribs(Canvas c) {
    final a = particles[pN], b = particles[pS];
    final p = Paint()
      ..color = type.skin
      ..strokeWidth = 1.6 * s
      ..style = PaintingStyle.stroke;
    for (var i = 1; i <= 4; i++) {
      final t = i / 5;
      final x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t;
      c.drawLine(Offset(x - 8 * s, y), Offset(x + 8 * s, y), p);
    }
  }

  void _head(Canvas c, Color skin) {
    final h = particles[pH];
    final n = particles[pN];
    final r = 11.0 * s;
    var ux = h.x - n.x, uy = h.y - n.y;
    final ul = math.sqrt(ux * ux + uy * uy);
    if (ul > 1e-6) {
      ux /= ul;
      uy /= ul;
    } else {
      ux = 0;
      uy = -1;
    }
    final ang = math.atan2(uy, ux) + math.pi / 2;
    c.save();
    c.translate(h.x, h.y);
    c.rotate(ang);
    if (facing < 0) c.scale(-1, 1);
    // now: up is -y, forward is +x
    final hairCol = darken(type.hair, charred);
    if (type.hairStyle == 2) {
      final p = Paint()..color = hairCol;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-r - 2, -r - 2, r * 1.4, r * 2.4), Radius.circular(r)), p);
    }
    c.drawCircle(Offset.zero, r + 1.6, Paint()..color = outline);
    c.drawCircle(Offset.zero, r, Paint()..color = skin);
    final hp = Paint()..color = hairCol;
    switch (type.hairStyle) {
      case 1:
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r + 0.5), math.pi * 1.0, math.pi * 1.05, true, hp);
        break;
      case 2:
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r + 0.5), math.pi * 0.9, math.pi * 1.2, true, hp);
        break;
      case 3:
        c.drawRect(Rect.fromLTWH(-3 * s, -r - 6 * s, 6 * s, 9 * s), hp);
        break;
      case 4:
        c.drawArc(Rect.fromCircle(center: const Offset(0, -1), radius: r + 2.5), math.pi, math.pi, true, hp);
        c.drawRect(Rect.fromLTWH(-r - 2, -2, r * 2 + 8, 2.5 * s), hp);
        break;
      case 5:
        c.drawArc(Rect.fromCircle(center: Offset.zero, radius: r + 2.5), math.pi * 0.75, math.pi * 1.4, true, hp);
        break;
      case 6:
        final path = Path()
          ..moveTo(-7 * s, -r + 2)
          ..lineTo(-7 * s, -r - 7 * s)
          ..lineTo(-3.5 * s, -r - 2 * s)
          ..lineTo(0, -r - 8 * s)
          ..lineTo(3.5 * s, -r - 2 * s)
          ..lineTo(7 * s, -r - 7 * s)
          ..lineTo(7 * s, -r + 2)
          ..close();
        c.drawPath(path, hp);
        break;
      case 7:
        c.drawCircle(Offset.zero, r + 2.2, hp);
        break;
    }
    // face
    final eye = Paint()..color = const Color(0xFF111111);
    final ex = r * 0.45, ey = -r * 0.1;
    switch (type.face) {
      case Face.visor:
        final vp = Paint()..color = dead ? const Color(0xFF222222) : const Color(0xFF55C7FF);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r * 0.05, -r * 0.4, r * 0.95, r * 0.5), Radius.circular(3 * s)), vp);
        break;
      case Face.mask:
        final maskP = Paint()..color = const Color(0xFF111111);
        c.drawRect(Rect.fromLTWH(-r * 0.2, -r * 0.35, r * 1.2, r * 0.42), maskP);
        if (!dead) {
          final ep = Paint()..color = const Color(0xFFEEEEEE);
          c.drawCircle(Offset(ex, ey - 1), 1.6 * s, ep);
        }
        break;
      default:
        if (dead) {
          final xp = Paint()
            ..color = const Color(0xFF111111)
            ..strokeWidth = 1.4 * s;
          for (final ox in [ex - 3.5 * s, ex + 2.5 * s]) {
            c.drawLine(Offset(ox - 1.5 * s, ey - 1.5 * s), Offset(ox + 1.5 * s, ey + 1.5 * s), xp);
            c.drawLine(Offset(ox - 1.5 * s, ey + 1.5 * s), Offset(ox + 1.5 * s, ey - 1.5 * s), xp);
          }
        } else if (!conscious) {
          final lp = Paint()
            ..color = const Color(0xFF111111)
            ..strokeWidth = 1.2 * s;
          c.drawLine(Offset(ex - 5 * s, ey), Offset(ex - 2 * s, ey), lp);
          c.drawLine(Offset(ex + 1 * s, ey), Offset(ex + 4 * s, ey), lp);
        } else {
          if (type.face == Face.alien) {
            c.drawOval(Rect.fromCenter(center: Offset(ex, ey), width: 6 * s, height: 4 * s), eye);
          } else if (type.face == Face.skull) {
            c.drawCircle(Offset(ex - 1, ey), 2.6 * s, eye);
            c.drawCircle(Offset(ex + 4.5 * s, ey), 2.2 * s, eye);
          } else {
            final ec = type.face == Face.zombie ? const Color(0xFFE8E04A) : const Color(0xFF111111);
            final ep = Paint()..color = ec;
            c.drawCircle(Offset(ex - 2.5 * s, ey), 1.4 * s, ep);
            c.drawCircle(Offset(ex + 3 * s, ey), 1.4 * s, ep);
          }
        }
        // mouth
        final mouthP = Paint()
          ..color = const Color(0xFF3A1A1A)
          ..strokeWidth = 1.1 * s;
        if (panic > 0 && !dead) {
          c.drawCircle(Offset(ex + 1 * s, r * 0.45), 2 * s, Paint()..color = const Color(0xFF3A1A1A));
        } else {
          c.drawLine(Offset(ex - 1 * s, r * 0.45), Offset(ex + 3 * s, r * 0.45), mouthP);
        }
    }
    c.restore();
  }

  // ------------------------------------------------------------------ save
  @override
  Map<String, dynamic> saveData() => {
        'type': type.id,
        if (customCfg != null) 'cfg': customCfg,
        'facing': facing,
        'hp': limbHp.map((v) => (v * 10).roundToDouble() / 10).toList(),
        'blood': blood,
        'bleed': bleed,
        'dead': dead,
        'sev': severOrder,
        'inf': infected,
        'zomb': defIdOverride != null,
        'wounds': [
          for (final w in wounds.take(40)) [w.limb, w.t, w.side]
        ],
      };

  @override
  void loadData(Map<String, dynamic> d) {
    final f = (d['facing'] as num?)?.toInt() ?? 1;
    if (f != facing) flip();
    final hp = d['hp'] as List?;
    if (hp != null && hp.length == 11) {
      for (var i = 0; i < 11; i++) {
        limbHp[i] = (hp[i] as num).toDouble();
      }
    }
    blood = (d['blood'] as num?)?.toDouble() ?? 100;
    bleed = (d['bleed'] as num?)?.toDouble() ?? 0;
    infected = d['inf'] == true;
    for (final l in (d['sev'] as List? ?? const [])) {
      final li = (l as num).toInt();
      if (li >= 0 && li < 11) sever(li);
    }
    if (d['zomb'] == true) {
      type = HumanTypes.zombie.copyWith(
          shirt: type.shirt, pants: type.pants, hair: type.hair, hairStyle: type.hairStyle, scale: type.scale);
      defIdOverride = 'zombie';
    }
    if (d['dead'] == true) _die();
    for (final w in (d['wounds'] as List? ?? const [])) {
      final l = w as List;
      if (l.length == 3) {
        wounds.add(Wound((l[0] as num).toInt(), (l[1] as num).toDouble(), (l[2] as num).toDouble()));
      }
    }
  }
}

/// Things a human can aim and fire.
abstract class Shooter {
  void aimAt(double x, double y, double dt);
  double aimError(double x, double y);
  void aiTrigger();
}

/// Held items that track mirroring when their holder turns around.
abstract class Flippable {
  bool mirrored = false;
}
