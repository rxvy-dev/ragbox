import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/errors.dart';
import '../core/sfx.dart';
import '../core/storage.dart';
import '../engine/physics.dart';
import '../game/catalog.dart';
import '../game/entity.dart';
import '../game/human.dart';
import '../game/maps.dart';
import '../game/props.dart';
import '../game/sandbox.dart';
import '../game/weapons.dart';
import 'saves_screen.dart';
import 'spawn_sheet.dart';
import 'theme.dart';
import 'world_painter.dart';

enum Tool { drag, use, rope, spring, weld, pin, wire, build, fire, explode, cut, heal, delete }

class ToolInfo {
  final Tool tool;
  final IconData icon;
  final String name;
  final String hint;
  const ToolInfo(this.tool, this.icon, this.name, this.hint);
}

const tools = [
  ToolInfo(Tool.drag, Icons.pan_tool_alt, 'Drag', 'Drag objects. Tap to select. Drag empty space to pan.'),
  ToolInfo(Tool.use, Icons.touch_app, 'Use', 'Tap an object to activate it (fire guns, light fuses, start engines).'),
  ToolInfo(Tool.rope, Icons.timeline, 'Rope', 'Tap two objects to tie them. Tap empty space second to hang from the world.'),
  ToolInfo(Tool.spring, Icons.waves, 'Spring', 'Tap two objects to join them with a spring.'),
  ToolInfo(Tool.weld, Icons.link, 'Weld', 'Tap two objects to fuse them together.'),
  ToolInfo(Tool.pin, Icons.push_pin, 'Pin', 'Tap an object to nail it to the background.'),
  ToolInfo(Tool.wire, Icons.cable, 'Wire', 'Tap two devices to wire them. Power flows from sources to machines.'),
  ToolInfo(Tool.build, Icons.crop_square, 'Build', 'Drag to draw a block.'),
  ToolInfo(Tool.fire, Icons.local_fire_department, 'Fire', 'Tap to set things on fire.'),
  ToolInfo(Tool.explode, Icons.flare, 'Blast', 'Tap anywhere to cause an explosion.'),
  ToolInfo(Tool.cut, Icons.content_cut, 'Cut', 'Tap ropes, wires and joints to cut them, or limbs to sever them.'),
  ToolInfo(Tool.heal, Icons.healing, 'Heal', 'Tap a person to fully heal or revive them. Repairs objects.'),
  ToolInfo(Tool.delete, Icons.delete_forever, 'Delete', 'Tap an object to remove it.'),
];

class GameScreen extends StatefulWidget {
  final GameMap map;
  final String? sceneId;
  const GameScreen({super.key, required this.map, this.sceneId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late Sandbox sb;
  final Camera cam = Camera();
  late Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  Tool tool = Tool.drag;
  SpawnChoice? pending;
  String? sceneId;
  String sceneName = 'Untitled';
  Timer? _autosave;
  double _fps = 60;
  bool _hint = true;
  bool _camReady = false;
  final ValueNotifier<String?> _error = ValueNotifier(null);

  // touch state
  final Map<int, Offset> _ptrs = {};
  int? _p1, _p2;
  Offset _p1Start = Offset.zero;
  final Stopwatch _p1Clock = Stopwatch();
  bool _moved = false;
  bool _multi = false;
  int _mode = 0; // 0 pending, 1 pan, 2 drag, 3 move frozen, 4 build, 5 pinch
  DragHandle? _drag;
  Entity? _dragEntity;
  double _dragOffX = 0, _dragOffY = 0;
  double _lastWX = 0, _lastWY = 0;
  double _pinchD0 = 1, _pinchZoom0 = 1, _pinchWX = 0, _pinchWY = 0;
  // second-finger aiming
  bool _aiming = false;
  Entity? _aimItem;
  double _aimWX = 0, _aimWY = 0;
  bool _aimShotPending = false;
  double _aimShotDelay = 0;
  Offset? _buildA, _buildB;
  bool buildStatic = true;
  int buildMat = 0;
  static const buildMats = [Mat.stone, Mat.wood, Mat.metal, Mat.glass, Mat.ice, Mat.rubber];

  // two-step tools
  Entity? _pickA;
  int _pickIdx = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      sb = Sandbox(widget.map);
    } catch (e, st) {
      Errors.record(e, st, where: 'map ${widget.map.id}');
      sb = Sandbox(GameMaps.byId('flat'));
    }
    _applySettings();
    sceneId = widget.sceneId;
    if (sceneId != null) {
      final j = Storage.readScene(sceneId!);
      if (j != null) {
        try {
          sb.loadJson(j);
          sceneName = j['name'] as String? ?? 'Untitled';
          final c = j['cam'] as List?;
          if (c != null && c.length == 3) {
            final x = (c[0] as num).toDouble(), y = (c[1] as num).toDouble(), z = (c[2] as num).toDouble();
            if (x.isFinite && y.isFinite && z.isFinite) {
              cam.x = x;
              cam.y = y;
              cam.zoom = z.clamp(0.12, 3.0);
              _camReady = true;
            }
          }
        } catch (e, st) {
          Errors.record(e, st, where: 'load scene');
          sb = Sandbox(widget.map);
        }
        _applySettings();
        if (sceneId == Storage.autosaveId) sceneId = null;
      }
    } else {
      cam.y = sb.map.spawnY;
    }
    sb.onRumble = (s) {
      if (Storage.settings.haptics) {
        if (s > 0.6) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      }
    };
    _hint = Storage.settings.showHints;
    _ticker = createTicker(_tick)..start();
    if (Storage.settings.autosave) {
      _autosave = Timer.periodic(Duration(seconds: Storage.settings.autosaveSeconds.clamp(15, 600)), (_) => _doAutosave());
    }
    if (_hint) {
      // show the quick guide once; it can be re-enabled in Settings
      Storage.settings.showHints = false;
      Storage.saveSettings();
      Future.delayed(const Duration(seconds: 12), () {
        if (mounted && _hint) setState(() => _hint = false);
      });
    }
  }

