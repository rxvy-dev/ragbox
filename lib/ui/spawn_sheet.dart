import 'package:flutter/material.dart';

import '../core/storage.dart';
import '../game/catalog.dart';
import '../game/entity.dart';
import '../game/human.dart';
import 'theme.dart';
import 'world_painter.dart';

class SpawnChoice {
  final String defId;
  final String name;
  final Map<String, dynamic>? data;
  SpawnChoice(this.defId, this.name, [this.data]);
}

/// Cached preview entities for the spawn menu (built once, never simulated).
class IconCache {
  static final Map<String, Entity> _cache = {};

  static Entity? get(String key, Entity Function() build) {
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      final e = build();
      _cache[key] = e;
      return e;
    } catch (_) {
      return null;
    }
  }

  static void invalidate(String key) => _cache.remove(key);
}

class EntityIcon extends StatelessWidget {
  final String cacheKey;
  final Entity Function() maker;
  const EntityIcon(this.cacheKey, this.maker, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _IconPainter(cacheKey, maker), size: Size.infinite);
  }
}

class _IconPainter extends CustomPainter {
  final String key_;
  final Entity Function() build;
  _IconPainter(this.key_, this.build);

  @override
  void paint(Canvas canvas, Size size) {
    final e = IconCache.get(key_, build);
    if (e != null) paintEntityIcon(canvas, size, e);
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.key_ != key_;
}

class SpawnSheet extends StatefulWidget {
  const SpawnSheet({super.key});

  @override
  State<SpawnSheet> createState() => _SpawnSheetState();
}

class _SpawnSheetState extends State<SpawnSheet> {
  static String _lastCat = Cat.humans;
  String _cat = _lastCat;
  String _query = '';
  late List<Map<String, dynamic>> _customs;

  static const _fav = 'Favorites';
  static const _all = 'All';

  @override
  void initState() {
    super.initState();
    _customs = Storage.loadCharacters();
  }

  List<String> get _favs => Storage.settings.favorites;

  void _toggleFav(String id) {
    setState(() {
      if (_favs.contains(id)) {
        _favs.remove(id);
      } else {
        _favs.add(id);
      }
    });
    Storage.saveSettings();
  }

  @override
  Widget build(BuildContext context) {
    final items = Catalog.visible;
    final q = _query.trim().toLowerCase();
    final tiles = <Widget>[];

    // custom characters appear under Custom (and in search / favourites)
    final customChoices = [
      for (final c in _customs)
        if (c['uid'] != null) c
    ];

    bool match(String name, String cat, String desc) =>
        q.isEmpty || name.toLowerCase().contains(q) || cat.toLowerCase().contains(q) || desc.toLowerCase().contains(q);

    if (_cat == Cat.custom || q.isNotEmpty || _cat == _fav || _cat == _all) {
      for (final c in customChoices) {
        final id = 'custom:${c['uid']}';
        final name = c['name'] as String? ?? 'Custom';
        if (_cat == _fav && !_favs.contains(id)) continue;
        if (!match(name, Cat.custom, '')) continue;
        tiles.add(_tile(id, name, () => Human(0, 0, HumanTypes.fromConfig(c), defId: 'custom', customCfg: c),
            SpawnChoice('custom', name, {'cfg': c})));
      }
    }
    for (final it in items) {
      if (_cat == _fav) {
        if (!_favs.contains(it.id)) continue;
      } else if (_cat != _all && q.isEmpty && it.category != _cat) {
        continue;
      }
      if (!match(it.name, it.category, it.desc)) continue;
      tiles.add(_tile(it.id, it.name, () => it.build(0, 0, null), SpawnChoice(it.id, it.name), desc: it.desc));
    }

    final cats = [_fav, _all, ...Cat.order];
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: RB.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          border: Border(top: BorderSide(color: RB.red, width: 2)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
            child: Row(children: [
              const Text('SPAWN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 16)),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search ${items.length + customChoices.length} items…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: RB.panel,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final c in cats)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(c, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      avatar: c == _fav ? const Icon(Icons.star, size: 16) : null,
                      selected: _cat == c && q.isEmpty,
                      selectedColor: RB.red,
                      backgroundColor: RB.panel,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _cat = c;
                        _lastCat = c;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: tiles.isEmpty
                ? Center(
                    child: Text(
                        _cat == _fav
                            ? 'No favourites yet.\nTap the star on any item to pin it here.'
                            : (_cat == Cat.custom ? 'No custom characters yet.\nCreate them from the main menu → Characters.' : 'Nothing found.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: RB.dim)))
                : GridView.extent(
                    maxCrossAxisExtent: 104,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.82,
                    children: tiles,
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _tile(String id, String name, Entity Function() build, SpawnChoice choice, {String desc = ''}) {
    final fav = _favs.contains(id);
    return Tooltip(
      message: desc.isEmpty ? name : '$name — $desc',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: RB.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pop(context, choice),
          onLongPress: () => _toggleFav(id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: RB.line),
            ),
            child: Stack(children: [
              Column(children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(4), child: EntityIcon(id, build))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                  child: Text(name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, height: 1.1)),
                ),
              ]),
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  onTap: () => _toggleFav(id),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(fav ? Icons.star : Icons.star_border, size: 18, color: fav ? const Color(0xFFFFC107) : RB.dim),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
