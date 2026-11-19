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
    this.itemName,
    this.category,
    this.size = 52,
    this.color = AppColors.primaryGold,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  /// Stable seeded or user-facing item name used to select object artwork.
  /// Unknown names keep the source-compatible [icon] fallback.
  final String? itemName;
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

  _GameObjectArt? get _objectArt => switch (_normalizedName) {
        'vintage velvet sofa' || 'sofa' => _GameObjectArt.sofa,
        'classic city scooter' || 'scooter' => _GameObjectArt.scooter,
        'retro arcade cabinet' || 'arcade cabinet' => _GameObjectArt.arcade,
        'midnight gt coupe' || 'gt coupe' => _GameObjectArt.coupe,
        'modernist penthouse art' || 'penthouse art' => _GameObjectArt.painting,
        'coastal speedboat' || 'speedboat' => _GameObjectArt.speedboat,
        'art deco wall clock' || 'wall clock' => _GameObjectArt.clock,
        _ => null,
      };

  String get _normalizedName => itemName?.trim().toLowerCase() ?? '';

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
            if (_objectArt case final art?)
              CustomPaint(
                size: Size.square(size * .68),
                painter: _GameObjectPainter(art, color),
              )
            else if (categoryAsset != null)
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

enum _GameObjectArt { sofa, scooter, arcade, coupe, painting, speedboat, clock }

/// Small, scalable illustrations for the game's recognizable inventory items.
class _GameObjectPainter extends CustomPainter {
  const _GameObjectPainter(this.art, this.accent);

