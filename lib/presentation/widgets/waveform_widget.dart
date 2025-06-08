import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveformWidget extends StatefulWidget {
  final List<double> waveformData;
  final Duration? currentPosition;
  final Duration? totalDuration;
  final Color? waveColor;
  final Color? progressColor;
  final double height;
  final Function(Duration)? onSeek;
  final bool interactive;

  const WaveformWidget({
    super.key,
    required this.waveformData,
    this.currentPosition,
    this.totalDuration,
    this.waveColor,
    this.progressColor,
    this.height = 60,
    this.onSeek,
    this.interactive = true,
  });

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: widget.waveformData.isEmpty
          ? _buildPlaceholder(theme)
          : _buildWaveform(theme),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.graphic_eq,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            'Waveform',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(ThemeData theme) {
    return GestureDetector(
      onTapDown: widget.interactive ? _handleTap : null,
      child: CustomPaint(
        painter: WaveformPainter(
          waveformData: widget.waveformData,
          currentPosition: widget.currentPosition,
          totalDuration: widget.totalDuration,
          waveColor: widget.waveColor ?? theme.colorScheme.primary.withOpacity(0.3),
          progressColor: widget.progressColor ?? theme.colorScheme.primary,
        ),
        size: Size.infinite,
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    if (widget.onSeek == null || widget.totalDuration == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final progress = localPosition.dx / renderBox.size.width;
    
    final seekPosition = Duration(
      milliseconds: (progress * widget.totalDuration!.inMilliseconds).round(),
    );
    
    widget.onSeek!(seekPosition);
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Duration? currentPosition;
  final Duration? totalDuration;
  final Color waveColor;
  final Color progressColor;

  WaveformPainter({
    required this.waveformData,
    this.currentPosition,
    this.totalDuration,
    required this.waveColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..color = progressColor;

    final wavePaint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..color = waveColor;

    final barWidth = size.width / waveformData.length;
    final centerY = size.height / 2;
    
    // Calculate progress position
    double progressX = 0;
    if (currentPosition != null && totalDuration != null && totalDuration!.inMilliseconds > 0) {
      progressX = (currentPosition!.inMilliseconds / totalDuration!.inMilliseconds) * size.width;
    }

    // Draw waveform bars
    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final amplitude = waveformData[i];
      final barHeight = amplitude * (size.height * 0.8);
      
      final rect = Rect.fromLTWH(
        x,
        centerY - barHeight / 2,
        barWidth * 0.8, // Add some spacing between bars
        barHeight,
      );

      // Use progress color if this bar is before the current position
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1)),
        x <= progressX ? progressPaint : wavePaint,
      );
    }

    // Draw progress line
    if (progressX > 0) {
      final progressLinePaint = Paint()
        ..color = progressColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        progressLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
           oldDelegate.currentPosition != currentPosition ||
           oldDelegate.totalDuration != totalDuration ||
           oldDelegate.waveColor != waveColor ||
           oldDelegate.progressColor != progressColor;
  }
}

class AnimatedWaveformWidget extends StatefulWidget {
  final bool isAnimating;
  final Color? waveColor;
  final double height;
  final int barCount;

  const AnimatedWaveformWidget({
    super.key,
    required this.isAnimating,
    this.waveColor,
    this.height = 60,
    this.barCount = 20,
  });

  @override
  State<AnimatedWaveformWidget> createState() => _AnimatedWaveformWidgetState();
}

class _AnimatedWaveformWidgetState extends State<AnimatedWaveformWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _barAnimations = List.generate(widget.barCount, (index) {
      final delay = index * 0.1;
      return Tween<double>(begin: 0.1, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            delay,
            math.min(1.0, delay + 0.3),
            curve: Curves.easeInOut,
          ),
        ),
      );
    });

    if (widget.isAnimating) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return CustomPaint(
            painter: AnimatedWaveformPainter(
              barAnimations: _barAnimations,
              waveColor: widget.waveColor ?? theme.colorScheme.primary,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class AnimatedWaveformPainter extends CustomPainter {
  final List<Animation<double>> barAnimations;
  final Color waveColor;

  AnimatedWaveformPainter({
    required this.barAnimations,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / barAnimations.length;
    final centerY = size.height / 2;

    for (int i = 0; i < barAnimations.length; i++) {
      final x = i * barWidth;
      final amplitude = barAnimations[i].value;
      final barHeight = amplitude * (size.height * 0.8);
      
      final rect = Rect.fromLTWH(
        x + barWidth * 0.1,
        centerY - barHeight / 2,
        barWidth * 0.8,
        barHeight,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AnimatedWaveformPainter oldDelegate) {
    return true; // Always repaint for animation
  }
}

