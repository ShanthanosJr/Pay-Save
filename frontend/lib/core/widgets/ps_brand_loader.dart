import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'ps_logo.dart';

/// Full-screen branded wait: the mark draws itself in on the forest
/// gradient, the wordmark rises under it, and a thin bar keeps moving for
/// as long as the wait lasts. Shown at app start and while signing in.
class PsBrandLoader extends StatefulWidget {
  const PsBrandLoader({super.key, this.message, this.onIntroDone});

  /// What the app is doing, under the wordmark ("Signing you in…").
  final String? message;

  /// Called once the mark has finished drawing.
  final VoidCallback? onIntroDone;

  @override
  State<PsBrandLoader> createState() => _PsBrandLoaderState();
}

class _PsBrandLoaderState extends State<PsBrandLoader> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: AppMotion.splashIntro);
  late final AnimationController _bar = AnimationController(vsync: this, duration: AppMotion.loaderBar);
  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1, curve: AppMotion.curve),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduced motion: show the finished mark at once, no moving bar.
      _intro.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _introDone());
    } else {
      _intro.forward().whenComplete(_introDone);
      _bar.repeat();
    }
  }

  void _introDone() {
    if (mounted) widget.onIntroDone?.call();
  }

  @override
  void dispose() {
    _intro.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Semantics(
        label: widget.message ?? l10n.loadingLabel,
        liveRegion: true,
        child: ExcludeSemantics(
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppColors.headerGradient),
              // The web shell lays the app out at 1×1 before it knows the
              // window size; there is no room for the mark until it does.
              child: LayoutBuilder(
                builder: (context, box) => box.biggest.shortestSide < 240 ? const SizedBox.expand() : _content(l10n),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l10n) {
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _intro,
                  builder: (context, _) => PsLogo(size: 84, progress: _intro.value),
                ),
                const SizedBox(height: AppSpace.xl),
                FadeTransition(
                  opacity: _wordmark,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(_wordmark),
                    child: Text(l10n.wordmark, style: AppText.hero.copyWith(fontSize: 32)),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpace.xxl,
            right: AppSpace.xxl,
            bottom: AppSpace.xxxl + AppSpace.l,
            child: FadeTransition(
              opacity: _wordmark,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.message != null) ...[
                    Text(
                      widget.message!,
                      textAlign: TextAlign.center,
                      style: AppText.callout.copyWith(color: AppColors.onForestMuted),
                    ),
                    const SizedBox(height: AppSpace.l),
                  ],
                  _LoaderBar(animation: _bar),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin track with a short light segment gliding across it.
class _LoaderBar extends StatelessWidget {
  const _LoaderBar({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: ColoredBox(
          color: AppColors.glass,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) => FractionallySizedBox(
              widthFactor: 0.4,
              // Past -1 and 1 so the segment starts and ends fully off the track.
              alignment: Alignment(Curves.easeInOut.transform(animation.value) * 4.7 - 2.35, 0),
              child: child,
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.onForest,
                borderRadius: BorderRadius.all(Radius.circular(AppRadii.pill)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Holds the branded loader over the app until [ready] and the mark has
/// drawn, then fades it away to reveal whatever is underneath.
class PsSplashGate extends StatefulWidget {
  const PsSplashGate({super.key, required this.ready, required this.child});

  final bool ready;
  final Widget child;

  @override
  State<PsSplashGate> createState() => _PsSplashGateState();
}

class _PsSplashGateState extends State<PsSplashGate> {
  bool _introDone = false;
  bool _gone = false;
  Timer? _hold;

  /// Lets the finished mark rest on screen for a moment before the app shows.
  void _onIntroDone() {
    if (MediaQuery.disableAnimationsOf(context)) return setState(() => _introDone = true);
    _hold = Timer(AppMotion.splashHold, () => setState(() => _introDone = true));
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return widget.child;
    final leaving = widget.ready && _introDone;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: leaving,
          child: AnimatedOpacity(
            opacity: leaving ? 0 : 1,
            duration: AppMotion.medium,
            curve: AppMotion.curve,
            onEnd: () => setState(() => _gone = true),
            child: PsBrandLoader(onIntroDone: _onIntroDone),
          ),
        ),
      ],
    );
  }
}
