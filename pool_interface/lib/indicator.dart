import 'package:flutter/material.dart';
import 'dart:math';

class Indicator extends CustomPainter {
  Color color;

  Indicator({this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint line = new Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset center = new Offset(size.width / 2, size.height / 2);
    double radius = min(size.width / 2, size.height / 2);

    canvas.drawCircle(center, radius, line);
  }

  @override
  bool shouldRepaint(CustomPainter oldPainter) {
    return true;
  }
}
