import 'dart:math' as math;
import 'package:flutter/material.dart';

const authGradient = LinearGradient(
  colors: [Color(0xFF9020EA), Color(0xFF5930EF), Color(0xFF3654E5)],
);

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF100B26), Color(0xFF070C1B), Color(0xFF020C10)],
      ),
    ),
    child: CustomPaint(painter: _BackdropPainter(), child: child),
  );
}

class AuthBrand extends StatelessWidget {
  const AuthBrand({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        label: 'LifeSync',
        image: true,
        child: const SizedBox(
          width: 176,
          height: 176,
          child: CustomPaint(painter: _WatchPainter()),
        ),
      ),
      const SizedBox(height: 10),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Life',
              style: TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
                color: Colors.white,
              ),
            ),
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                colors: [Color(0xFF9053EB), Color(0xFF6230C9)],
              ).createShader(rect),
              child: const Text(
                'Sync',
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        'Organiza tu vida.\nAlcanza tus metas.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, height: 1.5, color: Color(0xFFB9B9C5)),
      ),
    ],
  );
}

class _WatchPainter extends CustomPainter {
  const _WatchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 180);
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4FB6F0),
          Color(0xFF5865DE),
          Color(0xFFC067E9),
          Color(0xFF7032B8),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 180, 180))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(90, 90);
    canvas.rotate(-math.pi / 4);
    canvas.drawOval(const Rect.fromLTWH(-96, -40, 192, 80), paint);
    canvas.restore();
    canvas.drawArc(
      const Rect.fromLTWH(18, 14, 142, 152),
      2.7,
      1.65,
      false,
      paint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(18, 14, 142, 152),
      -.25,
      1.5,
      false,
      paint,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 5, 51, 35),
        const Radius.circular(8),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(65, 143, 51, 32),
        const Radius.circular(8),
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(139, 62, 7, 22),
        const Radius.circular(3),
      ),
      paint,
    );
    final face = RRect.fromRectAndRadius(
      const Rect.fromLTWH(45, 36, 91, 111),
      const Radius.circular(22),
    );
    canvas.drawRRect(face, Paint()..color = const Color(0xFF0A1024));
    paint.style = PaintingStyle.stroke;
    canvas.drawRRect(face, paint);
    paint.strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 43, 77, 97),
        const Radius.circular(17),
      ),
      paint,
    );
    paint.strokeWidth = 7;
    canvas.drawArc(const Rect.fromLTWH(64, 60, 53, 62), .1, 2.0, false, paint);
    canvas.drawArc(const Rect.fromLTWH(64, 60, 53, 62), 3, 1.8, false, paint);
    canvas.drawPath(
      Path()
        ..moveTo(91, 54)
        ..lineTo(102, 61)
        ..lineTo(90, 68),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(90, 115)
        ..lineTo(79, 123)
        ..lineTo(92, 128),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(78, 86)
        ..lineTo(89, 97)
        ..lineTo(123, 63),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = math.min(size.height * .51, 440.0);
    final wave = Path()
      ..moveTo(0, y - 70)
      ..cubicTo(
        size.width * .45,
        y + 65,
        size.width * .57,
        y + 45,
        size.width,
        y - 104,
      )
      ..lineTo(size.width, y - 33)
      ..cubicTo(size.width * .5, y + 95, size.width * .4, y + 12, 0, y - 24)
      ..close();
    canvas.drawPath(
      wave,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x102D3A8F), Color(0x302E258E)],
        ).createShader(Rect.fromLTWH(0, y - 104, size.width, 210)),
    );
    canvas.drawPath(
      wave,
      Paint()
        ..color = const Color(0x222C38AA)
        ..style = PaintingStyle.stroke,
    );
    for (final point in [
      const Offset(.05, .09),
      const Offset(.96, .16),
      const Offset(.045, .22),
      const Offset(.91, .055),
    ]) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        point.dx > .9 ? 4 : 3,
        Paint()..color = const Color(0x554F35A9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
