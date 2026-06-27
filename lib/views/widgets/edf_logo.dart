import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';

/// ─── Logo EDF Catálogo ───────────────────────────────────────────────────────
///
/// Variantes:
///   - [EdfLogo.icon]       → solo el icono cuadrado (para drawer header, splashscreen)
///   - [EdfLogo.horizontal] → icono + texto en fila (appbar, login)
///   - [EdfLogo.stacked]    → icono + texto en columna (login centrado)

// ── Icono EDF (marca geométrica) ──────────────────────────────────────────────
class EdfLogoIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const EdfLogoIcon({super.key, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EdfMarkPainter(color: c),
      ),
    );
  }
}

/// Painter de la marca EDF: tres barras horizontales de longitud decreciente,
/// estilizando la letra "E" como páginas de un catálogo.
class _EdfMarkPainter extends CustomPainter {
  final Color color;
  const _EdfMarkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Fondo redondeado
    final bgPaint = Paint()..color = color.withValues(alpha: 0.12);
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w * 0.25),
    );
    canvas.drawRRect(bgRect, bgPaint);

    // Tres barras: top, middle, bottom
    // La de arriba es la más larga, la de abajo la más corta → E de catálogo
    const barCount = 3;
    final barHeight = h * 0.12;
    final barRadius = Radius.circular(barHeight / 2);
    final paddingH = w * 0.18;
    final paddingV = h * 0.22;
    final gap = (h - 2 * paddingV - barCount * barHeight) / (barCount - 1);

    final widths = [w - 2 * paddingH, (w - 2 * paddingH) * 0.72, (w - 2 * paddingH) * 0.5];

    for (int i = 0; i < barCount; i++) {
      final y = paddingV + i * (barHeight + gap);
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(paddingH, y, widths[i], barHeight),
        barRadius,
      );
      canvas.drawRRect(barRect, paint);
    }
  }

  @override
  bool shouldRepaint(_EdfMarkPainter old) => old.color != color;
}

// ── Logo horizontal (icono + texto) ───────────────────────────────────────────
class EdfLogoHorizontal extends StatelessWidget {
  final double iconSize;
  final double? fontSize;
  final Color? color;

  const EdfLogoHorizontal({
    super.key,
    this.iconSize = 36,
    this.fontSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final fs = fontSize ?? iconSize * 0.55;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        EdfLogoIcon(size: iconSize, color: c),
        SizedBox(width: iconSize * 0.3),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EDF',
              style: GoogleFonts.inter(
                fontSize: fs,
                fontWeight: FontWeight.w800,
                color: c,
                letterSpacing: -0.5,
                height: 1.0,
              ),
            ),
            Text(
              'Catálogo',
              style: GoogleFonts.inter(
                fontSize: fs * 0.7,
                fontWeight: FontWeight.w400,
                color: c.withValues(alpha: 0.7),
                letterSpacing: 0.5,
                height: 1.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Logo apilado (icono grande + texto debajo) ─────────────────────────────────
class EdfLogoStacked extends StatelessWidget {
  final double iconSize;
  final Color? color;

  const EdfLogoStacked({super.key, this.iconSize = 72, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono con sombra suave
        Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(iconSize * 0.25),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.25),
                blurRadius: iconSize * 0.4,
                offset: Offset(0, iconSize * 0.12),
              ),
            ],
          ),
          child: EdfLogoIcon(size: iconSize, color: c),
        ),
        SizedBox(height: iconSize * 0.2),
        Text(
          'EDF',
          style: GoogleFonts.inter(
            fontSize: iconSize * 0.42,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: -1,
            height: 1.0,
          ),
        ),
        Text(
          'Catálogo',
          style: GoogleFonts.inter(
            fontSize: iconSize * 0.22,
            fontWeight: FontWeight.w400,
            color: c.withValues(alpha: 0.65),
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

// ── Badge de versión ──────────────────────────────────────────────────────────
class EdfVersionBadge extends StatelessWidget {
  final String version;
  const EdfVersionBadge({super.key, this.version = '1.1'});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        'v$version',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.onPrimaryContainer,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
