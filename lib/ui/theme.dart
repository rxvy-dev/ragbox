import 'package:flutter/material.dart';

class RB {
  static const bg = Color(0xFF0E0C0F);
  static const panel = Color(0xFF1A161B);
  static const panel2 = Color(0xFF241E25);
  static const line = Color(0xFF3A3038);
  static const red = Color(0xFFC62828);
  static const redHi = Color(0xFFE53935);
  static const text = Color(0xFFEDE6E8);
  static const dim = Color(0xFF9C8F96);

  static ThemeData theme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: red,
        secondary: redHi,
        surface: panel,
        onPrimary: Colors.white,
        onSurface: text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 3, color: text),
      ),
      sliderTheme: base.sliderTheme.copyWith(activeTrackColor: red, thumbColor: redHi),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? redHi : dim),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? red.withValues(alpha: 0.5) : line),
      ),
      snackBarTheme: const SnackBarThemeData(backgroundColor: panel2, contentTextStyle: TextStyle(color: text)),
    );
  }

  static const title = TextStyle(
    fontSize: 54,
    fontWeight: FontWeight.w900,
    letterSpacing: 10,
    color: text,
    height: 1,
  );

  static const label = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: dim);
}

/// Square-ish dark button used across the HUD.
class HudButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final bool active;
  final Color? color;
  final double size;
  const HudButton(this.icon, {super.key, this.label, this.onTap, this.active = false, this.color, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final bg = active ? RB.red : (color ?? const Color(0xCC1A161B));
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minWidth: size, minHeight: size),
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? RB.redHi : RB.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 21, color: RB.text),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(label!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RB.text)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  const MenuButton(this.text, this.icon, this.onTap, {super.key, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: primary ? RB.red : RB.panel,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary ? RB.redHi : RB.line),
            ),
            child: Row(children: [
              Icon(icon, color: RB.text, size: 22),
              const SizedBox(width: 14),
              Text(text.toUpperCase(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 2, color: RB.text)),
            ]),
          ),
        ),
      ),
    );
  }
}
