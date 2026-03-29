import 'dart:math';
import 'package:flutter/material.dart';

/// ECG-style voice-reactive audio visualizer
class AudioVisualizer extends StatefulWidget {
  final bool isRecording;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;
  final double? audioLevel;

  const AudioVisualizer({
    super.key,
    required this.isRecording,
    this.primaryColor = const Color(0xFF007AFF),
    this.secondaryColor = const Color(0xFF5AC8FA),
    this.size = 200,
    this.audioLevel,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _waveformData = [];
  static const int _maxDataPoints = 60;

  @override
  void initState() {
    super.initState();
    // Initialize with flat line
    _waveformData.addAll(List.filled(_maxDataPoints, 0.0));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateWaveform);

    if (widget.isRecording) {
      _controller.repeat();
    }
  }

  void _updateWaveform() {
    if (!widget.isRecording) return;

    setState(() {
      // Add new audio level to the end
      final level = widget.audioLevel ?? 0.0;
      _waveformData.add(level);

      // Remove old data to keep fixed size
      if (_waveformData.length > _maxDataPoints) {
        _waveformData.removeAt(0);
      }
    });
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.repeat();
      } else {
        _controller.stop();
        // Reset to flat line when stopped
        setState(() {
          _waveformData.clear();
          _waveformData.addAll(List.filled(_maxDataPoints, 0.0));
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Microphone button
        _buildMicrophoneButton(),
        const SizedBox(height: 24),
        // ECG Waveform
        _buildWaveform(),
      ],
    );
  }

  Widget _buildMicrophoneButton() {
    final audioLevel = (widget.audioLevel ?? 0.0).clamp(0.0, 1.0);
    final buttonScale = 1.0 + (audioLevel * 0.15);

    return Transform.scale(
      scale: buttonScale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.primaryColor.withValues(alpha: 0.9),
              widget.primaryColor,
              widget.secondaryColor,
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withValues(alpha: 0.3 + audioLevel * 0.4),
              blurRadius: 12 + (audioLevel * 20),
              spreadRadius: 2 + (audioLevel * 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Icon(
              widget.isRecording ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveform() {
    return Container(
      width: widget.size + 40,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          size: Size(widget.size + 40, 80),
          painter: _WaveformPainter(
            data: _waveformData,
            color: widget.primaryColor,
            isRecording: widget.isRecording,
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isRecording;

  _WaveformPainter({
    required this.data,
    required this.color,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final path = Path();
    final glowPath = Path();

    final centerY = size.height / 2;
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      // Amplify the audio level for visible effect
      final amplitude = data[i] * (size.height * 0.4);
      final y = centerY - amplitude;

      if (i == 0) {
        path.moveTo(x, y);
        glowPath.moveTo(x, y);
      } else {
        // Smooth curve
        final prevX = (i - 1) * stepX;
        final prevAmplitude = data[i - 1] * (size.height * 0.4);
        final prevY = centerY - prevAmplitude;

        final controlX = (prevX + x) / 2;
        path.quadraticBezierTo(controlX, prevY, x, y);
        glowPath.quadraticBezierTo(controlX, prevY, x, y);
      }
    }

    // Draw glow first, then main line
    if (isRecording) {
      canvas.drawPath(glowPath, glowPaint);
    }
    canvas.drawPath(path, paint);

    // Draw center reference line (faint)
    final centerLinePaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}

/// Compact audio wave indicator for smaller spaces
class CompactAudioWave extends StatefulWidget {
  final bool isActive;
  final Color color;
  final int barCount;

  const CompactAudioWave({
    super.key,
    required this.isActive,
    this.color = const Color(0xFF007AFF),
    this.barCount = 5,
  });

  @override
  State<CompactAudioWave> createState() => _CompactAudioWaveState();
}

class _CompactAudioWaveState extends State<CompactAudioWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<double> _heights;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _heights = List.generate(widget.barCount, (_) => 0.3 + _random.nextDouble() * 0.7);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
        if (widget.isActive && mounted) {
          setState(() {
            for (int i = 0; i < _heights.length; i++) {
              if (_random.nextDouble() > 0.7) {
                _heights[i] = 0.2 + _random.nextDouble() * 0.8;
              }
            }
          });
        }
      });

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CompactAudioWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(widget.barCount, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 3,
          height: widget.isActive ? _heights[index] * 20 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}
