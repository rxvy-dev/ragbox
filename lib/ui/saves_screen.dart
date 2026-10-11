import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/storage.dart';
import '../game/maps.dart';
import 'game_screen.dart';
import 'theme.dart';

class SavesScreen extends StatefulWidget {
  /// When true, tapping a save returns its id instead of opening it.
  final bool pickMode;
  const SavesScreen({super.key, this.pickMode = false});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  List<SaveMeta> _saves = [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _saves = Storage.listScenes());

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  void _open(SaveMeta m) {
    if (widget.pickMode) {
      Navigator.pop(context, m.id);
      return;
    }
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => GameScreen(map: GameMaps.byId(m.map), sceneId: m.id)));
  }

  Future<void> _rename(SaveMeta m) async {
    final ctrl = TextEditingController(text: m.name);
    final n = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: RB.panel,
        title: const Text('Rename'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Rename')),
        ],
      ),
    );
    if (n != null && n.isNotEmpty) {
      Storage.renameScene(m.id, n);
      _reload();
    }
  }

  Future<void> _delete(SaveMeta m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: RB.panel,
        title: Text('Delete "${m.name}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      Storage.deleteScene(m.id);
      _reload();
    }
  }

  Future<void> _export(SaveMeta m) async {
    final j = Storage.readScene(m.id);
    if (j == null) return;
    final safe = m.name.replaceAll(RegExp(r'[^A-Za-z0-9_\- ]'), '').trim();
    final ok = await Native.exportText('${safe.isEmpty ? 'scene' : safe}.ragbox.json', jsonEncode(j));
    if (mounted) _toast(ok ? 'Exported "${m.name}"' : 'Export cancelled');
  }

  Future<void> _exportAll() async {
    final ok = await Native.exportText('ragbox-backup-${DateTime.now().toIso8601String().substring(0, 10)}.json', Storage.backupJson());
    if (mounted) _toast(ok ? 'Backup exported' : 'Export cancelled');
  }

  Future<void> _import() async {
    final text = await Native.importText();
    if (text == null) return;
    try {
      final msg = Storage.importJson(text);
      _reload();
      if (mounted) _toast(msg);
    } catch (e) {
      if (mounted) _toast('Could not import: not a Ragbox scene or backup file');
    }
  }

  String _ago(int ms) {
    if (ms == 0) return '';
    final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickMode ? 'LOAD SCENE' : 'SAVED SCENES'),
        actions: [
          IconButton(tooltip: 'Import file', onPressed: _import, icon: const Icon(Icons.file_open)),
          IconButton(tooltip: 'Export full backup', onPressed: _exportAll, icon: const Icon(Icons.backup)),
        ],
      ),
      body: _saves.isEmpty
          ? const Center(
              child: Text('No saved scenes yet.\nOpen a sandbox and tap the save button.',
                  textAlign: TextAlign.center, style: TextStyle(color: RB.dim)))
          : GridView.extent(
              maxCrossAxisExtent: 300,
              padding: const EdgeInsets.all(14),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [for (final m in _saves) _card(m)],
            ),
    );
  }

  Widget _card(SaveMeta m) {
    final thumb = Storage.thumbFile(m.id);
    final isAuto = m.id == Storage.autosaveId;
    return Material(
      color: RB.panel,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: thumb.existsSync()
                ? Image.file(thumb, fit: BoxFit.cover, gaplessPlayback: true)
                : Container(
                    color: RB.panel2,
                    child: Icon(isAuto ? Icons.history : Icons.image_not_supported, color: RB.dim, size: 36),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 2, 4),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isAuto ? 'AUTOSAVE' : m.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${GameMaps.byId(m.map).name} · ${m.count} objects · ${_ago(m.updated)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: RB.dim, fontSize: 11)),
                ]),
              ),
              PopupMenuButton<String>(
                color: RB.panel2,
                onSelected: (v) async {
                  switch (v) {
                    case 'rename':
                      await _rename(m);
                      break;
                    case 'dup':
                      Storage.duplicateScene(m.id);
                      _reload();
                      break;
                    case 'export':
                      await _export(m);
                      break;
                    case 'delete':
                      await _delete(m);
                      break;
                  }
                },
                itemBuilder: (_) => [
                  if (!isAuto) const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'dup', child: Text('Duplicate')),
                  const PopupMenuItem(value: 'export', child: Text('Export to file')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
