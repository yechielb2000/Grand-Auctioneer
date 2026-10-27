import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppIcon extends StatelessWidget {
  const AppIcon({
    required this.assetName,
    required this.color,
    this.size = 24,
    this.semanticLabel,
    super.key,
  });

  final String assetName;
  final Color color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        assetName,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        semanticsLabel: semanticLabel,
      );
}
