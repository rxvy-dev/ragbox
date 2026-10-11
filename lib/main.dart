import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/errors.dart';
import 'core/sfx.dart';
import 'core/storage.dart';
import 'ui/menu_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Errors.install();
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (e, st) {
    Errors.record(e, st, where: 'startup');
  }
  try {
    await Storage.init();
  } catch (e, st) {
    Errors.record(e, st, where: 'storage');
  }
  Sfx.volume = Storage.settings.volume;
  Sfx.enabled = Storage.settings.sound;
  runApp(const RagboxApp());
  // Sound synthesis runs after the first frame so the menu appears instantly.
  Future.delayed(const Duration(milliseconds: 300), () async {
    try {
      await Sfx.init(Storage.root);
    } catch (e, st) {
      Errors.record(e, st, where: 'sound');
    }
  });
}

class RagboxApp extends StatelessWidget {
  const RagboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ragbox',
      debugShowCheckedModeBanner: false,
      theme: RB.theme(),
      builder: (context, child) => ErrorOverlay(child: child ?? const SizedBox.shrink()),
      home: const MenuScreen(),
    );
  }
}
