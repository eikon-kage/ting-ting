import 'package:flutter/material.dart';

/// Pieces of the "mission control" look that `ThemeData` has no slot for: the
/// bracketed panel border and the faint grid behind every page.
///
/// Modelled on the ARES VII dashboard (miaai-lab, study 076): slate panels on
/// a cyan grid, each with safety-orange brackets on its four corners.
class MissionStyle {
  const MissionStyle._();

  /// Mono face for numbers, labels and headers. Bundled, see `pubspec.yaml`.
  static const String mono = 'JetBrainsMono';

  /// Grid pitch, in logical pixels.
  static const double gridStep = 24;
}

/// A rounded outline with an accent bracket drawn over each corner.
///
/// Used as the card shape, so every `Card` in the app picks it up without the
/// pages knowing. The brackets follow the corner's curve rather than sitting
/// square on top of it, the way a CSS background clipped by `border-radius`
/// does in the reference.
class BracketBorder extends OutlinedBorder {
  const BracketBorder({
    super.side,
    this.radius = 10,
    this.bracketColor = const Color(0xFFFF6B1A),
    this.bracketLength = 14,
    this.bracketWidth = 2,
  });

  final double radius;
  final Color bracketColor;
  final double bracketLength;
  final double bracketWidth;

  RRect _rrect(Rect rect) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect).deflate(side.strokeInset));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none) {
      canvas.drawRRect(
        _rrect(rect).deflate(side.strokeInset / 2),
        side.toPaint(),
      );
    }

    // Stroke centred half a bracket in, so the bracket lies on the edge
    // instead of spilling past it.
    final r = rect.deflate(bracketWidth / 2);
    final cr = (radius - bracketWidth / 2).clamp(0.0, double.infinity);
    final len = bracketLength.clamp(cr, r.shortestSide / 2);
    final arc = Radius.circular(cr);
    final path = Path()
      // top left
      ..moveTo(r.left, r.top + len)
      ..lineTo(r.left, r.top + cr)
      ..arcToPoint(Offset(r.left + cr, r.top), radius: arc)
      ..lineTo(r.left + len, r.top)
      // top right
      ..moveTo(r.right - len, r.top)
      ..lineTo(r.right - cr, r.top)
      ..arcToPoint(Offset(r.right, r.top + cr), radius: arc)
      ..lineTo(r.right, r.top + len)
      // bottom right
      ..moveTo(r.right, r.bottom - len)
      ..lineTo(r.right, r.bottom - cr)
      ..arcToPoint(Offset(r.right - cr, r.bottom), radius: arc)
      ..lineTo(r.right - len, r.bottom)
      // bottom left
      ..moveTo(r.left + len, r.bottom)
      ..lineTo(r.left + cr, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - cr), radius: arc)
      ..lineTo(r.left, r.bottom - len);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = bracketWidth
        ..color = bracketColor.withValues(alpha: 0.9),
    );
  }

  @override
  BracketBorder copyWith({BorderSide? side}) => BracketBorder(
    side: side ?? this.side,
    radius: radius,
    bracketColor: bracketColor,
    bracketLength: bracketLength,
    bracketWidth: bracketWidth,
  );

  @override
  ShapeBorder scale(double t) => BracketBorder(
    side: side.scale(t),
    radius: radius * t,
    bracketColor: bracketColor,
    bracketLength: bracketLength * t,
    bracketWidth: bracketWidth * t,
  );

  @override
  bool operator ==(Object other) =>
      other is BracketBorder &&
      other.side == side &&
      other.radius == radius &&
      other.bracketColor == bracketColor &&
      other.bracketLength == bracketLength &&
      other.bracketWidth == bracketWidth;

  @override
  int get hashCode =>
      Object.hash(side, radius, bracketColor, bracketLength, bracketWidth);
}

/// The page background: the surface colour with a faint grid ruled over it.
///
/// Scaffolds are transparent, so this has to sit under every route. It is
/// added by [GridPageTransitionsBuilder] rather than once around the
/// navigator: a single backdrop shared by all routes would let the outgoing
/// page show through the incoming one for the length of every transition.
class GridBackdrop extends StatelessWidget {
  const GridBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Cyan on slate; on paper the cyan vanishes, so the ink rules it instead.
    final line = scheme.brightness == Brightness.dark
        ? scheme.secondary.withValues(alpha: 0.035)
        : scheme.onSurface.withValues(alpha: 0.045);
    return CustomPaint(
      painter: _GridPainter(scheme.surface, line),
      child: child,
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter(this.fill, this.line);

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    const step = MissionStyle.gridStep;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.fill != fill || old.line != line;
}

/// Wraps another transitions builder so that each route paints its own
/// [GridBackdrop] beneath its page.
class GridPageTransitionsBuilder extends PageTransitionsBuilder {
  const GridPageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  /// The platform defaults, each wrapped.
  static PageTransitionsTheme theme() => PageTransitionsTheme(
    builders: {
      for (final e in const PageTransitionsTheme().builders.entries)
        e.key: GridPageTransitionsBuilder(e.value),
    },
  );

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => inner.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    GridBackdrop(child: child),
  );
}
