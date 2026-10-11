import 'dart:math' as math;
import 'dart:ui';

import 'entity.dart';

class GameMap {
  final String id;
  final String name;
  final String desc;
  final double gravity;
  final double friction;
  final Color skyTop, skyBottom;
  final Color groundColor, groundTop;
  final double left, right;
  final double killY;
  final double spawnY;
  final List<List<Offset>> polys; // convex polygons, static
  final List<List<Offset>> spikes; // static hazards that impale
  final int deco; // background decoration style
  const GameMap({
    required this.id,
    required this.name,
    required this.desc,
    this.gravity = 980,
    this.friction = 1,
    this.skyTop = const Color(0xFF2A2230),
    this.skyBottom = const Color(0xFF7A4048),
    this.groundColor = const Color(0xFF3E3638),
    this.groundTop = const Color(0xFFC0392B),
    this.left = -3000,
    this.right = 3000,
    this.killY = 6000,
    this.spawnY = -200,
    required this.polys,
    this.spikes = const [],
    this.deco = 0,
  });
}

List<Offset> box(double x0, double y0, double x1, double y1) =>
    [Offset(x0, y0), Offset(x1, y0), Offset(x1, y1), Offset(x0, y1)];

List<List<Offset>> _walls(double l, double r, {double h = 4000}) => [
      box(l - 200, -h, l, 2000),
      box(r, -h, r + 200, 2000),
    ];

List<List<Offset>> _hills(double l, double r, double seed) {
  final out = <List<Offset>>[];
  const step = 160.0;
  double f(double x) =>
      -60 * math.sin(x / 700 + seed) - 35 * math.sin(x / 260 + seed * 2) - 40;
  for (var x = l; x < r; x += step) {
    final y0 = f(x), y1 = f(x + step);
    out.add([Offset(x, y0), Offset(x + step, y1), Offset(x + step, 1500), Offset(x, 1500)]);
  }
  return out;
}

class GameMaps {
  static final List<GameMap> all = [
    GameMap(
      id: 'flat',
      name: 'Flatlands',
      desc: 'Wide open floor. The classic empty sandbox.',
      polys: [box(-3000, 0, 3000, 1500), ..._walls(-3000, 3000)],
    ),
    GameMap(
      id: 'endless',
      name: 'Endless Plain',
      desc: 'A huge unrestricted floor, 40 km of room to build.',
      left: -20000,
      right: 20000,
      skyTop: Color(0xFF101318),
      skyBottom: Color(0xFF26303A),
      groundTop: Color(0xFF4F6F52),
      groundColor: Color(0xFF23302A),
      polys: [box(-20000, 0, 20000, 1500), ..._walls(-20000, 20000)],
      deco: 1,
    ),
    GameMap(
      id: 'void',
      name: 'Zero-G Void',
      desc: 'No gravity inside a sealed chamber. Things float forever.',
      gravity: 0,
      skyTop: Color(0xFF05050A),
      skyBottom: Color(0xFF120A1E),
      groundTop: Color(0xFF6B3FA0),
      groundColor: Color(0xFF1C1428),
      left: -2000,
      right: 2000,
      spawnY: -800,
      polys: [
        box(-2000, 0, 2000, 400),
        box(-2000, -2400, 2000, -2000),
        ..._walls(-2000, 2000, h: 2400),
      ],
      deco: 2,
    ),
    GameMap(
      id: 'arena',
      name: 'Proving Grounds',
      desc: 'Arena with platforms, ramps and a central pit.',
      polys: [
        box(-2500, 0, -300, 1500),
        box(300, 0, 2500, 1500),
        box(-300, 260, 300, 1500),
        [Offset(-900, 0), Offset(-500, -180), Offset(-500, 0)],
        [Offset(500, -180), Offset(900, 0), Offset(500, 0)],
        box(-500, -180, -380, 0),
        box(380, -180, 500, 0),
        box(-1500, -420, -1000, -390),
        box(1000, -420, 1500, -390),
        box(-200, -620, 200, -590),
        ..._walls(-2500, 2500),
      ],
      deco: 0,
    ),
    GameMap(
      id: 'city',
      name: 'Rooftops',
      desc: 'Concrete rooftops with deadly gaps between them.',
      skyTop: Color(0xFF0E1020),
      skyBottom: Color(0xFF4A2A3A),
      groundTop: Color(0xFF55555E),
      groundColor: Color(0xFF26262C),
      polys: [
        box(-2800, 400, 2800, 1500),
        box(-2800, -200, -1700, 400),
        box(-1450, -380, -700, 400),
        box(-450, -120, 450, 400),
        box(700, -460, 1350, 400),
        box(1600, -260, 2800, 400),
        ..._walls(-2800, 2800),
      ],
      deco: 3,
    ),
    GameMap(
      id: 'hills',
      name: 'Rolling Hills',
      desc: 'Bumpy grassland. Great for vehicles.',
      left: -4000,
      right: 4000,
      skyTop: Color(0xFF1B2A3A),
      skyBottom: Color(0xFF6B8CA8),
      groundTop: Color(0xFF5E8C3A),
      groundColor: Color(0xFF3B2A1E),
      polys: [..._hills(-4000, 4000, 1.3), ..._walls(-4000, 4000)],
      deco: 1,
    ),
    GameMap(
      id: 'lab',
      name: 'Facility',
      desc: 'Multi-floor test lab with stairs and ledges.',
      skyTop: Color(0xFF15181C),
      skyBottom: Color(0xFF22282E),
      groundTop: Color(0xFFB0B4B8),
      groundColor: Color(0xFF30353A),
      left: -2000,
      right: 2000,
      polys: [
        box(-2000, 0, 2000, 1500),
        box(-2000, -1200, 2000, -1100),
        box(-1800, -400, -200, -370),
        box(200, -400, 1800, -370),
        box(-1200, -780, 1200, -750),
        for (var i = 0; i < 6; i++) box(-200 + i * 0.0, -60.0 * (i + 1), -200 + 400 - i * 60.0, -60.0 * i),
        ..._walls(-2000, 2000, h: 1200),
      ],
      deco: 4,
    ),
    GameMap(
      id: 'moon',
      name: 'Moon Base',
      desc: 'One-sixth gravity on dusty craters.',
      gravity: 165,
      skyTop: Color(0xFF000000),
      skyBottom: Color(0xFF0A0A14),
      groundTop: Color(0xFFA8A8A8),
      groundColor: Color(0xFF4A4A4E),
      left: -3500,
      right: 3500,
      polys: [..._hills(-3500, 3500, 4.1), ..._walls(-3500, 3500, h: 6000)],
      deco: 2,
    ),
    GameMap(
      id: 'ice',
      name: 'Frozen Lake',
      desc: 'Almost no friction. Everything slides.',
      friction: 0.12,
      skyTop: Color(0xFF1A2430),
      skyBottom: Color(0xFF8DB4D0),
      groundTop: Color(0xFFDFF4FF),
      groundColor: Color(0xFF7FA8C4),
      polys: [box(-3000, 0, 3000, 1500), ..._walls(-3000, 3000)],
      deco: 1,
    ),
    GameMap(
      id: 'pit',
      name: 'Spike Pit',
      desc: 'Two ledges over a pit lined with spikes.',
      polys: [
        box(-2500, 0, -400, 1500),
        box(400, 0, 2500, 1500),
        box(-400, 600, 400, 1500),
        ..._walls(-2500, 2500),
      ],
      spikes: [
        for (var i = 0; i < 10; i++)
          [Offset(-400 + i * 80.0, 600), Offset(-360 + i * 80.0, 520), Offset(-320 + i * 80.0, 600)],
      ],
    ),
  ];

