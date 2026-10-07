import 'dart:math' as math;
import 'package:flutter/material.dart';

class CountryFlag extends StatelessWidget {
  const CountryFlag(this.code, {super.key, this.width = 32});
  final String code;
  final double width;
  @override
  Widget build(BuildContext context) => Semantics(
    label: code == 'vi' ? 'Việt Nam' : 'United States',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: CustomPaint(
        size: Size(width, width * .67),
        painter: _FlagPainter(code),
      ),
    ),
  );
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.code);
  final String code;
  void star(Canvas canvas, Offset centre, double radius, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * .382;
      final x = centre.dx + math.cos(angle) * r;
      final y = centre.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    if (code == 'vi') {
      canvas.drawRect(
        Offset.zero & size,
        paint..color = const Color(0xffda251d),
      );
      star(
        canvas,
        Offset(size.width / 2, size.height / 2),
        size.height * .31,
        const Color(0xffffe000),
      );
    } else {
      final stripe = size.height / 13;
      for (var i = 0; i < 13; i++) {
        canvas.drawRect(
          Rect.fromLTWH(0, i * stripe, size.width, stripe + .2),
          paint..color = i.isEven ? const Color(0xffb22234) : Colors.white,
        );
      }
      final w = size.width * .42;
      final h = stripe * 7;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        paint..color = const Color(0xff3c3b6e),
      );
      for (var row = 0; row < 9; row++) {
        for (var col = 0; col < (row.isEven ? 6 : 5); col++) {
          star(
            canvas,
            Offset((col + (row.isEven ? .5 : 1)) * w / 6, (row + .5) * h / 9),
            h / 22,
            Colors.white,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => oldDelegate.code != code;
}
