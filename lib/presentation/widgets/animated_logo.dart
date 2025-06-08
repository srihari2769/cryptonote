import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedLogo extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Duration animationDuration;
  final bool autoStart;

  const AnimatedLogo({
    super.key,
    this.size = 120,
    this.primaryColor,
    this.secondaryColor,
    this.animationDuration = const Duration(seconds: 2),
    this.autoStart = true,
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;
  
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    if (widget.autoStart) {
      _startAnimations();
    }
  }

  void _initializeAnimations() {
    // Rotation animation
    _rotationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeInOut,
    ));

    // Scale animation
    _scaleController = AnimationController(
      duration: Duration(milliseconds: (widget.animationDuration.inMilliseconds * 0.6).round()),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    // Pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _scaleController.forward();
    
    // Start rotation after scale animation begins
    Future.delayed(Duration(milliseconds: (widget.animationDuration.inMilliseconds * 0.2).round()), () {
      if (mounted) {
        _rotationController.forward();
      }
    });
    
    // Start pulse animation after main animations complete
    Future.delayed(widget.animationDuration, () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
    final secondaryColor = widget.secondaryColor ?? theme.colorScheme.secondary;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationController,
        _scaleController,
        _pulseController,
      ]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * _pulseAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.size * 0.2),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    secondaryColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background pattern
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: LogoPatternPainter(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  
                  // Main icon
                  Icon(
                    Icons.security,
                    size: widget.size * 0.5,
                    color: Colors.white,
                  ),
                  
                  // Animated rings
                  ...List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _rotationController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value * (index + 1) * 0.5,
                          child: Container(
                            width: widget.size * (0.8 + index * 0.1),
                            height: widget.size * (0.8 + index * 0.1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2 - index * 0.05),
                                width: 1,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class LogoPatternPainter extends CustomPainter {
  final Color color;

  LogoPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Draw hexagonal pattern
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi) / 3;
      final x = center.dx + radius * 0.3 * math.cos(angle);
      final y = center.dy + radius * 0.3 * math.sin(angle);
      
      canvas.drawCircle(
        Offset(x, y),
        size.width * 0.02,
        paint,
      );
    }

    // Draw center dot
    canvas.drawCircle(
      center,
      size.width * 0.015,
      paint,
    );
  }

  @override
  bool shouldRepaint(LogoPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class PulsingLogo extends StatefulWidget {
  final double size;
  final Color? color;
  final IconData icon;

  const PulsingLogo({
    super.key,
    this.size = 60,
    this.color,
    this.icon = Icons.security,
  });

  @override
  State<PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<PulsingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: widget.size * 0.6,
              color: color,
            ),
          ),
        );
      },
    );
  }
}

class LoadingLogo extends StatefulWidget {
  final double size;
  final Color? color;

  const LoadingLogo({
    super.key,
    this.size = 40,
    this.color,
  });

  @override
  State<LoadingLogo> createState() => _LoadingLogoState();
}

class _LoadingLogoState extends State<LoadingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.color ?? theme.colorScheme.primary;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: LoadingLogoPainter(
              progress: _controller.value,
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class LoadingLogoPainter extends CustomPainter {
  final double progress;
  final Color color;

  LoadingLogoPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      paint,
    );

    // Draw center icon
    final iconPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final iconSize = size.width * 0.3;
    final iconRect = Rect.fromCenter(
      center: center,
      width: iconSize,
      height: iconSize,
    );

    // Simple shield shape
    final path = Path();
    path.moveTo(center.dx, iconRect.top);
    path.lineTo(iconRect.right, center.dy);
    path.lineTo(center.dx, iconRect.bottom);
    path.lineTo(iconRect.left, center.dy);
    path.close();

    canvas.drawPath(path, iconPaint);
  }

  @override
  bool shouldRepaint(LoadingLogoPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