  static GameMap byId(String id) =>
      all.firstWhere((m) => m.id == id, orElse: () => all.first);
}

/// The static level geometry.
class MapEntity extends Entity {
  final GameMap map;
  final List<List<int>> _polyIdx = [];

  MapEntity(this.map) : super('map', material: Mat.stone) {
    for (final poly in map.polys) {
      final idx = <int>[];
      final ps = poly.map((o) {
        idx.add(particles.length);
        return addP(o.dx, o.dy, 0);
      }).toList();
      _polyIdx.add(idx);
      addPoly(ps, friction: 0.8);
    }
    for (final poly in map.spikes) {
      final ps = poly.map((o) => addP(o.dx, o.dy, 0)).toList();
      addPoly(ps, friction: 0.9, tag: 'spike');
    }
  }

  @override
  String get name => map.name;

  @override
  void damage(double amount, DmgType type) {}

  @override
  void receiveHit(Hit h) {}

  @override
  void ignite([double seconds = 6]) {}

  @override
  void render(Canvas c, RenderCtx r) {
    final top = Paint()..color = map.groundTop;
    final fill = Paint()..color = map.groundColor;
    final line = Paint()
      ..color = const Color(0x22000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final s in shapes) {
      if (s.tag == 'spike') {
        drawPoly(c, s.pts, const Color(0xFFB8BEC6), stroke: 2);
        continue;
      }
      final path = polyPath(s.pts);
      c.drawPath(path, fill);
      c.drawPath(path, line);
      // highlight upward facing edges as "ground top"
      final n = s.pts.length;
      final cxp = s.centerX(), cyp = s.centerY();
      for (var i = 0; i < n; i++) {
        final a = s.pts[i], b = s.pts[(i + 1) % n];
        var nx = b.y - a.y, ny = -(b.x - a.x);
        if ((cxp - a.x) * nx + (cyp - a.y) * ny > 0) {
          nx = -nx;
          ny = -ny;
        }
        final len = math.sqrt(nx * nx + ny * ny);
        if (len < 1) continue;
        if (ny / len < -0.5) {
          final p = Paint()
            ..color = map.groundTop
            ..strokeWidth = 8
            ..strokeCap = StrokeCap.round;
          c.drawLine(Offset(a.x, a.y + 4), Offset(b.x, b.y + 4), p);
        }
      }
    }
    top.color = map.groundTop;
  }
}
