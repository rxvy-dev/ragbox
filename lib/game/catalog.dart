import 'dart:ui';

import 'entity.dart';
import 'human.dart';
import 'machines.dart';
import 'props.dart';
import 'weapons.dart';

typedef EntityBuilder = Entity Function(double x, double y, Map<String, dynamic>? data);

class ItemDef {
  final String id;
  final String name;
  final String category;
  final String desc;
  final EntityBuilder build;
  final bool hidden;
  const ItemDef(this.id, this.name, this.category, this.desc, this.build, {this.hidden = false});
}

class Cat {
  static const humans = 'Humans';
  static const guns = 'Firearms';
  static const energy = 'Energy Weapons';
  static const melee = 'Melee';
  static const explosives = 'Explosives';
  static const props = 'Props';
  static const vehicles = 'Vehicles';
  static const machines = 'Machines';
  static const electric = 'Electrical';
  static const traps = 'Traps';
  static const build = 'Construction';
  static const custom = 'Custom';
  static const order = [humans, custom, guns, energy, melee, explosives, vehicles, machines, electric, traps, props, build];
}

Color _c(Map<String, dynamic>? d, String k, Color def) {
  final v = d?[k];
  return v is num ? Color(v.toInt()) : def;
}

double _n(Map<String, dynamic>? d, String k, double def) {
  final v = d?[k];
  return v is num ? v.toDouble() : def;
}

class Catalog {
  static final Map<String, ItemDef> _byId = {};
  static final List<ItemDef> items = [];

  static ItemDef? byId(String id) {
    if (_byId.isEmpty) _init();
    return _byId[id];
  }

  static List<ItemDef> get visible {
    if (_byId.isEmpty) _init();
    return items.where((i) => !i.hidden).toList();
  }

  static void _add(ItemDef d) {
    items.add(d);
    _byId[d.id] = d;
  }

