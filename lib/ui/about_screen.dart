import 'package:flutter/material.dart';

import '../game/catalog.dart';
import 'theme.dart';

const appVersion = '1.1.0';

const mitLicense = '''MIT License

Copyright (c) 2026 rxvy and Ragbox contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final i in Catalog.visible) {
      counts[i.category] = (counts[i.category] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ABOUT')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('RAGBOX', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 8)),
        const Text('v$appVersion · free and open-source physics sandbox', style: TextStyle(color: RB.dim)),
        const SizedBox(height: 16),
        const Text(
          'Spawn people, weapons, vehicles and machines and see what happens. '
          'Everything is free: no ads, no purchases, no accounts, no internet. '
          'Your scenes, characters and settings are stored only on this device; '
          'you can export them to a file for backup at any time.',
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in counts.entries)
            Chip(label: Text('${e.value} ${e.key}'), backgroundColor: RB.panel),
        ]),
        const SizedBox(height: 16),
        const Text(
          'All art is drawn procedurally in code and every sound is synthesised on the device, '
          'so the game ships with no third-party assets. Ragbox is an original game inspired by '
          'the ragdoll sandbox genre; it is not affiliated with any other game.',
          style: TextStyle(color: RB.dim, fontSize: 12),
        ),
        const SizedBox(height: 20),
        const Text('LICENSE', style: RB.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: RB.panel, borderRadius: BorderRadius.circular(10)),
          child: const Text(mitLicense, style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => showLicensePage(context: context, applicationName: 'Ragbox', applicationVersion: appVersion),
          child: const Text('Flutter & open-source notices'),
        ),
      ]),
    );
  }
}
