import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/prefs_store.dart';
import '../../core/providers/text_scale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_card.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';

/// Every preference in one place: how the app looks and reads, privacy,
/// security, and a plain statement of what is stored (NFR-01).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthLoggedIn ? auth.user : null;
    final locale = ref.watch(localeProvider);
    final textSize = ref.watch(textScaleProvider);
    final hidePreviews = ref.watch(hideChatPreviewsProvider);

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.settingsTitle, backLabel: l10n.backLabel),
        children: [
          PsSectionHeader(title: l10n.settingsDisplay),
          PsGroupLabel(l10n.textSizeLabel),
          PsSegmented<TextSizeChoice>(
            segments: [
              (TextSizeChoice.standard, l10n.textStandard),
              (TextSizeChoice.enhanced, l10n.textEnhanced),
              (TextSizeChoice.maximised, l10n.textMaximised),
            ],
            selected: textSize,
            onChanged: ref.read(textScaleProvider.notifier).set,
          ),
          const SizedBox(height: AppSpace.s),
          Text(l10n.settingsTextSample, style: AppText.body),
          const SizedBox(height: AppSpace.xl),
          PsGroupLabel(l10n.profileLanguage),
          PsSegmented<String>(
            segments: [('en', l10n.languageEnglish), ('si', l10n.languageSinhala), ('ta', l10n.languageTamil)],
            selected: locale.languageCode,
            onChanged: (code) {
              ref.read(localeProvider.notifier).set(Locale(code));
              // SMS, email and reminders follow the same language
              if (user != null) ref.read(authApiProvider).updateLanguage(code).catchError((_) {});
            },
          ),
          const SizedBox(height: AppSpace.s),
          Text(l10n.settingsLanguageNote, style: AppText.footnote),
          const SizedBox(height: AppSpace.xxl),

          PsSectionHeader(title: l10n.settingsNotifications),
          PsListRow(
            icon: Icons.notifications_rounded,
            tone: PsBadgeTone.mint,
            title: l10n.notificationsLabel,
            subtitle: l10n.settingsInboxHint,
            showChevron: true,
            onTap: () => context.push('/notifications'),
          ),
          PsListRow(
            icon: Icons.alarm_rounded,
            tone: PsBadgeTone.mint,
            title: l10n.remindersTitle,
            subtitle: l10n.settingsRemindersHint,
            showChevron: true,
            onTap: () => context.go('/circle'),
          ),
          const SizedBox(height: AppSpace.xxl),

          PsSectionHeader(title: l10n.settingsPrivacy),
          PsCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: SwitchListTile(
              value: hidePreviews,
              onChanged: ref.read(hideChatPreviewsProvider.notifier).set,
              title: Text(l10n.prefHidePreviews, style: AppText.headline),
              subtitle: Text(l10n.prefHidePreviewsHint, style: AppText.footnote),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.forest700,
            ),
          ),
          const SizedBox(height: AppSpace.m),
          PsListRow(
            icon: Icons.shield_rounded,
            tone: PsBadgeTone.mint,
            title: l10n.yourDataTitle,
            subtitle: l10n.yourDataHint,
            showChevron: true,
            onTap: () => showYourDataSheet(context),
          ),
          const SizedBox(height: AppSpace.xxl),

          if (user != null) ...[
            PsSectionHeader(title: l10n.settingsSecurity),
            PsListRow(
              icon: Icons.lock_reset_rounded,
              tone: PsBadgeTone.mint,
              title: l10n.changePasswordTitle,
              showChevron: true,
              onTap: () => context.push('/profile/password'),
            ),
            PsListRow(
              icon: Icons.phone_iphone_rounded,
              tone: PsBadgeTone.mint,
              title: l10n.changePhoneTitle,
              subtitle: user.phoneMasked,
              showChevron: true,
              onTap: () => context.push('/profile/phone'),
            ),
            PsListRow(
              icon: user.emailVerified ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
              tone: user.emailVerified ? PsBadgeTone.mint : PsBadgeTone.warning,
              title: l10n.profileEmail,
              subtitle: '${user.email ?? '—'} · ${user.emailVerified ? l10n.verifiedBadge : l10n.notVerifiedBadge}',
            ),
            const SizedBox(height: AppSpace.xxl),
            PsSectionHeader(title: l10n.accountGroup),
            PsListRow(
              icon: Icons.account_balance_wallet_rounded,
              tone: PsBadgeTone.mint,
              title: l10n.paymentMethodsTitle,
              showChevron: true,
              onTap: () => context.push('/profile/payment-methods'),
            ),
            PsListRow(
              icon: Icons.edit_rounded,
              tone: PsBadgeTone.mint,
              title: l10n.settingsEditProfile,
              showChevron: true,
              onTap: () => context.push('/profile/edit'),
            ),
            const SizedBox(height: AppSpace.l),
            PsButton(
              label: l10n.logOut,
              variant: PsButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: () => _confirmLogout(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showPsSheet<void>(
      context: context,
      title: l10n.logOutConfirmTitle,
      subtitle: l10n.logOutConfirmBody,
      builder: (ctx) => Row(children: [
        Expanded(
          child: PsButton(
            label: l10n.cancelLabel,
            variant: PsButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: PsButton(
            label: l10n.logOut,
            variant: PsButtonVariant.danger,
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ),
      ]),
    );
  }
}

/// NFR-01: what is stored, how it is protected and who can see it, in plain
/// words. Also reachable before signing in.
void showYourDataSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showPsSheet<void>(
    context: context,
    title: l10n.yourDataTitle,
    builder: (_) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (icon, title, body) in [
        (Icons.inventory_2_rounded, l10n.yourDataStoredTitle, l10n.yourDataStoredBody),
        (Icons.lock_rounded, l10n.yourDataProtectedTitle, l10n.yourDataProtectedBody),
        (Icons.groups_rounded, l10n.yourDataWhoTitle, l10n.yourDataWhoBody),
        (Icons.block_rounded, l10n.yourDataNeverTitle, l10n.yourDataNeverBody),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.l),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PsIconBadge(icon: icon, tone: PsBadgeTone.mint, size: 36),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.headline),
                const SizedBox(height: 2),
                Text(body, style: AppText.footnote),
              ]),
            ),
          ]),
        ),
    ]),
  );
}
