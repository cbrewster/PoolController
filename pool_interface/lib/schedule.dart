import 'package:flutter/material.dart';
import 'dart:math';

class Schedule extends StatelessWidget {
  final TimeOfDay onTime;
  final TimeOfDay offTime;

  Schedule({this.onTime, this.offTime});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
        child: CustomPaint(
            size: Size(300, 40),
            foregroundPainter:
                new SchedulePainter(onTime: onTime, offTime: offTime)));
  }
}

class SchedulePainter extends CustomPainter {
  TimeOfDay onTime;
  TimeOfDay offTime;

  SchedulePainter({this.onTime, this.offTime});

  @override
  void paint(Canvas canvas, Size size) {
    print(size);

    Paint greyLine = new Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    Paint blueLine = new Paint()
      ..color = Colors.blue[400]
      ..style = PaintingStyle.fill
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.butt;

    Paint blueLineCircle = new Paint()
      ..color = Colors.blue[400]
      ..style = PaintingStyle.fill
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.butt;

    Paint indicator = new Paint()
      ..color = Colors.blue[400]
      ..style = PaintingStyle.fill
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    var onPercent = (onTime.hour * 60 + onTime.minute) / (24 * 60.0);
    var offPercent = (offTime.hour * 60 + offTime.minute) / (24 * 60.0);

    canvas.drawLine(Offset(0, size.height / 2),
        Offset(size.width, size.height / 2), greyLine);

    canvas.drawLine(Offset(size.width * onPercent, 10),
        Offset(size.width * onPercent, size.height - 10), indicator);

    canvas.drawLine(Offset(size.width * offPercent, 10),
        Offset(size.width * offPercent, size.height - 10), indicator);

    if (offPercent > onPercent) {
      canvas.drawLine(Offset(size.width * onPercent, size.height / 2),
          Offset(size.width * offPercent, size.height / 2), blueLine);
    } else {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width * offPercent, size.height / 2), blueLine);
      canvas.drawLine(Offset(size.width * onPercent, size.height / 2),
          Offset(size.width, size.height / 2), blueLine);

      canvas.drawCircle(Offset(0, size.height / 2), 5.0, blueLineCircle);
      canvas.drawCircle(
          Offset(size.width, size.height / 2), 5.0, blueLineCircle);
    }

    TextSpan textSpan = new TextSpan(
        text: "12:00 AM",
        style: new TextStyle(color: Colors.grey, fontSize: 10));
    TextPainter textPainter = new TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    textPainter.layout();
    textPainter.paint(canvas, Offset(-textPainter.width / 2, size.height - 10));

    textSpan = new TextSpan(
        text: "12:00 PM",
        style: new TextStyle(color: Colors.grey, fontSize: 10));
    textPainter = new TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    textPainter.layout();
    textPainter.paint(canvas,
        Offset((size.width / 2) - textPainter.width / 2, size.height - 10));

    textSpan = new TextSpan(
        text: "12:00 AM",
        style: new TextStyle(color: Colors.grey, fontSize: 10));
    textPainter = new TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(size.width - textPainter.width / 2, size.height - 10));

    canvas.drawCircle(Offset(0, 0), 5.0, blueLineCircle);
    textSpan = new TextSpan(
        text: "ON", style: new TextStyle(color: Colors.grey, fontSize: 10));
    textPainter = new TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    textPainter.layout();
    textPainter.paint(canvas, Offset(8, -6.5));

    canvas.drawCircle(Offset(40, 0), 5.0, greyLine);
    textSpan = new TextSpan(
        text: "OFF", style: new TextStyle(color: Colors.grey, fontSize: 10));
    textPainter = new TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center);
    textPainter.layout();
    textPainter.paint(canvas, Offset(48, -6.5));
  }

  @override
  bool shouldRepaint(CustomPainter oldPainter) {
    return true;
  }
}
