import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';

/// Placeholder shown while content loads. One band of light sweeps every
/// [PsBone] underneath in step, so a whole screen shimmers as a single
/// surface instead of each block pulsing on its own.
///
/// Screen readers hear "Loading" once; the bones themselves are silent.
class PsSkeleton extends StatefulWidget {
  const PsSkeleton({super.key, required this.child});

  final Widget child;

  @override
  State<PsSkeleton> createState() => _PsSkeletonState();
}

class _PsSkeletonState extends State<PsSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: AppMotion.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: the bones stay, the moving light does not.
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).loadingLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: _SkeletonScope(state: this, child: widget.child),
      ),
    );
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.state, required super.child});

  final _PsSkeletonState state;

  @override
  bool updateShouldNotify(_SkeletonScope old) => false;
}

/// One grey block of a skeleton. Leave [width] null to fill the row.
class PsBone extends StatelessWidget {
  const PsBone({super.key, this.width, this.height = 14, this.radius = 7});

  const PsBone.circle({super.key, required double size})
      : width = size,
        height = size,
        radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_SkeletonScope>();
    return SizedBox(
      width: width,
      height: height,
      child: _BonePaint(sweep: scope?.state._sweep, frame: scope?.state.context, radius: radius),
    );
  }
}

class _BonePaint extends LeafRenderObjectWidget {
  const _BonePaint({required this.sweep, required this.frame, required this.radius});

  final Animation<double>? sweep;
  final BuildContext? frame;
  final double radius;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBone(sweep, frame, radius);

  @override
  void updateRenderObject(BuildContext context, _RenderBone renderObject) {
    renderObject
      ..sweep = sweep
      ..frame = frame
      ..radius = radius;
  }
}

class _RenderBone extends RenderBox {
  _RenderBone(this._sweep, this.frame, this._radius);

  static const _light = LinearGradient(
    colors: [AppColors.skeleton, AppColors.skeletonGlow, AppColors.skeleton],
    stops: [0.38, 0.5, 0.62],
    begin: Alignment(-1, -0.25),
    end: Alignment(1, 0.25),
  );

  BuildContext? frame;

  Animation<double>? _sweep;
  set sweep(Animation<double>? value) {
    if (value == _sweep) return;
    if (attached) _sweep?.removeListener(markNeedsPaint);
    _sweep = value;
    if (attached) _sweep?.addListener(markNeedsPaint);
  }

  double _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(Size(
        constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        constraints.hasBoundedHeight ? constraints.maxHeight : 0,
      ));

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _sweep?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _sweep?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()..color = AppColors.skeleton;
    final host = frame?.findRenderObject();
    if (_sweep != null && host is RenderBox && host.hasSize) {
      // Paint every bone from the same gradient, laid over the whole
      // skeleton and slid across it, so the band lines up between bones.
      final inHost = localToGlobal(Offset.zero, ancestor: host);
      final w = host.size.width;
      final travel = (_sweep!.value * 2 - 1) * w;
      // A square frame keeps the band's slant the same however tall the
      // skeleton is.
      paint.shader = _light.createShader(
        Rect.fromLTWH(offset.dx - inHost.dx + travel, offset.dy - inHost.dy, w, w),
      );
    }
    context.canvas.drawRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(_radius)), paint);
  }
}

/// A white card outline for bones to sit in, matching `PsCard`.
class _Plate extends StatelessWidget {
  const _Plate({required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.stroke),
        ),
        child: child,
      );
}

Widget _lines(List<double> widths, {double height = 12, double gap = 9}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, w) in widths.indexed) ...[
          if (i > 0) SizedBox(height: gap),
          FractionallySizedBox(widthFactor: w, child: PsBone(height: height)),
        ],
      ],
    );

enum PsSkeletonLeading { none, avatar, badge }

/// Rows shaped like `PsListRow` / `PersonRow`.
class PsSkeletonRows extends StatelessWidget {
  const PsSkeletonRows({super.key, this.count = 5, this.leading = PsSkeletonLeading.avatar, this.trailing = false});

  final int count;
  final PsSkeletonLeading leading;
  final bool trailing;

  // Uneven line lengths read as text; identical ones read as a table.
  static const _titles = [0.62, 0.48, 0.7, 0.55, 0.66, 0.5];
  static const _subtitles = [0.4, 0.58, 0.34, 0.46, 0.52, 0.38];