  static void _init() {
    // Humans
    for (final t in HumanTypes.all) {
      final defId = 'h_${t.id}';
      _add(ItemDef(defId, t.name, Cat.humans, t.desc,
          (x, y, d) => Human(x, y + 88 * t.scale, t, defId: defId)));
    }
    _add(ItemDef('custom', 'Custom Character', Cat.custom, 'Made in the character editor.', (x, y, d) {
      final cfg = (d?['cfg'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
      final t = HumanTypes.fromConfig(cfg);
      return Human(x, y + 88 * t.scale, t, defId: 'custom', customCfg: cfg);
    }, hidden: true));

    // Guns
    for (final g in Guns.all) {
      final energy = g.proj != Proj.bullet;
      _add(ItemDef(g.id, g.name, energy ? Cat.energy : Cat.guns, g.desc, (x, y, d) => Gun(g, x, y)));
    }
    // Melee
    for (final m in Melees.all) {
      _add(ItemDef(m.id, m.name, Cat.melee, m.desc, (x, y, d) => Melee(m, x, y)));
    }
    // Explosives
    const bombs = [
      [BombKind.grenade, 'Grenade', 'Activate to pull the pin. 3 second fuse.'],
      [BombKind.cluster, 'Cluster Bomb', 'Bursts into sticky bomblets.'],
      [BombKind.dynamite, 'Dynamite', 'Light it (activate or fire). 4 second fuse.'],
      [BombKind.c4, 'C4 Charge', 'Detonates when activated or powered by a wire.'],
      [BombKind.sticky, 'Sticky Bomb', 'Arms on activate, sticks to what it touches.'],
      [BombKind.mine, 'Landmine', 'Explodes when something hits it. Activate to disarm.'],
      [BombKind.molotov, 'Fire Bottle', 'Shatters into a pool of flames.'],
      [BombKind.barrel, 'Explosive Barrel', 'Goes up when shot, burned or hit hard.'],
      [BombKind.gas, 'Gas Canister', 'Pressurised and touchy.'],
      [BombKind.firework, 'Firework', 'Light it and stand back.'],
      [BombKind.holy, 'Holy Grenade', 'Enormous blast. Count to three.'],
      [BombKind.nuke, 'Tactical Nuke', 'Do not activate.'],
    ];
    for (final b in bombs) {
      final kind = b[0] as BombKind;
      final id = 'bomb_${kind.name}';
      final name = b[1] as String;
      _add(ItemDef(id, name, Cat.explosives, b[2] as String, (x, y, d) => Bomb(kind, x, y, id, name)));
    }
    // Vehicles
    const vehicles = [
      [VehicleKind.car, 'Car', 'Activate to start the engine.'],
      [VehicleKind.truck, 'Pickup Truck', 'Heavy and powerful.'],
      [VehicleKind.buggy, 'Dune Buggy', 'Light and bouncy.'],
      [VehicleKind.monster, 'Monster Truck', 'Huge wheels, climbs anything.'],
      [VehicleKind.bike, 'Motorbike', 'Two wheels of balance trouble.'],
      [VehicleKind.bus, 'Bus', 'Long and heavy.'],
      [VehicleKind.tank, 'Tank', 'Activate fires the cannon; power it with a wire to drive.'],
      [VehicleKind.cart, 'Cart', 'Unpowered cart for pushing things around.'],
    ];
    for (final v in vehicles) {
      final kind = v[0] as VehicleKind;
      final id = 'veh_${kind.name}';
      _add(ItemDef(id, v[1] as String, Cat.vehicles, v[2] as String, (x, y, d) => Vehicle(kind, x, y, id)));
    }
    // Machines
    _add(ItemDef('thruster', 'Thruster', Cat.machines, 'Pushes forward when on. Weld it to things.',
        (x, y, d) => Thruster(x, y)));
    _add(ItemDef('thruster_big', 'Big Thruster', Cat.machines, 'A much stronger thruster.',
        (x, y, d) => Thruster(x, y, big: true)));
    _add(ItemDef('motor', 'Motor Wheel', Cat.machines, 'Spinning wheel on a fixed axle.',
        (x, y, d) => MotorWheel(x, y)));
    _add(ItemDef('piston', 'Piston', Cat.machines, 'Extends while on.', (x, y, d) => Piston(x, y)));
    _add(ItemDef('press', 'Hydraulic Press', Cat.machines, 'Slow, heavy, crushes what is in front.',
        (x, y, d) => Piston(x, y, press: true)));
    _add(ItemDef('fan', 'Industrial Fan', Cat.machines, 'Blows things away when on.', (x, y, d) => Fan(x, y)));
    _add(ItemDef('magnet', 'Electromagnet', Cat.machines, 'Pulls metal objects when on.', (x, y, d) => Magnet(x, y)));
    _add(ItemDef('conveyor', 'Conveyor Belt', Cat.machines, 'Moves anything on top of it.',
        (x, y, d) => Conveyor(x, y)));
    _add(ItemDef('launchpad', 'Launch Pad', Cat.machines, 'Throws anything standing on it into the air.',
        (x, y, d) => LaunchPad(x, y)));
    _add(ItemDef('antigrav', 'Anti-Gravity Field', Cat.machines, 'Things float inside the field while on.',
        (x, y, d) => GravityField(x, y)));
    _add(ItemDef('singularity', 'Singularity Core', Cat.machines, 'Pulls in and erases everything nearby.',
        (x, y, d) => GravityField(x, y, singularity: true)));
    _add(ItemDef('balloon', 'Balloon', Cat.machines, 'Rope it to something to lift it.',
        (x, y, d) => Balloon(x, y, _c(d, 'c', const [
              Color(0xFFE53935),
              Color(0xFF1E88E5),
              Color(0xFFFDD835),
              Color(0xFF43A047),
              Color(0xFF8E24AA)
            ][(x.abs() ~/ 7) % 5]))));
    _add(ItemDef('chain', 'Chain', Cat.machines, 'Heavy swinging chain.', (x, y, d) => Chain(x, y)));
    // Electrical
    const elec = [
      [ElecKind.battery, 'battery', 'Power source. Wire it to machines. Activate to switch off.'],
      [ElecKind.generator, 'generator', 'Big power source.'],
      [ElecKind.button, 'button', 'Sends a short pulse when pressed or hit.'],
      [ElecKind.toggle, 'switch', 'Flip on/off.'],
      [ElecKind.timer, 'timer', 'Pulses on a schedule. Activate to change the interval.'],
      [ElecKind.sensor, 'sensor', 'On while a person is nearby.'],
      [ElecKind.tripwire, 'tripwire', 'On while its beam is blocked.'],
      [ElecKind.plate, 'plate', 'On while something rests on it.'],
      [ElecKind.logicNot, 'not', 'Outputs power only when NOT powered.'],
      [ElecKind.lamp, 'lamp', 'Glows when powered.'],
      [ElecKind.siren, 'siren', 'Flashes and beeps when powered.'],
      [ElecKind.shockPad, 'shockpad', 'Electrocutes people standing on it when powered.'],
      [ElecKind.tesla, 'tesla', 'Throws lightning at people and metal when powered.'],
    ];
    for (final e in elec) {
      final kind = e[0] as ElecKind;
      final id = 'el_${e[1]}';
      final sample = Electric(kind, 0, 0, id);
      _add(ItemDef(id, sample.name, kind == ElecKind.shockPad || kind == ElecKind.tesla ? Cat.traps : Cat.electric,
          e[2] as String, (x, y, d) => Electric(kind, x, y, id)));
    }
    // Traps
    _add(ItemDef('sawblade', 'Saw Blade', Cat.traps, 'Spinning blade on a fixed axle.',
        (x, y, d) => MotorWheel(x, y, saw: true)));
    _add(ItemDef('spiketrap', 'Spike Trap', Cat.traps, 'Impales anything that lands on it.',
        (x, y, d) => SpikeTrap(x, y)));
    _add(ItemDef('beartrap', 'Bear Trap', Cat.traps, 'Clamps onto legs. Activate to reopen.',
        (x, y, d) => BearTrap(x, y)));
    _add(ItemDef('burner', 'Gas Burner', Cat.traps, 'Shoots flames upward when on.', (x, y, d) => Burner(x, y)));
    _add(ItemDef('turret', 'Sentry Turret', Cat.traps, 'Shoots hostile creatures. Activate to toggle.',
        (x, y, d) => Turret(x, y)));
    // Props
    for (final p in Props.all) {
      _add(ItemDef(p.id, p.name, Cat.props, _propDesc(p), (x, y, d) => Prop(p, x, y)));
    }
    _add(ItemDef('frag', 'Debris', Cat.props, '', (x, y, d) {
      final parent = Props.byId(d?['of'] as String? ?? 'crate') ?? Props.all.first;
      return Prop(Prop.fragDef(parent), x, y,
          defId: 'frag', w: _n(d, 'w', 20), h: _n(d, 'h', 20), color: _c(d, 'c', matInfo[parent.mat]!.color))
        ..fragOf = parent.id;
    }, hidden: true));
    // Construction
    _add(ItemDef('wall_floor', 'Floor Slab', Cat.build, 'Static 400×30 slab. Never moves.',
        (x, y, d) => Block(x, y, _n(d, 'w', 400), _n(d, 'h', 30), isStatic: true)));
    _add(ItemDef('wall_pillar', 'Pillar', Cat.build, 'Static 30×300 pillar.',
        (x, y, d) => Block(x, y, _n(d, 'w', 30), _n(d, 'h', 300), isStatic: true)));
    _add(ItemDef('wall_ramp', 'Ramp', Cat.build, 'Static angled ramp.', (x, y, d) {
      return Block(x, y, _n(d, 'w', 300), _n(d, 'h', 24), isStatic: true, rot: -0.35);
    }));
    _add(ItemDef('wall', 'Wall', Cat.build, 'Static block (also made with the Build tool).',
        (x, y, d) => Block(x, y, _n(d, 'w', 120), _n(d, 'h', 120),
            isStatic: true,
            mat: Mat.values[_n(d, 'mat', Mat.stone.index.toDouble()).toInt().clamp(0, Mat.values.length - 1)],
            color: d?['c'] is num ? Color((d!['c'] as num).toInt()) : null),
        hidden: true));
    _add(ItemDef('block', 'Block', Cat.build, 'Dynamic block (made with the Build tool).',
        (x, y, d) => Block(x, y, _n(d, 'w', 80), _n(d, 'h', 80),
            isStatic: false,
            mat: Mat.values[_n(d, 'mat', Mat.wood.index.toDouble()).toInt().clamp(0, Mat.values.length - 1)],
            color: d?['c'] is num ? Color((d!['c'] as num).toInt()) : null)));
    _add(ItemDef('metal_block', 'Metal Block', Cat.build, 'Heavy dynamic steel block.',
        (x, y, d) => Block(x, y, _n(d, 'w', 80), _n(d, 'h', 80), mat: Mat.metal)));
    // Projectiles (only for save files)
    for (final k in MissileKind.values) {
      _add(ItemDef('missile_${k.name}', k.name, Cat.guns, '', (x, y, d) => Missile(k, x, y, 0), hidden: true));
    }
  }

  static String _propDesc(PropDef p) {
    final m = p.mat.name;
    return p.hp > 0 ? 'Breakable $m object.' : 'Solid $m object.';
  }
}
