import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AssistantPhase {
  idle,
  typing,
  listening,
  thinking,
  generating,
  completed,
  error,
}

class AssistantOrb extends StatefulWidget {
  const AssistantOrb({super.key, required this.phase, this.size = 48});
  final AssistantPhase phase;
  final double size;

  @override
  State<AssistantOrb> createState() => _AssistantOrbState();
}

class _AssistantOrbState extends State<AssistantOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AssistantOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncAnimation();
  }

  void _syncAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      return;
    }
    _animation.duration = Duration(
      milliseconds: switch (widget.phase) {
        AssistantPhase.thinking || AssistantPhase.generating => 1800,
        AssistantPhase.typing || AssistantPhase.listening => 3200,
        _ => 6000,
      },
    );
    _animation.repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = widget.phase == AssistantPhase.error
        ? colors.error
        : colors.primary;
    return Semantics(
      label: 'Assistant ${widget.phase.name}',
      image: true,
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final wave = math.sin(_animation.value * math.pi * 2);
              return CustomPaint(
                painter: _OrbPainter(color, colors.tertiary, _animation.value),
                child: Center(
                  child: Transform.scale(
                    scale: 0.96 + wave * 0.04,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: widget.size * 0.58,
                      height: widget.size * 0.58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.4, -0.5),
                          colors: [
                            colors.primaryContainer,
                            color,
                            colors.tertiary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.2 + wave * 0.05),
                            blurRadius: widget.size * 0.2,
                            spreadRadius: widget.size * 0.025,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: widget.size * 0.22,
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.color, this.accent, this.progress);
  final Color color;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.43;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (var i = 0; i < 3; i++) {
      final angle = progress * math.pi * 2 + i * math.pi * 2 / 3;
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        size.width * (i == 0 ? 0.028 : 0.018),
        Paint()..color = (i == 0 ? color : accent).withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.accent != accent;
}
