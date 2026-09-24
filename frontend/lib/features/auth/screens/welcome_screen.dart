import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_language_chip.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../widgets/accent_title.dart';

/// Landing screen, modelled on the Foreal hero: full-bleed photo, hairline,
/// mixed sans/serif headline, white info card and two pill buttons.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);
    void setLocale(String code) => ref.read(localeProvider.notifier).set(Locale(code));

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/rosca_1.png', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpace.s),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.wordmark,
                              style: AppText.title.copyWith(
                                color: AppColors.onDark,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Wrap(
                          spacing: 4,
                          children: [
                            PsLanguageChip(
                              label: l10n.languageEnglish,
                              selected: locale.languageCode == 'en',
                              onTap: () => setLocale('en'),
                            ),
                            PsLanguageChip(
                              label: l10n.languageSinhala,
                              selected: locale.languageCode == 'si',
                              onTap: () => setLocale('si'),
                            ),
                            PsLanguageChip(
                              label: l10n.languageTamil,
                              selected: locale.languageCode == 'ta',
                              onTap: () => setLocale('ta'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.m),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.heroTagline,
                          style: AppText.small.copyWith(color: AppColors.onDarkMuted),
                        ),
                      ),
                      const SizedBox(height: AppSpace.m),
                      Container(height: 1, color: AppColors.onDark.withValues(alpha: 0.3)),
                      const SizedBox(height: AppSpace.xxl),
                      AccentTitle(
                        plain: l10n.welcomeTitlePlain,
                        accent: l10n.welcomeTitleAccent,
                        color: AppColors.onDark,
                        textAlign: TextAlign.center,
                        large: true,
                      ),
                      Text(
                        l10n.welcomeTitleLine2,
                        textAlign: TextAlign.center,
                        style: AppText.display.copyWith(color: AppColors.onDark),
                      ),
                      const Spacer(),
                      _InfoCard(title: l10n.heroCardTitle, subtitle: l10n.heroCardSubtitle),
                      const SizedBox(height: AppSpace.l),
                      PsButton(
                        label: l10n.logIn,
                        variant: PsButtonVariant.scrim,
                        onPressed: () => context.go('/login'),
                      ),
                      const SizedBox(height: AppSpace.m),
                      PsButton(
                        label: l10n.createAccount,
                        variant: PsButtonVariant.light,
                        trailing: Icons.arrow_forward,
                        onPressed: () => context.go('/register/details'),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.m, AppSpace.l, AppSpace.m),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.small),
              ],
            ),
          ),
          const Icon(Icons.south_east, color: AppColors.ink),
        ],
      ),
    );
  }
}
