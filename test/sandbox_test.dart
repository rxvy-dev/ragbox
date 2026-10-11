import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ragbox/engine/physics.dart';
import 'package:ragbox/game/catalog.dart';
import 'package:ragbox/game/human.dart';
import 'package:ragbox/game/maps.dart';
import 'package:ragbox/game/props.dart';
import 'package:ragbox/game/sandbox.dart';
import 'package:ragbox/game/weapons.dart';

void run(Sandbox sb, double seconds) {
  final steps = (seconds * 60).round();
  for (var i = 0; i < steps; i++) {
    sb.update(1 / 60);
  }
}

bool finite(Sandbox sb) => sb.world.particles.every((p) => p.x.isFinite && p.y.isFinite);

void main() {
  test('a crate falls and comes to rest on the floor', () {
    final sb = Sandbox(GameMaps.byId('flat'));
    final crate = sb.spawn('crate', 0, -400)!;
    run(sb, 4);
    expect(finite(sb), isTrue);
    // floor top is y = 0, crate is 50 tall
    expect(crate.cy, greaterThan(-40));
    expect(crate.cy, lessThan(5));
    expect(crate.vy.abs(), lessThan(1.0));
  });

  test('every catalog item can be spawned and simulated', () {
    final sb = Sandbox(GameMaps.byId('flat'));
    sb.maxEntities = 1000;
    var x = -2800.0;
    for (final item in Catalog.visible) {
      final e = sb.spawn(item.id, x, -300);
      expect(e, isNotNull, reason: item.id);
      x += 45;
      if (x > 2800) x = -2800;
    }
    run(sb, 1);
    expect(finite(sb), isTrue);
  });

  test('every item can be activated without errors', () {
    final sb = Sandbox(GameMaps.byId('arena'));
    sb.maxEntities = 1000;
    var x = -2000.0;
    final spawned = [];
    for (final item in Catalog.visible) {
      if (item.id == 'bomb_nuke') continue;
      spawned.add(sb.spawn(item.id, x, -300));
      x += 40;
    }
    run(sb, 0.5);
    for (final e in spawned) {
      if (e != null && !e.removed) e.use();
    }
    run(sb, 2);
    expect(finite(sb), isTrue);
  });

  test('humans stand up and can be shot', () {
    final sb = Sandbox(GameMaps.byId('flat'));
    final h = sb.spawn('h_human', 0, -100) as Human;
    run(sb, 3);
    expect(finite(sb), isTrue);
    expect(h.dead, isFalse);
    final gun = sb.spawn('sniper', -400, h.particles[pH].y) as Gun;
    run(sb, 0.02);
    // aim straight at the head
    sb.fireBullet(-300, h.particles[pH].y, 1, 0, damage: 200, source: gun);
    run(sb, 0.5);
    expect(h.dead, isTrue);
  });

  test('explosions throw things and hurt people', () {
    final sb = Sandbox(GameMaps.byId('flat'));
    final h = sb.spawn('h_human', 60, -100) as Human;
    run(sb, 1);
    final before = h.health;
    sb.explode(0, -20, 200, 3000, damage: 150);
    run(sb, 0.5);
    expect(h.health, lessThan(before));
    expect(finite(sb), isTrue);
  });

  test('scenes survive a save and load round trip', () {
    final sb = Sandbox(GameMaps.byId('city'));
    final a = sb.spawn('crate', 0, -500)!;
    final b = sb.spawn('h_soldier', 100, -500) as Human;
    final g = sb.spawn('rifle', 140, -500)!;
    sb.spawn('el_battery', 300, -500);
    sb.spawn('el_lamp', 360, -500);
    sb.addJoint(JointType.rope, a, 0, null, 0, anchorX: 0, anchorY: -800);
    b.grab(g);
    b.sever(lUArmL);
    sb.addLink(sb.entities[4], sb.entities[5]);
    run(sb, 1);
    final json = jsonEncode(sb.toJson(name: 'test'));
    final sb2 = Sandbox(GameMaps.byId('flat'));
    sb2.loadJson(jsonDecode(json) as Map<String, dynamic>);
    expect(sb2.map.id, 'city');
    expect(sb2.dynamicCount, sb.dynamicCount);
    expect(sb2.joints.length, sb.joints.length);
    expect(sb2.links.length, 1);
    final b2 = sb2.humans.first;
    expect(b2.severed[lUArmL], isTrue);
    expect(b2.held, isNotNull);
    run(sb2, 1);
    expect(finite(sb2), isTrue);
  });

  test('power flows from a battery to a lamp through a wire', () {
    final sb = Sandbox(GameMaps.byId('flat'));
    final bat = sb.spawn('el_battery', 0, -50)!;
    final lamp = sb.spawn('el_lamp', 100, -50)!;
    sb.addLink(bat, lamp);
    run(sb, 0.1);
    expect(lamp.powered, isTrue);
    bat.use(); // switch off
    run(sb, 0.1);
    expect(lamp.powered, isFalse);
  });

  test('glass breaks into pieces when hit hard', () {
    final sb = Sandbox(GameMaps.byId('flat'));
    final glass = sb.spawn('window', 0, -60) as Prop;
    run(sb, 0.05);
    sb.fireBullet(-300, -60, 1, 0, damage: 100);
    run(sb, 0.2);
    expect(glass.removed, isTrue);
  });

  test('raycast hits a box', () {
    final w = PhysicsWorld();
    final ps = [Particle(-10, -10, 1), Particle(10, -10, 1), Particle(10, 10, 1), Particle(-10, 10, 1)];
    final s = Shape.poly(ps);
    w.addShape(s);
    s.computeAabb(0);
    final hits = w.raycast(-100, 0, 1, 0, 500);
    expect(hits.length, 1);
    expect(hits.first.t, closeTo(90, 0.5));
  });
}
