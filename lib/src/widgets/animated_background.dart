import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

class AnimatedNeuralBackground extends StatefulWidget {
  final Widget child;
  const AnimatedNeuralBackground({Key? key, required this.child}) : super(key: key);

  @override
  State<AnimatedNeuralBackground> createState() => _AnimatedNeuralBackgroundState();
}

class _AnimatedNeuralBackgroundState extends State<AnimatedNeuralBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 10), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkBase, Color(0xFF1A1F2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(painter: NeuralPathPainter(_controller.value), size: Size.infinite);
        },
      ),
      widget.child,
    ]);
  }
}

class NeuralPathPainter extends CustomPainter {
  final double animation;
  NeuralPathPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.neuralTeal.withOpacity(0.08)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final startY = size.height * (i / 5);
      path.moveTo(0, startY);
      for (double x = 0; x < size.width; x += 50) {
        final y = startY + math.sin((x / 100) + (animation * 2 * math.pi)) * 30;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
