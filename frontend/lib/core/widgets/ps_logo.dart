import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Pay&Save mark: two interlocking rings (people paying together) holding a
/// rising arc (savings growing).
class PsLogo extends StatelessWidget {
  const PsLogo({super.key, this.size = 30, this.wordmark, this.onForest = true, this.progress = 1});

  final double size;
  final String? wordmark;
  final bool onForest;

  /// How much of the mark is drawn, 0 to 1. The loading screens animate
  /// this so the rings and arc draw themselves in.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(onForest: onForest, progress: progress)),
    );
    if (wordmark == null) return mark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      SizedBox(width: size * 0.36),
      Text(
        wordmark!,
        style: AppText.brand.copyWith(
          fontSize: size * 0.66,
          color: onForest ? AppColors.onForest : AppColors.ink,
        ),
      ),
    ]);
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.onForest, required this.progress});

  final bool onForest;
  final double progress;

  /// The share of [progress] that falls inside one stroke's slot, eased.
  double _part(double from, double to) =>
      Curves.easeInOutCubic.transform(((progress - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ringA = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11
      ..strokeCap = StrokeCap.round
      ..color = onForest ? AppColors.mint : AppColors.forest600;
    final ringB = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11
      ..strokeCap = StrokeCap.round
      ..color = onForest ? AppColors.onForest.withValues(alpha: 0.9) : AppColors.forest800;
    final r = s * 0.27;
    final cy = s * 0.56;
    // First ring, second ring, then the arc above them, each overlapping
    // the one before so the mark draws as a single gesture.
    final a = _part(0, 0.5), b = _part(0.25, 0.75), c = _part(0.6, 1);
    if (a > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(s * 0.36, cy), radius: r),
        -math.pi * 0.5,
        math.pi * 2 * a,
        false,
        ringA,
      );
    }
    if (b > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(s * 0.64, cy), radius: r),
        -math.pi * 0.95,
        math.pi * 1.7 * b,
        false,
        ringB,
      );
    }
    if (c == 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.08
      ..strokeCap = StrokeCap.round
      ..color = onForest ? AppColors.mint : AppColors.forest500;
    final path = Path()
      ..moveTo(s * 0.2, s * 0.2)
      ..quadraticBezierTo(s * 0.5, s * 0.02, s * 0.8, s * 0.2);
    final line = path.computeMetrics().first;
    canvas.drawPath(line.extractPath(0, line.length * c), arc);
  }

  @override
  bool shouldRepaint(covariant _MarkPainter old) => old.onForest != onForest || old.progress != progress;
}
