import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class Wallpaper extends StatelessWidget {
  const Wallpaper({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Color tint = context.appPalette.wallpaperTint;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint,
        image: DecorationImage(
          image: const AssetImage('assets/wallpaper.png'),
          repeat: ImageRepeat.repeat,
          alignment: Alignment.topLeft,
          colorFilter: ColorFilter.mode(tint, BlendMode.modulate),
        ),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
  }
}
