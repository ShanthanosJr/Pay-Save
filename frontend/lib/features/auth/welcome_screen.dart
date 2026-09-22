import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_gradient_button.dart';
import '../../core/widgets/ps_language_chip.dart';
import '../../core/widgets/ps_pager_dots.dart';
import '../../l10n/gen/app_localizations.dart';

/// Welcome screen (design-system §4.1). Language is chosen first, above
/// Get started, because low digital confidence means the reader must be
/// able to understand every later screen (NFR-06).
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/welcome.jpg', fit: BoxFit.cover),
          DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.photoOverlay),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
              child: Column(
                children: [
                  const SizedBox(height: AppSpace.xxxl),
                  Text(l10n.wordmark, style: AppText.wordmark),
                  const Spacer(),
                  Text(
                    l10n.welcomeTitleLine1,
                    textAlign: TextAlign.center,
                    style: AppText.display,
                  ),
                  Text(
                    l10n.welcomeTitleLine2,
                    textAlign: TextAlign.center,
                    style: AppText.display,
                  ),
                  const SizedBox(height: AppSpace.m),
                  Text(
                    l10n.welcomeSubtitle,
                    textAlign: TextAlign.center,
                    style: AppText.body,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpace.s,
                    runSpacing: AppSpace.s,
                    children: [
                      PsLanguageChip(
                        label: l10n.languageEnglish,
                        selected: locale.languageCode == 'en',
                        onTap: () => ref.read(localeProvider.notifier).set(const Locale('en')),
                      ),
                      PsLanguageChip(
                        label: l10n.languageSinhala,
                        selected: locale.languageCode == 'si',
                        onTap: () => ref.read(localeProvider.notifier).set(const Locale('si')),
                      ),
                      PsLanguageChip(
                        label: l10n.languageTamil,
                        selected: locale.languageCode == 'ta',
                        onTap: () => ref.read(localeProvider.notifier).set(const Locale('ta')),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),
                  const PsPagerDots(count: 3, activeIndex: 0),
                  const SizedBox(height: AppSpace.xl),
                  PsGradientButton(
                    label: l10n.getStarted,
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
