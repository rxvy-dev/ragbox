import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/storage.dart';
import '../game/entity.dart';
import '../game/human.dart';
import 'spawn_sheet.dart';
import 'theme.dart';

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  List<Map<String, dynamic>> _chars = [];

  @override
  void initState() {
    super.initState();
    _chars = Storage.loadCharacters();
  }

  Future<void> _edit([Map<String, dynamic>? c]) async {
    final r = await Navigator.push<Map<String, dynamic>>(
        context, MaterialPageRoute(builder: (_) => CharacterEditor(initial: c)));
    if (r == null) return;
    setState(() {
      final i = _chars.indexWhere((x) => x['uid'] == r['uid']);
      if (i >= 0) {
        _chars[i] = r;
      } else {
        _chars.add(r);
      }
    });
    IconCache.invalidate('custom:${r['uid']}');
    Storage.saveCharacters(_chars);
  }

  void _delete(Map<String, dynamic> c) {
    setState(() => _chars.removeWhere((x) => x['uid'] == c['uid']));
    Storage.saveCharacters(_chars);
  }

  Future<void> _export(Map<String, dynamic> c) async {
    final ok = await Native.exportText('${c['name'] ?? 'character'}.ragbox-char.json',
        jsonEncode({'format': 'ragbox-character', 'version': 1, 'character': c}));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Exported' : 'Export cancelled')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHARACTERS')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: RB.red,
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('NEW CHARACTER', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
      ),
      body: _chars.isEmpty
          ? const Center(
              child: Text('Create your own people: pick a base type, colours, size,\narmour, team and behaviour. They show up in the spawn menu under Custom.',
                  textAlign: TextAlign.center, style: TextStyle(color: RB.dim)))
          : GridView.extent(
              maxCrossAxisExtent: 170,
              padding: const EdgeInsets.all(14),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [
                for (final c in _chars)
                  Material(
                    color: RB.panel,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _edit(c),
                      child: Column(children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: EntityIcon('custom:${c['uid']}',
                                () => Human(0, 0, HumanTypes.fromConfig(c), defId: 'custom', customCfg: c)),
                          ),
                        ),
                        Row(children: [
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(c['name'] as String? ?? 'Custom',
                                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          PopupMenuButton<String>(
                            color: RB.panel2,
                            onSelected: (v) {
                              if (v == 'delete') _delete(c);
                              if (v == 'export') _export(c);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'export', child: Text('Export to file')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ]),
                      ]),
                    ),
                  ),
              ],
            ),
    );
  }
}

const _palette = [
  Color(0xFFF1C9A5), Color(0xFFE0A47A), Color(0xFFC68B62), Color(0xFF9C6B4E), Color(0xFF6B4632), Color(0xFF3F2A1E),
  Color(0xFF7FA068), Color(0xFF8BD17C), Color(0xFFC9CED6), Color(0xFFE8E2CF),
  Color(0xFFB3261E), Color(0xFFE53935), Color(0xFFFF7043), Color(0xFFFFB300), Color(0xFFFDD835), Color(0xFF43A047),
  Color(0xFF00897B), Color(0xFF1E88E5), Color(0xFF3D5A80), Color(0xFF5E35B1), Color(0xFF8E24AA), Color(0xFFD81B60),
  Color(0xFF212121), Color(0xFF424242), Color(0xFF757575), Color(0xFFBDBDBD), Color(0xFFFFFFFF), Color(0xFF4B5320),
  Color(0xFF2B2D42), Color(0xFF5D4037),
];

