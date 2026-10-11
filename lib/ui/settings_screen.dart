import 'package:flutter/material.dart';

import '../core/sfx.dart';
import '../core/storage.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Settings get s => Storage.settings;

  void _save() {
    Storage.saveSettings();
    Sfx.volume = s.volume;
    Sfx.enabled = s.sound;
    setState(() {});
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(t.toUpperCase(), style: const TextStyle(color: RB.redHi, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(children: [
        _header('Sound'),
        SwitchListTile(title: const Text('Sound effects'), value: s.sound, onChanged: (v) {
          s.sound = v;
          _save();
        }),
        ListTile(
          title: const Text('Volume'),
          subtitle: Slider(
            value: s.volume,
            onChanged: (v) {
              s.volume = v;
              _save();
            },
            onChangeEnd: (_) => Sfx.play('pistol', vol: 0.8),
          ),
        ),
        SwitchListTile(title: const Text('Vibration on explosions'), value: s.haptics, onChanged: (v) {
          s.haptics = v;
          _save();
        }),
        _header('Gameplay'),
        SwitchListTile(
          title: const Text('Blood and gore'),
          subtitle: const Text('Blood, wounds, dismemberment. Off keeps sparks and debris only.'),
          value: s.gore,
          onChanged: (v) {
            s.gore = v;
            _save();
          },
        ),
        SwitchListTile(title: const Text('Show tool hints'), value: s.showHints, onChanged: (v) {
          s.showHints = v;
          _save();
        }),
        ListTile(
          title: const Text('Physics quality'),
          subtitle: const Text('Higher is stiffer and more stable but uses more battery.'),
          trailing: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Low')),
              ButtonSegment(value: 1, label: Text('Normal')),
              ButtonSegment(value: 2, label: Text('High')),
            ],
            selected: {s.quality},
            onSelectionChanged: (v) {
              s.quality = v.first;
              _save();
            },
          ),
        ),
        ListTile(
          title: Text('Object limit: ${s.maxEntities}'),
          subtitle: Slider(
            value: s.maxEntities.toDouble(),
            min: 50,
            max: 1000,
            divisions: 19,
            onChanged: (v) {
              s.maxEntities = v.round();
              _save();
            },
          ),
        ),
        SwitchListTile(title: const Text('Show FPS counter'), value: s.showFps, onChanged: (v) {
          s.showFps = v;
          _save();
        }),
        _header('Saving'),
        SwitchListTile(
          title: const Text('Autosave'),
          subtitle: const Text('Your current scene is saved on this device automatically.'),
          value: s.autosave,
          onChanged: (v) {
            s.autosave = v;
            _save();
          },
        ),
        ListTile(
          title: Text('Autosave every ${s.autosaveSeconds} s'),
          subtitle: Slider(
            value: s.autosaveSeconds.toDouble(),
            min: 15,
            max: 300,
            divisions: 19,
            onChanged: (v) {
              s.autosaveSeconds = v.round();
              _save();
            },
          ),
        ),
        ListTile(
          title: const Text('Clear favourites'),
          trailing: const Icon(Icons.star_outline),
          onTap: () {
            s.favorites.clear();
            _save();
          },
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('All data stays on this device. Ragbox has no accounts, no ads, no analytics and never connects to the internet.',
              style: TextStyle(color: RB.dim, fontSize: 12)),
        ),
      ]),
    );
  }
}
