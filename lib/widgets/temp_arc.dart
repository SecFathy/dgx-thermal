import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/thermal_data.dart';

class TempArc extends StatelessWidget {
  final double temperature;
  final double maxTemp;
  final ThermalLevel level;
  final double size;

  const TempArc({
    super.key,
    required this.temperature,
    this.maxTemp = 100,
    required this.level,
    this.size = 100,
  });

  Color get _arcColor {
    switch (level) {
      case ThermalLevel.critical:
        return const Color(0xFFFF3B30);
      case ThermalLevel.warning:
        return const Color(0xFFFF9500);
      case ThermalLevel.normal:
        return const Color(0xFF30D158);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (temperature / maxTemp).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcPainter(
          progress: pct,
          trackColor: Colors.white12,
          arcColor: _arcColor,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${temperature.toStringAsFixed(0)}°',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.bold,
                  color: _arcColor,
                ),
              ),
              Text(
                'C',
                style: TextStyle(
                  fontSize: size * 0.12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;

  _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;
    const startAngle = math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = arcColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.arcColor != arcColor;
}
