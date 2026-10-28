import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';

enum PropertyArtStyle { shed, apartment, villa, marina }

class IsometricPropertyArt extends StatelessWidget {
  const IsometricPropertyArt({
    required this.style,
    this.size = 82,
    super.key,
  });

  final PropertyArtStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size * .82),
        painter: _IsometricPropertyPainter(style),
      );
}

class GameItemArtwork extends StatelessWidget {
  const GameItemArtwork({
    required this.icon,
    this.category,
    this.size = 52,
    this.color = AppColors.primaryGold,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String? category;
  final double size;
  final Color color;
  final String? semanticLabel;

  String? get _categoryAsset => switch (category) {
        'Furniture' => AppAssets.furniture,
        'Vehicles' => AppAssets.vehicle,
        'Boats' => AppAssets.boat,
        'Real Estate' => AppAssets.realEstate,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final categoryAsset = _categoryAsset;
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: .2),
              const Color(0xFF171D29),
            ],
          ),
          borderRadius: BorderRadius.circular(size * .25),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: size * .05,
              child: Container(
                width: size * .55,
                height: size * .14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .18),
                  borderRadius: BorderRadius.all(Radius.elliptical(size, size)),
                ),
              ),
            ),
            if (categoryAsset != null)
              AppIcon(
                assetName: categoryAsset,
                color: color,
                size: size * .54,
              )
            else
              Icon(icon, color: color, size: size * .54),
          ],
        ),
      ),
    );
  }
}

class _IsometricPropertyPainter extends CustomPainter {
  const _IsometricPropertyPainter(this.style);

  final PropertyArtStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shadow = Paint()..color = Colors.black.withValues(alpha: .3);
    final tile = Paint()..color = const Color(0xFF243A35);
    final tileSide = Paint()..color = const Color(0xFF172722);
    final edge = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final diamond = Path()
      ..moveTo(w * .5, h * .53)
      ..lineTo(w * .98, h * .72)
      ..lineTo(w * .5, h * .92)
      ..lineTo(w * .02, h * .72)
      ..close();
    canvas.drawOval(
      Rect.fromLTRB(w * .12, h * .7, w * .88, h * .99),
      shadow,
    );
    canvas.drawPath(diamond, tileSide);
    canvas.drawPath(
      Path()
        ..moveTo(w * .02, h * .72)
        ..lineTo(w * .5, h * .92)
        ..lineTo(w * .5, h * .99)
        ..lineTo(w * .02, h * .79)
        ..close(),
      tileSide,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .5, h * .92)
        ..lineTo(w * .98, h * .72)
        ..lineTo(w * .98, h * .79)
        ..lineTo(w * .5, h * .99)
        ..close(),
      Paint()..color = const Color(0xFF1D302B),
    );
    canvas.drawPath(diamond, tile);
    canvas.drawPath(diamond, edge);
    final wall = Paint()..color = const Color(0xFFD8C9A8);
    final roof = Paint()..color = const Color(0xFF735141);
    final window = Paint()..color = const Color(0xFF6AC6D1);
    final dark = Paint()..color = const Color(0xFF322A27);

    switch (style) {
      case PropertyArtStyle.shed:
        _drawGable(
          canvas,
          w,
          h,
          left: .3,
          right: .7,
          peak: .2,
          eave: .43,
          wall: wall,
          roof: roof,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .45, h * .43, w * .56, h * .66),
          dark,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .33, h * .46, w * .41, h * .54),
          window,
        );
        break;
      case PropertyArtStyle.apartment:
        canvas.drawRect(
          Rect.fromLTRB(w * .31, h * .25, w * .69, h * .67),
          wall,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .31, h * .25, w * .69, h * .31),
          roof,
        );
        for (final x in [.38, .53, .62]) {
          for (final y in [.37, .49, .59]) {
            canvas.drawRect(
              Rect.fromLTRB(w * x, h * y, w * (x + .07), h * (y + .06)),
              window,
            );
          }
        }
        break;
      case PropertyArtStyle.villa:
        _drawGable(
          canvas,
          w,
          h,
          left: .22,
          right: .78,
          peak: .18,
          eave: .39,
          wall: wall,
          roof: roof,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .3, h * .39, w * .7, h * .66),
          wall,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .43, h * .48, w * .56, h * .66),
          dark,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .32, h * .44, w * .4, h * .52),
          window,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .6, h * .44, w * .68, h * .52),
          window,
        );
        break;
      case PropertyArtStyle.marina:
        canvas.drawRect(
          Rect.fromLTRB(w * .3, h * .35, w * .65, h * .65),
          wall,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .27, h * .31, w * .68, h * .37),
          roof,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .39, h * .43, w * .48, h * .51),
          window,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .53, h * .43, w * .61, h * .51),
          window,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * .2, h * .69)
            ..lineTo(w * .8, h * .69)
            ..lineTo(w * .7, h * .75)
            ..lineTo(w * .3, h * .75)
            ..close(),
          Paint()..color = const Color(0xFF3B7A84),
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .34, h * .75, w * .66, h * .79),
          Paint()..color = const Color(0xFF9A7652),
        );
        break;
    }
  }

  void _drawGable(
    Canvas canvas,
    double width,
    double height, {
    required double left,
    required double right,
    required double peak,
    required double eave,
    required Paint wall,
    required Paint roof,
  }) {
    canvas.drawRect(
      Rect.fromLTRB(width * left, height * eave, width * right, height * .66),
      wall,
    );
    canvas.drawPath(
      Path()
        ..moveTo(width * (left - .06), height * eave)
        ..lineTo(width * .5, height * peak)
        ..lineTo(width * (right + .06), height * eave)
        ..close(),
      roof,
    );
  }

  @override
  bool shouldRepaint(_IsometricPropertyPainter oldDelegate) =>
      style != oldDelegate.style;
}
