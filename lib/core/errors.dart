import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// App-wide error capture. Any Flutter or Dart error is recorded here and
/// shown on top of every screen (see [ErrorOverlay]) so problems are visible
/// on the phone without needing adb/logcat.
class Errors {
  static final ValueNotifier<String?> last = ValueNotifier(null);

  static void record(Object e, StackTrace? st, {String where = ''}) {
    final lines = (st?.toString() ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(8).join('\n');
    final msg = '${where.isEmpty ? '' : '[$where] '}$e\n$lines';
    debugPrint('Ragbox error: $msg');
    last.value ??= msg;
  }

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      record(details.exception, details.stack, where: details.library ?? 'flutter');
    };
    PlatformDispatcher.instance.onError = (e, st) {
      record(e, st, where: 'dart');
      return true;
    };
    ErrorWidget.builder = (details) => Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            color: const Color(0xFF5A0000),
            padding: const EdgeInsets.all(8),
            child: Text(
              'Error: ${details.exceptionAsString()}',
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 11),
            ),
          ),
        );
  }
}

/// Wraps the whole app and shows the first recorded error in a red panel.
class ErrorOverlay extends StatelessWidget {
  final Widget child;
  const ErrorOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [
        Positioned.fill(child: child),
        ValueListenableBuilder<String?>(
          valueListenable: Errors.last,
          builder: (_, err, __) {
            if (err == null) return const SizedBox.shrink();
            return Positioned(
              left: 40,
              right: 40,
              top: 40,
              child: Material(
                color: const Color(0xF27F0000),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => Errors.last.value = null,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Ragbox hit an error (tap to dismiss). Screenshot this and send it:\n\n$err',
                      maxLines: 14,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}
