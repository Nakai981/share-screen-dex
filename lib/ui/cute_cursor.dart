import 'package:flutter/material.dart';

const cuteCursorSize = Size(16, 20);

class CuteCursorPainter extends CustomPainter {
  const CuteCursorPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 24);
    final pointer = Path()
      ..moveTo(2, 1)
      ..quadraticBezierTo(.2, .2, .5, 3)
      ..lineTo(2, 19)
      ..quadraticBezierTo(2.3, 21, 4, 19.5)
      ..lineTo(7.2, 16.5)
      ..lineTo(11, 22)
      ..quadraticBezierTo(12, 23.4, 13.3, 22.5)
      ..lineTo(15, 21.3)
      ..quadraticBezierTo(16.2, 20.5, 15.2, 19)
      ..lineTo(12, 14.5)
      ..lineTo(17, 14.2)
      ..quadraticBezierTo(19.2, 14, 17.3, 12.4)
      ..close();
    canvas.drawShadow(pointer, const Color(0x3318323C), 1.2, false);
    canvas.drawPath(pointer, Paint()..color = const Color(0xFFBDE9DC));
    canvas.drawPath(
      pointer,
      Paint()
        ..color = const Color(0xFF28514D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.05
        ..strokeJoin = StrokeJoin.round,
    );
    final face = Paint()..color = const Color(0xFF28514D);
    canvas.drawCircle(const Offset(5.7, 8.8), .75, face);
    canvas.drawCircle(const Offset(9.1, 10.2), .75, face);
    canvas.drawPath(
      Path()
        ..moveTo(5.8, 11.4)
        ..quadraticBezierTo(6.7, 13.4, 8.7, 12.7),
      Paint()
        ..color = const Color(0xFF28514D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CuteCursorPainter oldDelegate) => false;
}