class CharacterEditor extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const CharacterEditor({super.key, this.initial});

  @override
  State<CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends State<CharacterEditor> {
  late Map<String, dynamic> cfg;
  late TextEditingController _name;
  int _rev = 0;

  @override
  void initState() {
    super.initState();
    cfg = Map<String, dynamic>.from(widget.initial ??
        {
          'uid': Storage.newId(),
          'name': 'My Character',
          'base': 'human',
        });
    cfg['uid'] ??= Storage.newId();
    _name = TextEditingController(text: cfg['name'] as String? ?? '');
  }

  HumanType get _base => HumanTypes.byId(cfg['base'] as String? ?? 'human');

  void _set(String k, Object? v) => setState(() {
        if (v == null) {
          cfg.remove(k);
        } else {
          cfg[k] = v;
        }
        _rev++;
      });

  Widget _colorRow(String label, String key, Color current) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: RB.label),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final c in _palette)
              GestureDetector(
                onTap: () => _set(key, c.toARGB32()),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.toARGB32() == current.toARGB32() ? RB.redHi : RB.line, width: 3),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = HumanTypes.fromConfig(cfg);
    final base = _base;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHARACTER EDITOR'),
        actions: [
          TextButton.icon(
            onPressed: () {
              cfg['name'] = _name.text.trim().isEmpty ? 'Custom' : _name.text.trim();
              Navigator.pop(context, cfg);
            },
            icon: const Icon(Icons.check),
            label: const Text('SAVE'),
          ),
        ],
      ),
      body: Row(children: [
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: RB.panel, borderRadius: BorderRadius.circular(16), border: Border.all(color: RB.line)),
            child: CustomPaint(
              painter: _PreviewPainter(t, cfg, _rev),
              size: Size.infinite,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: ListView(padding: const EdgeInsets.fromLTRB(4, 12, 16, 24), children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => cfg['name'] = v,
            ),
            const SizedBox(height: 12),
            const Text('BASE TYPE', style: RB.label),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final b in HumanTypes.all)
                ChoiceChip(
                  label: Text(b.name, style: const TextStyle(fontSize: 12)),
                  selected: base.id == b.id,
                  selectedColor: RB.red,
                  showCheckmark: false,
                  onSelected: (_) => _set('base', b.id),
                ),
            ]),
            const SizedBox(height: 8),
            Text(base.desc, style: const TextStyle(color: RB.dim, fontSize: 12)),
            _colorRow('Skin', 'skin', t.skin),
            _colorRow('Shirt', 'shirt', t.shirt),
            _colorRow('Pants', 'pants', t.pants),
            _colorRow('Hair / helmet', 'hair', t.hair),
            const SizedBox(height: 6),
            const Text('HAIR STYLE', style: RB.label),
            Wrap(spacing: 6, children: [
              for (final hs in const [[0, 'Bald'], [1, 'Short'], [2, 'Long'], [3, 'Mohawk'], [4, 'Helmet'], [5, 'Hood'], [6, 'Crown'], [7, 'Dome']])
                ChoiceChip(
                  label: Text(hs[1] as String, style: const TextStyle(fontSize: 12)),
                  selected: t.hairStyle == hs[0],
                  selectedColor: RB.red,
                  showCheckmark: false,
                  onSelected: (_) => _set('hairStyle', hs[0]),
                ),
            ]),
            _slider('Size', (cfg['scale'] as num?)?.toDouble() ?? base.scale, 0.5, 1.8, 'scale', (v) => '${(v * 100).round()}%'),
            _slider('Toughness', (cfg['hpMul'] as num?)?.toDouble() ?? base.hpMul, 0.3, 4, 'hpMul', (v) => '×${v.toStringAsFixed(1)}'),
            _slider('Armour', (cfg['armor'] as num?)?.toDouble() ?? base.armorTorso, 0, 0.95, 'armor', (v) => '${(v * 100).round()}%'),
            _slider('Team', ((cfg['team'] as num?)?.toDouble() ?? base.team.toDouble()), 0, 9, 'team', (v) => 'Team ${v.round()}',
                divisions: 9, asInt: true),
            const SizedBox(height: 6),
            const Text('BEHAVIOUR', style: RB.label),
            Wrap(spacing: 6, children: [
              for (final b in Behavior.values)
                ChoiceChip(
                  label: Text(_behName(b), style: const TextStyle(fontSize: 12)),
                  selected: t.behavior == b,
                  selectedColor: RB.red,
                  showCheckmark: false,
                  onSelected: (_) => _set('behavior', b.name),
                ),
            ]),
            const SizedBox(height: 6),
            Text(_behDesc(t.behavior), style: const TextStyle(color: RB.dim, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  String _behName(Behavior b) => switch (b) {
        Behavior.passive => 'Passive',
        Behavior.coward => 'Coward',
        Behavior.hostile => 'Hostile',
        Behavior.soldier => 'Soldier',
        Behavior.berserk => 'Berserk',
      };

  String _behDesc(Behavior b) => switch (b) {
        Behavior.passive => 'Stands around. Panics only when burning.',
        Behavior.coward => 'Runs away from hostiles, gunfire and explosions.',
        Behavior.hostile => 'Hunts people on other teams with fists or a held weapon.',
        Behavior.soldier => 'Shoots hostiles with any gun you hand them.',
        Behavior.berserk => 'Attacks everyone, even its own team.',
      };

  Widget _slider(String label, double v, double min, double max, String key, String Function(double) fmt,
      {int? divisions, bool asInt = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label.toUpperCase(), style: RB.label)),
        Expanded(
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (x) => _set(key, asInt ? x.round() : double.parse(x.toStringAsFixed(2))),
          ),
        ),
        SizedBox(width: 64, child: Text(fmt(v), style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final HumanType t;
  final Map<String, dynamic> cfg;
  final int rev;
  _PreviewPainter(this.t, this.cfg, this.rev);

  @override
  void paint(Canvas canvas, Size size) {
    final h = Human(0, 0, t, defId: 'custom', customCfg: cfg);
    // fixed scale so the Size slider is visible: room for a 1.8x person
    final k = size.height * 0.85 / (185 * 1.8);
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.93);
    canvas.scale(k);
    // reference silhouette of a normal-sized person
    canvas.drawRect(const Rect.fromLTWH(-40, -180, 2, 180), Paint()..color = const Color(0x22FFFFFF));
    canvas.drawRect(const Rect.fromLTWH(-60, 0, 120, 2), Paint()..color = const Color(0x44FFFFFF));
    h.render(canvas, RenderCtx()..zoom = k);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.rev != rev || old.t != t;
}