  @override
  Widget build(BuildContext context) {
    return PsSkeleton(
      child: Column(children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Plate(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                if (leading == PsSkeletonLeading.avatar) const PsBone.circle(size: 44),
                if (leading == PsSkeletonLeading.badge) const PsBone(width: 38, height: 38, radius: AppRadii.small),
                if (leading != PsSkeletonLeading.none) const SizedBox(width: 14),
                Expanded(child: _lines([_titles[i % 6], _subtitles[i % 6]])),
                if (trailing) ...[
                  const SizedBox(width: 12),
                  const PsBone(width: 64, height: 28, radius: AppRadii.pill),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}

/// A content card: heading, a few lines of text and, optionally, a button.
class PsSkeletonCard extends StatelessWidget {
  const PsSkeletonCard({super.key, this.lines = 3, this.button = false});

  final int lines;
  final bool button;

  static const _widths = [0.92, 0.78, 0.6, 0.84, 0.5];

  @override
  Widget build(BuildContext context) {
    return PsSkeleton(
      child: _Plate(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Align(alignment: AlignmentDirectional.centerStart, child: PsBone(width: 150, height: 18, radius: 9)),
          const SizedBox(height: AppSpace.l),
          _lines([for (var i = 0; i < lines; i++) _widths[i % 5]]),
          if (button) ...[
            const SizedBox(height: AppSpace.xl),
            const PsBone(height: 48, radius: AppRadii.pill),
          ],
        ]),
      ),
    );
  }
}

/// Home and Circle tabs: the circle chip, the cycle card with its amount and
/// action, then a short list.
class PsSkeletonDashboard extends StatelessWidget {
  const PsSkeletonDashboard({super.key, this.chip = true});

  final bool chip;

  @override
  Widget build(BuildContext context) {
    return PsSkeleton(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (chip) ...[
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: PsBone(width: 168, height: 40, radius: AppRadii.pill),
          ),
          const SizedBox(height: AppSpace.l),
        ],
        _Plate(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const PsBone(width: 44, height: 44, radius: AppRadii.small),
              const SizedBox(width: 14),
              Expanded(child: _lines([0.55, 0.38])),
            ]),
            const SizedBox(height: AppSpace.xl),
            const Align(alignment: AlignmentDirectional.centerStart, child: PsBone(width: 180, height: 34, radius: 10)),
            const SizedBox(height: AppSpace.m),
            _lines([0.72]),
            const SizedBox(height: AppSpace.xl),
            const PsBone(height: 56, radius: AppRadii.pill),
          ]),
        ),
        const SizedBox(height: AppSpace.xxl),
        const Align(alignment: AlignmentDirectional.centerStart, child: PsBone(width: 130, height: 18, radius: 9)),
        const SizedBox(height: AppSpace.m),
        const _BareRows(count: 3),
      ]),
    );
  }
}

/// Another person's profile: photo, name, the three counts, then cards.
class PsSkeletonProfile extends StatelessWidget {
  const PsSkeletonProfile({super.key});

  @override
  Widget build(BuildContext context) {
    return PsSkeleton(
      child: Column(children: [
        const PsBone.circle(size: 96),
        const SizedBox(height: AppSpace.l),
        const PsBone(width: 170, height: 20, radius: 10),
        const SizedBox(height: AppSpace.s),
        const PsBone(width: 110),
        const SizedBox(height: AppSpace.xl),
        Row(children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.m),
            const Expanded(child: PsBone(height: 62, radius: AppRadii.field)),
          ],
        ]),
        const SizedBox(height: AppSpace.xl),
        const PsBone(height: 48, radius: AppRadii.pill),
        const SizedBox(height: AppSpace.xxl),
        const _BareRows(count: 2),
      ]),
    );
  }
}

/// A conversation: bubbles from both sides, the way the thread will lay out.
class PsSkeletonChat extends StatelessWidget {
  const PsSkeletonChat({super.key});

  static const _bubbles = [(false, 0.56, 44.0), (false, 0.38, 44.0), (true, 0.5, 44.0), (false, 0.64, 64.0), (true, 0.42, 44.0), (true, 0.6, 64.0)];

  @override
  Widget build(BuildContext context) {
    return PsSkeleton(
      // Newest at the bottom, like the thread; never overflows a short view.
      child: SingleChildScrollView(
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(children: [
          for (final (mine, width, height) in _bubbles)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Align(
                alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: FractionallySizedBox(widthFactor: width, child: PsBone(height: height, radius: 18)),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Rows without their own [PsSkeleton], for use inside a larger skeleton.
class _BareRows extends StatelessWidget {
  const _BareRows({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Plate(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                const PsBone.circle(size: 44),
                const SizedBox(width: 14),
                Expanded(child: _lines([PsSkeletonRows._titles[i % 6], PsSkeletonRows._subtitles[i % 6]])),
              ]),
            ),
          ),
      ]);
}
