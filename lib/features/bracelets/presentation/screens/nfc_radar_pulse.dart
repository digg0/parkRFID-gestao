import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NfcRadarPulse extends StatefulWidget {
  const NfcRadarPulse({super.key});

  @override
  State<NfcRadarPulse> createState() => _NfcRadarPulseState();
}

class _NfcRadarPulseState extends State<NfcRadarPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _lastValue = 0.0;


  final Set<int> _triggeredWaves = {};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _controller.addListener(() {
      final currentValue = _controller.value;


      if (currentValue < _lastValue) {
        _triggeredWaves.clear();
      }


      for (int i = 0; i < 3; i++) {
        final waveProgress = (currentValue + (i * 0.33)) % 1.0;


        if (waveProgress < 0.05 && !_triggeredWaves.contains(i)) {
          HapticFeedback.lightImpact();
          _triggeredWaves.add(i);
          break;
        }
      }

      _lastValue = currentValue;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PulsePainter(_controller.value),
          child: const SizedBox(
            width: 260,
            height: 260,
          ),
        );
      },
    );
  }
}

class _PulsePainter extends CustomPainter {
  final double progress;
  _PulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = maxRadius * waveProgress;
      final opacity = (1.0 - waveProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => true;
}