  void _applySettings() {
    final s = Storage.settings;
    sb.world.iterations = s.iterations;
    sb.fx.gore = s.gore;
    sb.maxEntities = s.maxEntities;
    Sfx.volume = s.volume;
    Sfx.enabled = s.sound;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    _ticker.dispose();
    _frame.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _doAutosave();
    }
  }

  void _reportError(String where, Object e, StackTrace st) {
    if (_error.value != null) return;
    final first = st.toString().split('\n').take(3).join(' | ');
    // ignore: avoid_print
    print('Ragbox $where error: $e\n$st');
    _error.value = '$where: $e  ($first)';
    Errors.record(e, st, where: where);
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 0) _fps = _fps * 0.95 + (1 / dt) * 0.05;
    _updateAim(dt);
    try {
      sb.update(dt);
    } catch (e, st) {
      _reportError('update', e, st);
    }
    if (_drag != null && _dragEntity != null && _dragEntity!.removed) _endDrag();
    _frame.value++;
  }

  Map<String, dynamic> _sceneJson(String name) => sb.toJson(name: name, camX: cam.x, camY: cam.y, zoom: cam.zoom);

  void _doAutosave() {
    if (!Storage.settings.autosave) return;
    try {
      Storage.writeScene(Storage.autosaveId, _sceneJson('Autosave'));
    } catch (_) {}
  }

  Future<ui.Image?> _thumbImage() async {
    try {
      const w = 320.0, h = 180.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final tc = Camera()
        ..x = cam.x
        ..y = cam.y
        ..zoom = cam.zoom * w / math.max(1.0, _size.width);
      paintWorld(c, const Size(w, h), sb, tc, showWires: false);
      return await rec.endRecording().toImage(w.toInt(), h.toInt());
    } catch (_) {
      return null;
    }
  }

  Future<void> _save({bool asNew = false}) async {
    var name = sceneName;
    if (sceneId == null || asNew) {
      final n = await _askName(asNew ? 'Save as' : 'Save scene', sceneName == 'Untitled' ? '' : sceneName);
      if (n == null) return;
      name = n.isEmpty ? 'Untitled' : n;
      sceneId = Storage.newId();
    }
    sceneName = name;
    final img = await _thumbImage();
    final bytes = img == null ? null : await img.toByteData(format: ui.ImageByteFormat.png);
    Storage.writeScene(sceneId!, _sceneJson(name), thumb: bytes?.buffer.asUint8List());
    if (mounted) _toast('Saved "$name"');
  }

  Future<String?> _askName(String title, String initial) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: RB.panel,
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Scene name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1400), behavior: SnackBarBehavior.floating));
  }

  // ------------------------------------------------------------------ input
  double _wx(Offset p) => cam.toWorldX(p.dx, _size);
  double _wy(Offset p) => cam.toWorldY(p.dy, _size);

  // ---------------------------------------------------------------------
  // Touch input. Raw pointers are used (not a scale gesture) so that a
  // second finger can aim and fire a held weapon, Melon Sandbox style,
  // while the first finger keeps holding it. With nothing held, two
  // fingers pinch-zoom.

  void _onDown(PointerDownEvent e) {
    if (_hint) setState(() => _hint = false);
    final pos = e.localPosition;
    _ptrs[e.pointer] = pos;
    if (_p1 == null) {
      _p1 = e.pointer;
      _p1Start = pos;
      _p1Clock
        ..reset()
        ..start();
      _moved = false;
      _multi = false;
      _beginPrimary(pos);
    } else if (_p2 == null) {
      _p2 = e.pointer;
      _multi = true;
      final d = _dragEntity;
      if ((_mode == 2 || _mode == 3) && d != null && !d.removed) {
        _startAim(pos);
      } else {
        _startPinch();
      }
    }
  }

  void _beginPrimary(Offset p) {
    _mode = 0;
    if (pending != null) return; // lifting the finger will place the item
    final wx = _wx(p), wy = _wy(p);
    if (tool == Tool.build) {
      _mode = 4;
      _buildA = Offset(wx, wy);
      _buildB = _buildA;
      return;
    }
    if (tool != Tool.drag && tool != Tool.use && tool != Tool.heal) return;
    final shape = sb.shapeAt(wx, wy, pad: 18 / cam.zoom);
    final e = shape?.owner;
    if (shape == null || e is! Entity || e is MapEntity) return;
    sb.selected = e;
    final anchored = e.frozen || e.particles.any((q) => q.invMass == 0);
    _dragEntity = e;
    if (anchored) {
      _mode = 3;
      _lastWX = wx;
      _lastWY = wy;
      return;
    }
    // grab the particle of the touched shape nearest to the finger
    Particle best = shape.pts.first;
    var bd = double.infinity;
    for (final q in shape.pts) {
      final dd = (q.x - wx) * (q.x - wx) + (q.y - wy) * (q.y - wy);
      if (dd < bd) {
        bd = dd;
        best = q;
      }
    }
    _dragOffX = best.x - wx;
    _dragOffY = best.y - wy;
    _drag = DragHandle(best, wx + _dragOffX, wy + _dragOffY, strength: e is Human ? 0.3 : 0.35);
    sb.world.drags.add(_drag!);
    _mode = 2;
  }

  void _onMove(PointerMoveEvent e) {
    final pos = e.localPosition;
    final prev = _ptrs[e.pointer];
    _ptrs[e.pointer] = pos;
    if (e.pointer == _p1) {
      if (!_moved && (pos - _p1Start).distance > 12) _moved = true;
      switch (_mode) {
        case 0:
          if (_moved && pending == null) _mode = 1;
          break;
        case 1:
          if (prev != null) {
            cam.x -= (pos.dx - prev.dx) / cam.zoom;
            cam.y -= (pos.dy - prev.dy) / cam.zoom;
          }
          break;
        case 2:
          final h = _drag;
          if (h != null) {
            h.tx = _wx(pos) + _dragOffX;
            h.ty = _wy(pos) + _dragOffY;
          }
          break;
        case 3:
          final d = _dragEntity;
          if (d != null && !d.removed) {
            final wx = _wx(pos), wy = _wy(pos);
            final dx = wx - _lastWX, dy = wy - _lastWY;
            for (final p in d.particles) {
              p.x += dx;
              p.y += dy;
              p.px += dx;
              p.py += dy;
            }
            _lastWX = wx;
            _lastWY = wy;
          }
          break;
        case 4:
          _buildB = Offset(_wx(pos), _wy(pos));
          break;
        case 5:
          _updatePinch();
          break;
      }
    } else if (e.pointer == _p2) {
      if (_aiming) {
        _aimWX = _wx(pos);
        _aimWY = _wy(pos);
      } else if (_mode == 5) {
        _updatePinch();
      }
    }
  }

  void _onUp(PointerEvent e) {
    final id = e.pointer;
    final pos = e.localPosition;
    _ptrs.remove(id);
    if (id == _p2) {
      _p2 = null;
      if (_aiming) _stopAim();
      if (_mode == 5) {
        // keep panning with the finger that is still down
        _mode = 1;
        _moved = true;
      }
      return;
    }
    if (id != _p1) return;
    if (_aiming) _stopAim();
    final isTap = e is PointerUpEvent && !_moved && !_multi && _p1Clock.elapsedMilliseconds < 450;
    final dragged = _dragEntity;
    switch (_mode) {
      case 2:
        _endDrag();
        if (!isTap && dragged != null && dragged is HeldItem) _tryGive(dragged);
        break;
      case 3:
        if (dragged != null) {
          for (final p in dragged.particles) {
            p.px = p.x;
            p.py = p.y;
          }
        }
        _dragEntity = null;
        break;
      case 4:
        if (isTap) {
          _buildA = null;
          _buildB = null;
        } else {
          _finishBuild();
        }
        break;
    }
    _mode = 0;
    _p1 = null;
    final rest = _p2;
    if (rest != null) {
      // the second finger takes over as a pan
      _p1 = rest;
      _p2 = null;
      _p1Start = _ptrs[rest] ?? pos;
      _moved = true;
      _mode = 1;
    }
    if (isTap) _tapAt(pos);
    setState(() {});
  }

  void _startPinch() {
    _endDrag();
    _buildA = null;
    _buildB = null;
    final a = _ptrs[_p1], b = _ptrs[_p2];
    if (a == null || b == null) return;
    _mode = 5;
    _pinchD0 = math.max(1.0, (a - b).distance);
    _pinchZoom0 = cam.zoom;
    final mid = (a + b) / 2;
    _pinchWX = _wx(mid);
    _pinchWY = _wy(mid);
  }

  void _updatePinch() {
    final a = _ptrs[_p1], b = _ptrs[_p2];
    if (a == null || b == null) return;
    final d = math.max(1.0, (a - b).distance);
    cam.zoom = (_pinchZoom0 * d / _pinchD0).clamp(0.12, 3.0);
    final mid = (a + b) / 2;
    cam.x = _pinchWX - (mid.dx - _size.width / 2) / cam.zoom;
    cam.y = _pinchWY - (mid.dy - _size.height / 2) / cam.zoom;
  }

  // ---- second-finger aim & fire ------------------------------------------
  void _startAim(Offset pos) {
    final held = _dragEntity!;
    final Entity? item = held is Human ? held.held : held;
    _aiming = true;
    _aimItem = item;
    _aimWX = _wx(pos);
    _aimWY = _wy(pos);
    _aimShotPending = false;
    if (item == null) return;
    if (item is Gun || item is Melee) {
      // hold weapons by the grip so they pivot naturally toward the aim point
      final h = _drag;
      if (h != null && identical(held, item)) {
        final grip = item is Gun ? item.grip : (item as Melee).grip;
        h.p = grip;
        _dragOffX = 0;
        _dragOffY = 0;
        final f = _ptrs[_p1];
        if (f != null) {
          h.tx = _wx(f);
          h.ty = _wy(f);
        }
      }
    }
    if (item is Gun) {
      if (item.def.proj == Proj.gravity) {
        if (!item.activated) item.use(); // start pulling; release launches
      } else {
        _aimShotPending = true; // fires as soon as the barrel points at the finger
        _aimShotDelay = 0.12;
      }
    } else if (item is Melee) {
      if (item.def.style == MeleeStyle.chainsaw) item.activated = true;
    } else {
      item.use();
      Sfx.play('ui', vol: 0.3);
    }
  }

  void _stopAim() {
    final item = _aimItem;
    if (item is Gun) {
      if (item.def.proj == Proj.gravity) {
        if (item.activated) item.use(); // launch what it holds
      } else if (item.def.auto) {
        item.activated = false;
      }
    } else if (item is Melee && item.def.style == MeleeStyle.chainsaw) {
      item.activated = false;
    }
    _aiming = false;
    _aimItem = null;
    _aimShotPending = false;
  }

  void _updateAim(double dt) {
    if (!_aiming) return;
    final item = _aimItem;
    if (item == null) return;
    if (item.removed) {
      _aiming = false;
      _aimItem = null;
      return;
    }
    if (item is Gun) {
      item.keepUpright(_aimWX, _aimWY);
      item.playerAim(_aimWX, _aimWY);
      if (_aimShotPending) {
        _aimShotDelay -= dt;
        if (item.aimError(_aimWX, _aimWY) < 0.2 || _aimShotDelay <= 0) {
          _aimShotPending = false;
          if (item.def.auto) {
            item.activated = true;
          } else {
            item.tryFire();
          }
        }
      }
    } else if (item is Melee) {
      item.keepUpright(_aimWX, _aimWY);
      item.playerAim(_aimWX, _aimWY);
    }
  }

  void _endDrag() {
    final h = _drag;
    if (h != null) sb.world.drags.remove(h);
    _drag = null;
    _dragEntity = null;
  }

  /// Dropping a weapon onto a living person's hand makes them hold it.
  void _tryGive(Entity item) {
    final hi = item as HeldItem;
    if (hi.holder != null) return;
    final gp = item.particles[hi.gripIndex];
    Human? best;
    var bd = 40.0;
    for (final h in sb.humans) {
      if (!h.canGrab(item)) continue;
      for (final idx in [pHR, pHL]) {
        final hp = h.particles[idx];
        final d = math.sqrt((hp.x - gp.x) * (hp.x - gp.x) + (hp.y - gp.y) * (hp.y - gp.y));
        if (d < bd) {
          bd = d;
          best = h;
        }
      }
    }
    if (best != null) {
      best.grab(item);
      _toast('${best.name} grabbed the ${item.name}');
    }
  }

  void _finishBuild() {
    final a = _buildA, b = _buildB;
    _buildA = null;
    _buildB = null;
    if (a == null || b == null) return;
    final w = (b.dx - a.dx).abs(), h = (b.dy - a.dy).abs();
    if (w < 8 || h < 8) return;
    final mat = buildMats[buildMat];
    final blk = Block((a.dx + b.dx) / 2, (a.dy + b.dy) / 2, w, h, isStatic: buildStatic, mat: mat);
    sb.add(blk, undoable: true);
    Sfx.play('pop', vol: 0.5);
  }

  void _tapAt(Offset pos) {
    final wx = _wx(pos), wy = _wy(pos);
    final pad = 16 / cam.zoom;
    if (pending != null) {
      final p = pending!;
      final e = sb.spawn(p.defId, wx, wy, data: p.data);
      if (e == null) {
        _toast('Entity limit reached (${sb.maxEntities}). Raise it in Settings.');
      } else {
        sb.selected = e;
      }
      setState(() {});
      return;
    }
    final e = sb.entityAt(wx, wy, pad: pad);
    switch (tool) {
      case Tool.drag:
        setState(() => sb.selected = e);
        break;
      case Tool.use:
        if (e != null) {
          e.use();
          sb.selected = e;
          Sfx.play('ui', vol: 0.3);
        }
        setState(() {});
        break;
      case Tool.rope:
      case Tool.spring:
      case Tool.weld:
      case Tool.wire:
        _twoStep(e, wx, wy);
        break;
      case Tool.pin:
        if (e != null) {
          final idx = sb.nearestParticleIndex(e, wx, wy);
          final p = e.particles[idx];
          sb.addJoint(JointType.pin, e, idx, null, 0, anchorX: p.x, anchorY: p.y);
          Sfx.play('click', vol: 0.6);
        }
        break;
      case Tool.fire:
        if (e != null) {
          e.ignite(10);
          if (!e.canBurn) e.receiveHit(Hit(wx, wy, 0, -1, 10, 0, DmgType.fire));
        }
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + (sb.rng.nextDouble() - 0.5) * 1.5;
          sb.shootFlame(wx, wy, math.cos(a) * 120, math.sin(a) * 120, null);
        }
        Sfx.play('flame', vol: 0.6);
        break;
      case Tool.explode:
        sb.explode(wx, wy, 150, 2600, damage: 120);
        break;
      case Tool.cut:
        var n = sb.cutAt(wx, wy, 22 / cam.zoom);
        final s = sb.shapeAt(wx, wy, pad: 6 / cam.zoom);
        if (n == 0 && s != null && s.owner is Human && s.tag is int) {
          final h = s.owner as Human;
          final limb = s.tag as int;
          if (limb != lUTorso && limb != lLTorso) {
            h.sever(limb);
            n = 1;
          }
        }
        if (n > 0) Sfx.play('click', vol: 0.7, rate: 0.8);
        break;
      case Tool.heal:
        if (e is Human) {
          e.heal(999);
          sb.fx.sparks(e.cx, e.cy, 0, -1, 10, color: const Color(0xFF69F0AE));
          Sfx.play('heal', vol: 0.7);
        } else if (e != null) {
          if (e.hp.isFinite) e.hp = e.maxHp;
          e.burning = 0;
          e.charred = 0;
          Sfx.play('heal', vol: 0.5);
        }
        break;
      case Tool.delete:
        if (e != null) {
          sb.removeEntity(e);
          Sfx.play('pop', vol: 0.5, rate: 0.7);
        }
        break;
      case Tool.build:
        break;
    }
  }

  void _twoStep(Entity? e, double wx, double wy) {
    if (_pickA == null) {
      if (e == null) return;
      if (tool == Tool.weld && e.frozen) {
        // allowed: welding to a frozen thing makes it a fixed mount
      }
      setState(() {
        _pickA = e;
        _pickIdx = sb.nearestParticleIndex(e, wx, wy);
      });
      Sfx.play('ui', vol: 0.4);
      return;
    }
    final a = _pickA!;
    if (a.removed) {
      setState(() => _pickA = null);
      return;
    }
    final ia = _pickIdx;
    UserJoint? j;
    var ok = false;
    switch (tool) {
      case Tool.rope:
      case Tool.spring:
        final type = tool == Tool.rope ? JointType.rope : JointType.spring;
        if (e == null || identical(e, a)) {
          j = sb.addJoint(type, a, ia, null, 0, anchorX: wx, anchorY: wy);
        } else {
          j = sb.addJoint(type, a, ia, e, sb.nearestParticleIndex(e, wx, wy));
        }
        ok = j != null;
        break;
      case Tool.weld:
        if (e != null && !identical(e, a)) {
          j = sb.addJoint(JointType.weld, a, ia, e, sb.nearestParticleIndex(e, wx, wy));
          ok = j != null;
        }
        break;
      case Tool.wire:
        if (e != null && !identical(e, a)) {
          ok = sb.addLink(a, e) != null;
        }
        break;
      default:
        break;
    }
    setState(() => _pickA = null);
    Sfx.play(ok ? 'click' : 'ui', vol: 0.6);
  }

  // ------------------------------------------------------------------ actions
  Future<void> _openSpawn() async {
    final r = await showModalBottomSheet<SpawnChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => FractionallySizedBox(heightFactor: 0.86, child: const SpawnSheet()),
    );
    if (r != null) {
      setState(() {
        pending = r;
        _pickA = null;
      });
    }
  }

  void _clone(Entity e) {
    final def = Catalog.byId(e.defId);
    if (def == null) return;
    final j = e.toJson();
    final data = (j['d'] as Map?)?.cast<String, dynamic>();
    final c = def.build(0, 0, data);
    c.restoreFromJson(j);
    c.id = 0;
    for (final p in c.particles) {
      p.x += 50;
      p.y -= 50;
      p.px = p.x;
      p.py = p.y;
    }
    if (c is Human) c.drop();
    sb.liftClear(c);
    sb.add(c, undoable: true);
    sb.selected = c;
    Sfx.play('pop', vol: 0.5);
  }

  void _gravityDialog() {
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, set) {
        return AlertDialog(
          backgroundColor: RB.panel,
          title: const Text('Gravity'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${(sb.gravityMul * 100).round()}% of ${sb.map.name} gravity', style: const TextStyle(color: RB.dim)),
            Slider(
              value: sb.gravityMul,
              min: -1,
              max: 3,
              divisions: 40,
              onChanged: (v) => set(() {
                sb.gravityMul = v;
                sb.applyGravity();
              }),
            ),
            Wrap(spacing: 6, children: [
              for (final p in const [[0.0, 'Zero'], [0.17, 'Moon'], [1.0, 'Normal'], [2.5, 'Heavy'], [-0.5, 'Reverse']])
                ActionChip(
                  label: Text(p[1] as String),
                  onPressed: () => set(() {
                    sb.gravityMul = p[0] as double;
                    sb.applyGravity();
                  }),
                ),
            ]),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        );
      }),
    );
  }

  Future<void> _pauseMenu() async {
    final wasPaused = sb.paused;
    sb.paused = true;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        backgroundColor: RB.panel,
        title: Text(sceneName.toUpperCase(), style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.w900)),
        children: [
          _menuItem(c, 'resume', Icons.play_arrow, 'Resume'),
          _menuItem(c, 'save', Icons.save, sceneId == null ? 'Save' : 'Save "$sceneName"'),
          _menuItem(c, 'saveas', Icons.save_as, 'Save as new'),
          _menuItem(c, 'load', Icons.folder_open, 'Load scene'),
          _menuItem(c, 'clear', Icons.layers_clear, 'Clear everything'),
          _menuItem(c, 'exit', Icons.logout, 'Exit to main menu'),
        ],
      ),
    );
    sb.paused = wasPaused;
    if (!mounted) return;
    switch (r) {
      case 'save':
        await _save();
        break;
      case 'saveas':
        await _save(asNew: true);
        break;
      case 'load':
        final id = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const SavesScreen(pickMode: true)));
        if (id != null && mounted) {
          final j = Storage.readScene(id);
          if (j != null) {
            sb.loadJson(j);
            _applySettings();
            sceneId = id == Storage.autosaveId ? null : id;
            sceneName = j['name'] as String? ?? 'Untitled';
            final c = j['cam'] as List?;
            if (c != null && c.length == 3) {
              cam.x = (c[0] as num).toDouble();
              cam.y = (c[1] as num).toDouble();
              cam.zoom = (c[2] as num).toDouble().clamp(0.12, 3.0);
            }
            setState(() {});
          }
        }
        break;
      case 'clear':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: RB.panel,
            title: const Text('Clear the scene?'),
            content: const Text('Everything you spawned will be removed.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear')),
            ],
          ),
        );
        if (ok == true) setState(() => sb.clearAll());
        break;
      case 'exit':
        _doAutosave();
        if (mounted) Navigator.pop(context);
        break;
    }
  }

  Widget _menuItem(BuildContext c, String v, IconData icon, String label) => SimpleDialogOption(
        onPressed: () => Navigator.pop(c, v),
        child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 14), Text(label, style: const TextStyle(fontSize: 15))]),
      );

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (pending != null || _pickA != null) {
          setState(() {
            pending = null;
            _pickA = null;
          });
        } else {
          _pauseMenu();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(builder: (context, cons) {
          _size = Size(cons.maxWidth, cons.maxHeight);
          if (!_camReady && cons.maxHeight > 0) {
            _camReady = true;
            {
              // frame the floor (y = 0) at 68% of the screen height, above the toolbar
              cam.x = 0;
              cam.zoom = (cons.maxHeight / 520).clamp(0.45, 1.4);
              cam.y = -(cons.maxHeight * 0.18) / cam.zoom;
            }
          }
          // Explicit size: the Scaffold body gives loose constraints, and a Stack
          // whose only non-positioned children are empty would collapse to 0x0.
          return SizedBox(
              width: cons.maxWidth,
              height: cons.maxHeight,
              child: Stack(children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: _onUp,
                child: RepaintBoundary(child: CustomPaint(painter: _GamePainter(this), size: Size.infinite)),
              ),
            ),
            _topBar(),
            _toolBar(),
            _contextBar(),
            _banner(),
            if (_hint) _hintCard(),
            _errorBanner(),
          ]));
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // HUD: three slim translucent pills (controls, tools, selection) and a
  // spawn button. Everything else stays out of the way of the world.

  static const _pill = Color(0xB3141016);

  Widget _pillBox({required Widget child, EdgeInsets padding = const EdgeInsets.all(3)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _pill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: child,
      );

  Widget _topBar() {
    final slow = sb.timeScale < 1;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _pillBox(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _HudIcon(Icons.menu_rounded, onTap: _pauseMenu),
                _HudIcon(sb.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    active: sb.paused, onTap: () => setState(() => sb.paused = !sb.paused)),
                _HudIcon(Icons.slow_motion_video_rounded,
                    active: slow,
                    badge: slow ? '${sb.timeScale}×' : null,
                    onTap: () => setState(() {
                          const steps = [1.0, 0.5, 0.25, 0.1];
                          final i = steps.indexOf(sb.timeScale);
                          sb.timeScale = steps[(i + 1) % steps.length];
                        })),
                _HudIcon(Icons.public_rounded,
                    active: sb.gravityMul != 1,
                    badge: sb.gravityMul != 1 ? '${(sb.gravityMul * 100).round()}%' : null,
                    onTap: _gravityDialog),
                _HudIcon(Icons.undo_rounded, onTap: () {
                  if (sb.undo()) Sfx.play('pop', vol: 0.4, rate: 0.7);
                  setState(() {});
                }),
              ]),
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (_, __, ___) => Storage.settings.showFps
                  ? Padding(
                      padding: const EdgeInsets.only(right: 10, top: 14),
                      child: Text('${_fps.round()} fps · ${sb.dynamicCount}',
                          style: const TextStyle(color: RB.dim, fontSize: 11, fontFeatures: [ui.FontFeature.tabularFigures()])),
                    )
                  : const SizedBox.shrink(),
            ),
            Material(
              color: RB.red,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _openSpawn,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 22),
                    SizedBox(width: 4),
                    Text('SPAWN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _toolBar() {
    final info = tools.firstWhere((t) => t.tool == tool);
    return Positioned(
      left: 0,
      bottom: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(info.name.toUpperCase(),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: RB.text)),
                if (tool == Tool.build) ...[
                  const SizedBox(width: 10),
                  _SmallChip(buildStatic ? 'Static' : 'Dynamic', () => setState(() => buildStatic = !buildStatic)),
                  const SizedBox(width: 6),
                  _SmallChip(buildMats[buildMat].name, () => setState(() => buildMat = (buildMat + 1) % buildMats.length)),
                ],
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _pillBox(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final t in tools)
                    _HudIcon(t.icon, active: tool == t.tool, onTap: () {
                      setState(() {
                        tool = t.tool;
                        _pickA = null;
                        pending = null;
                      });
                      Sfx.play('ui', vol: 0.3);
                    }),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _contextBar() {
    final e = sb.selected;
    if (e == null || e.removed || pending != null) return const SizedBox.shrink();
    final h = e is Human ? e : null;
    return Positioned(
      right: 0,
      top: 58,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _pillBox(
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
            child: SizedBox(
              width: 188,
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (_, __, ___) {
                  String? status;
                  if (h != null) {
                    status = h.dead
                        ? 'Dead'
                        : (h.frozenIce > 0
                            ? 'Frozen'
                            : (!h.conscious ? 'Unconscious' : (h.panic > 0 ? 'Panicking' : (h.target != null ? 'Fighting' : null))));
                    if (h.infected && !h.dead) status = status == null ? 'Infected' : '$status · infected';
                  }
                  if (e.burning > 0) status = status == null ? 'On fire' : '$status · on fire';
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                        child: Text(e.name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12)),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => sb.selected = null),
                        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 16, color: RB.dim)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    if (h != null) ...[
                      _bar(h.health, const Color(0xFF66BB6A)),
                      if (h.type.bleeds) _bar(h.blood / 100, RB.redHi),
                    ] else if (e.hp.isFinite && e.maxHp.isFinite)
                      _bar((e.hp / e.maxHp).clamp(0.0, 1.0), const Color(0xFF42A5F5)),
                    if (status != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(status, style: const TextStyle(color: RB.dim, fontSize: 11)),
                      ),
                    const SizedBox(height: 4),
                    Wrap(children: [
                      _HudIcon(Icons.bolt_rounded, size: 34, active: e.activated, onTap: () => setState(() => e.use())),
                      _HudIcon(Icons.ac_unit_rounded, size: 34, active: e.frozen, onTap: () => setState(() => e.setFrozen(!e.frozen))),
                      _HudIcon(Icons.swap_horiz_rounded, size: 34, onTap: () => setState(() => e.flip())),
                      _HudIcon(Icons.copy_rounded, size: 34, onTap: () => setState(() => _clone(e))),
                      _HudIcon(Icons.local_fire_department_rounded, size: 34, onTap: () => e.ignite(8)),
                      _HudIcon(Icons.delete_rounded, size: 34, onTap: () => setState(() => sb.removeEntity(e))),
                      if (h != null) ...[
                        _HudIcon(Icons.healing_rounded, size: 34, onTap: () => setState(() => h.heal(999))),
                        _HudIcon(Icons.heart_broken_rounded, size: 34, onTap: () => setState(() => h.kill())),
                        if (h.held != null) _HudIcon(Icons.back_hand_rounded, size: 34, onTap: () => setState(() => h.drop())),
                      ],
                    ]),
                  ]);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(double v, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 3, right: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(value: v.clamp(0.0, 1.0), minHeight: 4, color: c, backgroundColor: const Color(0x33FFFFFF)),
        ),
      );

  Widget _banner() {
    String? text;
    VoidCallback? cancel;
    if (pending != null) {
      text = 'Tap to place ${pending!.name}';
      cancel = () => setState(() => pending = null);
    } else if (_pickA != null) {
      final what = switch (tool) {
        Tool.rope => 'Tap the second object, or empty space to hang it',
        Tool.spring => 'Tap the second object, or empty space to anchor',
        Tool.weld => 'Tap the object to weld to',
        Tool.wire => 'Tap the device to wire to',
        _ => '',
      };
      text = what;
      cancel = () => setState(() => _pickA = null);
    }
    if (text == null) return const SizedBox.shrink();
    return Positioned(
      top: 64,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Center(
          child: Material(
            color: RB.red,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (pending != null)
                  TextButton(
                    onPressed: () {
                      final p = pending!;
                      final e = sb.spawn(p.defId, cam.x, cam.y - 100, data: p.data);
                      if (e != null) sb.selected = e;
                      setState(() {});
                    },
                    child: const Text('CENTER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ),
                IconButton(onPressed: cancel, icon: const Icon(Icons.close, size: 20)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hintCard() {
    Widget line(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 16, color: RB.redHi),
            const SizedBox(width: 8),
            Flexible(child: Text(t, style: const TextStyle(fontSize: 12, color: RB.text))),
          ]),
        );
    return Positioned(
      left: 0,
      right: 0,
      top: 70,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            onTap: () => setState(() => _hint = false),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: const Color(0xE6141016),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                line(Icons.add_rounded, 'SPAWN adds things. Tap the world to place them.'),
                line(Icons.pan_tool_alt_rounded, 'One finger grabs and throws. Drag empty space to move around.'),
                line(Icons.gps_fixed_rounded, 'Holding a gun? Put a second finger where you want to shoot.'),
                line(Icons.pinch_rounded, 'Pinch with two fingers to zoom.'),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return ValueListenableBuilder<String?>(
      valueListenable: _error,
      builder: (_, err, __) {
        if (err == null) return const SizedBox.shrink();
        return Positioned(
          left: 70,
          right: 70,
          bottom: 76,
          child: Material(
            color: const Color(0xEE7F0000),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => _error.value = null,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Something broke (tap to dismiss). Please report this:\n$err',
                    style: const TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ),
          ),
        );
      },
    );
  }

  void paintOverlay(Canvas c) {
    // build preview
    final a = _buildA, b = _buildB;
    if (a != null && b != null) {
      final r = Rect.fromPoints(a, b);
      c.drawRect(r, Paint()..color = const Color(0x55C62828));
      c.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / cam.zoom
            ..color = RB.redHi);
    }
    // drag line
    final h = _drag;
    if (h != null) {
      c.drawLine(Offset(h.p.x, h.p.y), Offset(h.tx, h.ty),
          Paint()
            ..color = const Color(0xAAFFFFFF)
            ..strokeWidth = 1.5 / cam.zoom);
      c.drawCircle(Offset(h.tx, h.ty), 5 / cam.zoom, Paint()..color = const Color(0xCCFFFFFF));
    }
    // second-finger aim: line from the muzzle and a crosshair at the finger
    final ai = _aimItem;
    if (_aiming && ai != null && !ai.removed) {
      final z = cam.zoom;
      final red = Paint()
        ..color = const Color(0xCCFF3D3D)
        ..strokeWidth = 1.5 / z
        ..style = PaintingStyle.stroke;
      if (ai is Gun) {
        final f = ai.frame;
        final mx = f.wx(ai.def.length / 2, 0), my = f.wy(ai.def.length / 2, 0);
        final dx = _aimWX - mx, dy = _aimWY - my;
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 1) {
          // dashed line
          const dash = 10.0;
          for (var t = 0.0; t < len; t += dash * 2 / z) {
            final t2 = math.min(len, t + dash / z);
            c.drawLine(Offset(mx + dx / len * t, my + dy / len * t), Offset(mx + dx / len * t2, my + dy / len * t2), red);
          }
        }
      }
      final r = 14 / z;
      c.drawCircle(Offset(_aimWX, _aimWY), r, red);
      c.drawLine(Offset(_aimWX - r * 1.5, _aimWY), Offset(_aimWX - r * 0.5, _aimWY), red);
      c.drawLine(Offset(_aimWX + r * 0.5, _aimWY), Offset(_aimWX + r * 1.5, _aimWY), red);
      c.drawLine(Offset(_aimWX, _aimWY - r * 1.5), Offset(_aimWX, _aimWY - r * 0.5), red);
      c.drawLine(Offset(_aimWX, _aimWY + r * 0.5), Offset(_aimWX, _aimWY + r * 1.5), red);
    }
    // two-step pick marker
    final pa = _pickA;
    if (pa != null && !pa.removed && _pickIdx >= 0 && _pickIdx < pa.particles.length) {
      final p = pa.particles[_pickIdx];
      c.drawCircle(
          Offset(p.x, p.y),
          10 / cam.zoom,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 / cam.zoom
            ..color = const Color(0xFFFFD600));
    }
  }
}

class _HudIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final double size;
  final String? badge;
  const _HudIcon(this.icon, {required this.onTap, this.active = false, this.size = 42, this.badge});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Material(
        color: active ? RB.red : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(alignment: Alignment.center, children: [
              Icon(icon, size: size * 0.52, color: RB.text),
              if (badge != null)
                Positioned(
                  bottom: 1,
                  child: Text(badge!, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SmallChip(this.text, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xB3141016),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  final _GameScreenState s;
  _GamePainter(this.s) : super(repaint: s._frame);

  @override
  void paint(Canvas canvas, Size size) {
    final n = canvas.getSaveCount();
    try {
      paintWorld(canvas, size, s.sb, s.cam, overlay: s.paintOverlay);
    } catch (e, st) {
      canvas.restoreToCount(n);
      s._reportError('paint', e, st);
    }
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}
