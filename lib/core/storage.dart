import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'native.dart';

/// Player settings, persisted to settings.json on the device.
class Settings {
  double volume = 0.8;
  bool sound = true;
  bool haptics = true;
  bool gore = true;
  bool showFps = false;
  int quality = 1; // 0 low, 1 normal, 2 high
  bool autosave = true;
  int autosaveSeconds = 60;
  int maxEntities = 400;
  bool showHints = true;
  List<String> favorites = [];

  int get iterations => quality == 0 ? 6 : (quality == 1 ? 8 : 12);

  Map<String, dynamic> toJson() => {
        'volume': volume,
        'sound': sound,
        'haptics': haptics,
        'gore': gore,
        'showFps': showFps,
        'quality': quality,
        'autosave': autosave,
        'autosaveSeconds': autosaveSeconds,
        'maxEntities': maxEntities,
        'showHints': showHints,
        'favorites': favorites,
      };

  void fromJson(Map<String, dynamic> j) {
    volume = (j['volume'] as num?)?.toDouble() ?? volume;
    sound = j['sound'] as bool? ?? sound;
    haptics = j['haptics'] as bool? ?? haptics;
    gore = j['gore'] as bool? ?? gore;
    showFps = j['showFps'] as bool? ?? showFps;
    quality = (j['quality'] as num?)?.toInt() ?? quality;
    autosave = j['autosave'] as bool? ?? autosave;
    autosaveSeconds = (j['autosaveSeconds'] as num?)?.toInt() ?? autosaveSeconds;
    maxEntities = (j['maxEntities'] as num?)?.toInt() ?? maxEntities;
    showHints = j['showHints'] as bool? ?? showHints;
    favorites = ((j['favorites'] as List?) ?? const []).map((e) => e.toString()).toList();
  }
}

class SaveMeta {
  final String id;
  String name;
  final String map;
  final int created;
  int updated;
  final int count;
  SaveMeta(this.id, this.name, this.map, this.created, this.updated, this.count);
}

/// All persistence lives here. Files are written to the app's private
/// storage directory; nothing ever leaves the device unless the player
/// explicitly exports a backup through the system file picker.
class Storage {
  static late String root;
  static final Settings settings = Settings();
  static bool _ready = false;
  static const autosaveId = 'autosave';

  static Directory get savesDir => Directory('$root/saves');
  static File get _settingsFile => File('$root/settings.json');
  static File get _charsFile => File('$root/characters.json');

  static Future<void> init() async {
    if (_ready) return;
    root = await Native.filesDir();
    if (!savesDir.existsSync()) savesDir.createSync(recursive: true);
    try {
      if (_settingsFile.existsSync()) {
        settings.fromJson(jsonDecode(_settingsFile.readAsStringSync()) as Map<String, dynamic>);
      }
    } catch (_) {
      // corrupt settings: keep defaults
    }
    _ready = true;
  }

  static void saveSettings() {
    _writeAtomic(_settingsFile, jsonEncode(settings.toJson()));
  }

  /// Writes through a temp file so a crash never leaves a half-written save.
  static void _writeAtomic(File f, String content) {
    final tmp = File('${f.path}.tmp');
    tmp.writeAsStringSync(content, flush: true);
    tmp.renameSync(f.path);
  }

  static String newId() {
    final r = math.Random();
    final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '$t${r.nextInt(1 << 20).toRadixString(36)}';
  }

  // ------------------------------------------------------------------ scenes
  static File sceneFile(String id) => File('${savesDir.path}/$id.json');
  static File thumbFile(String id) => File('${savesDir.path}/$id.png');

  static void writeScene(String id, Map<String, dynamic> scene, {Uint8List? thumb}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final old = readMeta(id);
    scene['meta'] = {
      'id': id,
      'name': scene['name'] ?? 'Untitled',
      'map': scene['map'] ?? 'flat',
      'created': old?.created ?? now,
      'updated': now,
      'count': (scene['entities'] as List?)?.length ?? 0,
    };
    _writeAtomic(sceneFile(id), jsonEncode(scene));
    if (thumb != null) {
      try {
        thumbFile(id).writeAsBytesSync(thumb, flush: true);
      } catch (_) {}
    }
  }