  final _GameObjectArt art;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 100;
    final sy = size.height / 100;
    canvas.save();
    canvas.scale(sx, sy);
    final ink = Paint()..color = const Color(0xFF222A36);
    final trim = Paint()..color = accent;
    final light = Paint()..color = const Color(0xFFE8DCC1);
    final glass = Paint()..color = const Color(0xFF77C7D1);
    final dark = Paint()..color = const Color(0xFF121923);
    final stroke = Paint()
      ..color = accent.withValues(alpha: .9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (art) {
      case _GameObjectArt.sofa:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(13, 39, 87, 73), const Radius.circular(10)), trim);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(19, 43, 81, 68), const Radius.circular(7)), ink);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(22, 23, 49, 49), const Radius.circular(9)), trim);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(51, 23, 78, 49), const Radius.circular(9)), trim);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(25, 27, 47, 45), const Radius.circular(6)), ink);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(53, 27, 75, 45), const Radius.circular(6)), ink);
        canvas.drawLine(const Offset(50, 51), const Offset(50, 67), stroke);
        canvas.drawLine(const Offset(23, 73), const Offset(20, 84), stroke);
        canvas.drawLine(const Offset(77, 73), const Offset(80, 84), stroke);
        break;
      case _GameObjectArt.scooter:
        canvas.drawCircle(const Offset(24, 75), 10, stroke);
        canvas.drawCircle(const Offset(76, 75), 10, stroke);
        canvas.drawLine(const Offset(24, 75), const Offset(40, 75), stroke);
        canvas.drawLine(const Offset(40, 75), const Offset(53, 53), stroke);
        canvas.drawLine(const Offset(53, 53), const Offset(68, 75), stroke);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(38, 48, 61, 59), const Radius.circular(5)), trim);
        canvas.drawLine(const Offset(54, 51), const Offset(61, 30), stroke);
        canvas.drawLine(const Offset(61, 30), const Offset(75, 30), stroke);
        canvas.drawLine(const Offset(61, 30), const Offset(58, 24), stroke);
        canvas.drawLine(const Offset(42, 48), const Offset(49, 42), stroke);
        canvas.drawLine(const Offset(26, 65), const Offset(34, 53), stroke);
        canvas.drawCircle(const Offset(76, 75), 3, light);
        break;
      case _GameObjectArt.arcade:
        canvas.drawPath(Path()..moveTo(27, 17)..lineTo(73, 17)..lineTo(80, 28)..lineTo(80, 85)..lineTo(20, 85)..lineTo(20, 28)..close(), ink);
        canvas.drawPath(Path()..moveTo(27, 17)..lineTo(73, 17)..lineTo(80, 28)..lineTo(20, 28)..close(), trim);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(28, 34, 72, 57), const Radius.circular(3)), glass);
        canvas.drawRect(const Rect.fromLTRB(32, 38, 68, 53), dark);
        canvas.drawPath(Path()..moveTo(39, 49)..lineTo(47, 40)..lineTo(55, 49)..lineTo(61, 43), stroke);
        canvas.drawLine(const Offset(32, 64), const Offset(68, 64), stroke);
        canvas.drawCircle(const Offset(39, 73), 4, trim);
        canvas.drawCircle(const Offset(61, 73), 4, light);
        canvas.drawLine(const Offset(25, 85), const Offset(22, 92), stroke);
        canvas.drawLine(const Offset(75, 85), const Offset(78, 92), stroke);
        break;
      case _GameObjectArt.coupe:
        canvas.drawPath(Path()..moveTo(9, 67)..lineTo(17, 53)..lineTo(34, 47)..lineTo(47, 31)..quadraticBezierTo(51, 27, 59, 28)..lineTo(75, 34)..lineTo(87, 52)..lineTo(94, 60)..lineTo(91, 72)..lineTo(10, 72)..close(), trim);
        canvas.drawPath(Path()..moveTo(35, 47)..lineTo(49, 32)..quadraticBezierTo(54, 30, 59, 32)..lineTo(71, 37)..lineTo(79, 49)..close(), glass);
        canvas.drawLine(const Offset(56, 32), const Offset(55, 48), stroke);
        canvas.drawLine(const Offset(13, 61), const Offset(22, 61), stroke);
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(77, 56, 88, 61), const Radius.circular(2)), light);
        canvas.drawCircle(const Offset(29, 72), 10, dark);
        canvas.drawCircle(const Offset(29, 72), 5, light);
        canvas.drawCircle(const Offset(75, 72), 10, dark);
        canvas.drawCircle(const Offset(75, 72), 5, light);
        break;
      case _GameObjectArt.painting:
        canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(20, 12, 80, 88), const Radius.circular(3)), trim);
        canvas.drawRect(const Rect.fromLTRB(27, 19, 73, 81), ink);
        canvas.drawCircle(const Offset(59, 36), 10, light);
        canvas.drawPath(Path()..moveTo(31, 73)..lineTo(45, 48)..lineTo(54, 60)..lineTo(63, 45)..lineTo(70, 73)..close(), glass);
        canvas.drawLine(const Offset(33, 76), const Offset(67, 76), stroke);
        break;
      case _GameObjectArt.speedboat:
        canvas.drawPath(Path()..moveTo(9, 63)..lineTo(91, 63)..lineTo(76, 81)..lineTo(28, 81)..close(), trim);
        canvas.drawPath(Path()..moveTo(19, 65)..lineTo(31, 72)..lineTo(72, 72)..lineTo(82, 65)..close(), ink);
        canvas.drawPath(Path()..moveTo(39, 61)..lineTo(43, 43)..lineTo(65, 43)..lineTo(75, 61)..close(), light);
        canvas.drawRect(const Rect.fromLTRB(47, 47, 61, 57), glass);
        canvas.drawLine(const Offset(21, 88), const Offset(40, 88), stroke);
        canvas.drawLine(const Offset(51, 91), const Offset(72, 91), stroke);
        canvas.drawLine(const Offset(73, 86), const Offset(88, 86), stroke);
        break;
      case _GameObjectArt.clock:
        canvas.drawPath(Path()..moveTo(50, 9)..lineTo(72, 22)..lineTo(78, 50)..lineTo(72, 78)..lineTo(50, 91)..lineTo(28, 78)..lineTo(22, 50)..lineTo(28, 22)..close(), trim);
        canvas.drawCircle(const Offset(50, 49), 22, ink);
        canvas.drawCircle(const Offset(50, 49), 17, light);
        canvas.drawCircle(const Offset(50, 49), 2.5, trim);
        canvas.drawLine(const Offset(50, 49), const Offset(50, 36), stroke);
        canvas.drawLine(const Offset(50, 49), const Offset(61, 54), stroke);
        canvas.drawCircle(const Offset(50, 18), 2, light);
        canvas.drawCircle(const Offset(50, 80), 2, light);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GameObjectPainter oldDelegate) =>
      art != oldDelegate.art || accent != oldDelegate.accent;
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
