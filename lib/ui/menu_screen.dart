import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/storage.dart';
import '../game/entity.dart';
import '../game/human.dart';
import '../game/maps.dart';
import '../game/props.dart';
import '../game/sandbox.dart';
import 'about_screen.dart';
import 'characters_screen.dart';
import 'game_screen.dart';
import 'saves_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'world_painter.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late Sandbox demo;
  final Camera cam = Camera()
    ..x = 0
    ..y = -180
    ..zoom = 0.9;
  late Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  double _spawnT = 0;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    demo = Sandbox(GameMaps.byId('flat'));
    demo.fx.gore = Storage.settings.gore;
    _ticker = createTicker((el) {
      final dt = _last == Duration.zero ? 1 / 60 : (el - _last).inMicroseconds / 1e6;
      _last = el;
      _spawnT -= dt;
      if (_spawnT <= 0) {
        _spawnT = 1.6;
        _dropSomething();
      }
      demo.update(dt);
      _frame.value++;
    })
      ..start();
  }

  void _dropSomething() {
    if (demo.dynamicCount > 14) {
      // remove the oldest thing
      for (final e in demo.entities) {
        if (e is! MapEntity) {
          demo.removeEntity(e);
          break;
        }
      }
    }
    final x = cam.x + (_rng.nextDouble() - 0.5) * 700;
    if (_rng.nextDouble() < 0.55) {
      final types = HumanTypes.all;
      final t = types[_rng.nextInt(types.length)];
      final h = Human(x, -700, t, defId: 'h_${t.id}', facing: _rng.nextBool() ? 1 : -1);
      demo.add(h);
    } else {
      final p = Props.all[_rng.nextInt(Props.all.length)];
      demo.add(Prop(p, x, -700, rot: _rng.nextDouble() * 3));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Future<void> _go(Widget page) async {
    _ticker.stop();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    _last = Duration.zero;
    _ticker.start();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasAuto = Storage.hasAutosave();
    return Scaffold(
      body: SizedBox.expand(child: Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _DemoPainter(this), size: Size.infinite)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [RB.bg.withValues(alpha: 0.96), RB.bg.withValues(alpha: 0.7), Colors.transparent],
                stops: const [0, 0.45, 0.8],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 12),
            child: SizedBox(
              width: 330,
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  const Text('RAGBOX', style: RB.title),
                  Container(height: 4, width: 150, color: RB.red, margin: const EdgeInsets.only(top: 6, bottom: 4)),
                  const Text('PHYSICS SANDBOX · FREE · OFFLINE · OPEN SOURCE', style: RB.label),
                  const SizedBox(height: 18),
                  if (hasAuto)
                    MenuButton('Continue', Icons.play_arrow, () {
                      final meta = Storage.readMeta(Storage.autosaveId);
                      _go(GameScreen(map: GameMaps.byId(meta?.map ?? 'flat'), sceneId: Storage.autosaveId));
                    }, primary: true),
                  MenuButton('New sandbox', Icons.add_box, () => _go(const MapSelectScreen()), primary: !hasAuto),
                  MenuButton('Saved scenes', Icons.folder, () => _go(const SavesScreen())),
                  MenuButton('Characters', Icons.person, () => _go(const CharactersScreen())),
                  MenuButton('Settings', Icons.tune, () => _go(const SettingsScreen())),
                  MenuButton('About & license', Icons.info_outline, () => _go(const AboutScreen())),
                ]),
              ),
            ),
          ),
        ),
      ])),
    );
  }
}

class _DemoPainter extends CustomPainter {
  final _MenuScreenState s;
  _DemoPainter(this.s) : super(repaint: s._frame);
  @override
  void paint(Canvas canvas, Size size) {
    s.cam.x = -size.width * 0.18 / s.cam.zoom;
    final n = canvas.getSaveCount();
    try {
      paintWorld(canvas, size, s.demo, s.cam);
    } catch (_) {
      canvas.restoreToCount(n);
    }
  }

  @override
  bool shouldRepaint(covariant _DemoPainter oldDelegate) => true;
}

class MapSelectScreen extends StatelessWidget {
  const MapSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHOOSE A MAP')),
      body: GridView.extent(
        maxCrossAxisExtent: 280,
        padding: const EdgeInsets.all(14),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: [
          for (final m in GameMaps.all)
            Material(
              color: RB.panel,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(map: m))),
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _MapPreview(m))),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xEE0E0C0F)],
                        ),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(m.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
                        const SizedBox(height: 2),
                        Text(m.desc, style: const TextStyle(color: RB.dim, fontSize: 11), maxLines: 2),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPreview extends CustomPainter {
  final GameMap m;
  static final Map<String, MapEntity> _cache = {};
  _MapPreview(this.m);

  @override
  void paint(Canvas canvas, Size size) {
    final cam = Camera()
      ..x = 0
      ..y = -150;
    final span = math.min(4000.0, m.right - m.left + 400);
    cam.zoom = size.width / span;
    paintSky(canvas, size, m, cam);
    final me = _cache.putIfAbsent(m.id, () => MapEntity(m));
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cam.zoom);
    canvas.translate(-cam.x, -cam.y);
    me.render(canvas, RenderCtx());
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MapPreview old) => old.m != m;
}