  static Map<String, dynamic>? readScene(String id) {
    final f = sceneFile(id);
    if (!f.existsSync()) return null;
    try {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static SaveMeta? readMeta(String id) {
    final j = readScene(id);
    if (j == null) return null;
    return _meta(id, j);
  }

  static SaveMeta _meta(String id, Map<String, dynamic> j) {
    final m = (j['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    return SaveMeta(
      id,
      m['name'] as String? ?? j['name'] as String? ?? 'Untitled',
      m['map'] as String? ?? j['map'] as String? ?? 'flat',
      (m['created'] as num?)?.toInt() ?? 0,
      (m['updated'] as num?)?.toInt() ?? 0,
      (m['count'] as num?)?.toInt() ?? 0,
    );
  }

  static List<SaveMeta> listScenes({bool includeAutosave = true}) {
    final out = <SaveMeta>[];
    if (!savesDir.existsSync()) return out;
    for (final f in savesDir.listSync()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final name = f.uri.pathSegments.last;
      final id = name.substring(0, name.length - 5);
      if (!includeAutosave && id == autosaveId) continue;
      try {
        final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        out.add(_meta(id, j));
      } catch (_) {
        // skip unreadable files
      }
    }
    out.sort((a, b) => b.updated.compareTo(a.updated));
    return out;
  }

  static bool hasAutosave() => sceneFile(autosaveId).existsSync();

  static void deleteScene(String id) {
    try {
      sceneFile(id).deleteSync();
    } catch (_) {}
    try {
      if (thumbFile(id).existsSync()) thumbFile(id).deleteSync();
    } catch (_) {}
  }

  static void renameScene(String id, String name) {
    final j = readScene(id);
    if (j == null) return;
    j['name'] = name;
    writeScene(id, j);
  }

  static String duplicateScene(String id) {
    final j = readScene(id);
    if (j == null) return id;
    final nid = newId();
    j['name'] = '${j['name'] ?? 'Untitled'} (copy)';
    j.remove('meta');
    writeScene(nid, j);
    if (thumbFile(id).existsSync()) {
      try {
        thumbFile(id).copySync(thumbFile(nid).path);
      } catch (_) {}
    }
    return nid;
  }

  // ------------------------------------------------------------------ characters
  static List<Map<String, dynamic>> loadCharacters() {
    try {
      if (!_charsFile.existsSync()) return [];
      final l = jsonDecode(_charsFile.readAsStringSync()) as List;
      return l.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  static void saveCharacters(List<Map<String, dynamic>> chars) {
    _writeAtomic(_charsFile, jsonEncode(chars));
  }

  // ------------------------------------------------------------------ backup
  static String backupJson() {
    final scenes = <Map<String, dynamic>>[];
    for (final m in listScenes(includeAutosave: false)) {
      final j = readScene(m.id);
      if (j != null) scenes.add(j);
    }
    return jsonEncode({
      'format': 'ragbox-backup',
      'version': 1,
      'exported': DateTime.now().toIso8601String(),
      'scenes': scenes,
      'characters': loadCharacters(),
      'settings': settings.toJson(),
    });
  }

  /// Imports a backup bundle or a single exported scene. Returns a short
  /// human readable summary, or throws a [FormatException].
  static String importJson(String text) {
    final j = jsonDecode(text);
    if (j is! Map) throw const FormatException('Not a Ragbox file');
    final map = j.cast<String, dynamic>();
    final fmt = map['format'];
    if (fmt == 'ragbox-scene') {
      final scene = Map<String, dynamic>.from(map)..remove('meta');
      writeScene(newId(), scene);
      return 'Imported scene "${map['name'] ?? 'Untitled'}"';
    }
    if (fmt == 'ragbox-backup') {
      var nScenes = 0, nChars = 0;
      for (final s in (map['scenes'] as List? ?? const [])) {
        final scene = (s as Map).cast<String, dynamic>()..remove('meta');
        writeScene(newId(), scene);
        nScenes++;
      }
      final chars = loadCharacters();
      final known = chars.map((c) => c['uid']).toSet();
      for (final c in (map['characters'] as List? ?? const [])) {
        final cm = (c as Map).cast<String, dynamic>();
        if (known.contains(cm['uid'])) continue;
        chars.add(cm);
        nChars++;
      }
      saveCharacters(chars);
      return 'Imported $nScenes scenes and $nChars characters';
    }
    if (fmt == 'ragbox-character') {
      final chars = loadCharacters();
      final cm = (map['character'] as Map).cast<String, dynamic>();
      cm['uid'] = newId();
      chars.add(cm);
      saveCharacters(chars);
      return 'Imported character "${cm['name'] ?? 'Custom'}"';
    }
    throw const FormatException('Unknown file format');
  }
}
