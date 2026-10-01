import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_icon_badge.dart';
import '../../../core/widgets/ps_logo.dart';
import '../../../core/widgets/ps_section.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Editorial landing: community photo fading into forest green, a floating
/// "verified" proof card, language choice, then the two entry points.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.forest900,
        body: Stack(
          fit: StackFit.expand,
          children: [
            LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: c.maxHeight * 0.66,
                  width: double.infinity,
                  child: const ExcludeSemantics(
                    child: Stack(fit: StackFit.expand, children: [
                      Image(
                        image: AssetImage('assets/images/rosca_1.png'),
                        fit: BoxFit.cover,
                        alignment: Alignment(0, 0.3),
                      ),
                      DecoratedBox(decoration: BoxDecoration(gradient: AppColors.photoFade)),
                    ]),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: c.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: AppSpace.m),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.forest900.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(AppRadii.pill),
                                    border: Border.all(color: AppColors.glassStrong),
                                  ),
                                  child: PsLogo(size: 26, wordmark: l10n.wordmark),
                                ),
                              ),
                              const Spacer(),
                              const SizedBox(height: 150),
                              _ProofCard(title: l10n.heroCardTitle, subtitle: l10n.heroCardSubtitle),
                              const SizedBox(height: AppSpace.xxl),
                              Text(
                                l10n.heroTagline.toUpperCase(),
                                style: AppText.caption.copyWith(
                                  color: AppColors.mint,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpace.m),
                              Semantics(
                                header: true,
                                child: Text.rich(TextSpan(children: [
                                  TextSpan(text: '${l10n.welcomeHeadline1}\n', style: AppText.hero),
                                  TextSpan(text: l10n.welcomeHeadline2, style: AppText.hero.copyWith(color: AppColors.mint)),
                                ])),
                              ),
                              const SizedBox(height: AppSpace.xxl),
                              PsSegmented<String>(
                                onForest: true,
                                segments: [
                                  ('en', l10n.languageEnglish),
                                  ('si', l10n.languageSinhala),
                                  ('ta', l10n.languageTamil),
                                ],
                                selected: locale.languageCode,
                                onChanged: (code) => ref.read(localeProvider.notifier).set(Locale(code)),
                              ),
                              const SizedBox(height: AppSpace.l),
                              PsButton(
                                label: l10n.createAccount,
                                variant: PsButtonVariant.light,
                                trailingIcon: Icons.arrow_forward_rounded,
                                onPressed: () => context.go('/register/details'),
                              ),
                              const SizedBox(height: AppSpace.m),
                              PsButton(
                                label: l10n.logIn,
                                variant: PsButtonVariant.glass,
                                onPressed: () => context.go('/login'),
                              ),
                              const SizedBox(height: AppSpace.xl),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProofCard extends StatefulWidget {
  const _ProofCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_ProofCard> createState() => _ProofCardState();
}

class _ProofCardState extends State<_ProofCard> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: AppMotion.curve);
    return FadeTransition(
      opacity: t,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(t),
        child: Transform.rotate(
          angle: -0.03,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              boxShadow: AppColors.floatShadow,
            ),
            child: Row(children: [
              const PsIconBadge(icon: Icons.check_rounded, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: AppText.headline),
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: AppText.footnote),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
