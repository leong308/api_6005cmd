import 'package:api_6005cmd/app/theme/app_palette.dart';
import 'package:flutter/material.dart';

class MacPanel extends StatelessWidget {
  const MacPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppPalette.whiteA(0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.inkA(0.14),
        ),
      ),
      child: child,
    );
  }
}
