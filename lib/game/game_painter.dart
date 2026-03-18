import 'package:flutter/material.dart';

import 'game_controller.dart';

class GamePainter extends CustomPainter {
  GamePainter({
    required this.controller,
    required this.colorScheme,
  }) : super(repaint: controller);

  final GameController controller;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo.
    final background = Paint()..color = colorScheme.surface;
    canvas.drawRect(Offset.zero & size, background);

    // Borde del área.
    final border = Paint()
      ..color = colorScheme.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
        const Radius.circular(14),
      ),
      border,
    );

    if (!controller.isInitialized) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Iniciando...',
          style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      return;
    }

    // Obstáculos (estáticos por ronda).
    final obstacleFill = Paint()..color = colorScheme.secondaryContainer;
    final obstacleStroke = Paint()
      ..color = colorScheme.onSecondaryContainer.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final rect in controller.obstacles) {
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      canvas.drawRRect(rr, obstacleFill);
      canvas.drawRRect(rr, obstacleStroke);
    }

    // Objetivo.
    final targetPaint = Paint()..color = colorScheme.tertiary;
    canvas.drawCircle(controller.targetPos, controller.targetRadius, targetPaint);
    final targetRing = Paint()
      ..color = colorScheme.onTertiary.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      controller.targetPos,
      controller.targetRadius + 10,
      targetRing,
    );

    // Jugador.
    final playerPaint = Paint()..color = colorScheme.primary;
    canvas.drawCircle(controller.playerPos, controller.playerRadius, playerPaint);
    final playerStroke = Paint()
      ..color = colorScheme.onPrimary.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(
      controller.playerPos,
      controller.playerRadius + 8,
      playerStroke,
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.colorScheme != colorScheme;
  }
}
