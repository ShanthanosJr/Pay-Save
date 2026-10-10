import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_models.dart';
import '../../core/payouts/payouts_api.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/text_scale_provider.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_otp_field.dart';
import '../../core/widgets/ps_section.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import '../pals/pal_requests_row.dart';
import '../people/profile_header.dart';
import '../shell/brand_header.dart';
import 'profile_photo.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _photoBusy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthLoggedIn) return const SizedBox.shrink();
    final user = auth.user;
    final public = ref.watch(publicProfileProvider(user.id)).value;
    final locale = ref.watch(localeProvider);
    final textSize = ref.watch(textScaleProvider);

    return PsForestPage(
      header: const BrandHeader(),
      children: [
        ProfileHeader(
          name: user.fullName,
          avatarUrl: user.avatarUrl,
          username: user.username,
          verified: user.phoneVerified,
          bio: user.bio,
          city: user.city,
          memberSince: public?.memberSince,
          followers: public?.followersCount,
          pals: public?.palsCount,
          sharedCircles: public?.sharedCircles,
          onFollowers: () => context.push('/people/${user.id}/followers'),
          onPals: () => context.push('/people/${user.id}/pals'),
          photoBusy: _photoBusy,
          onEditPhoto: () => showProfilePhotoSheet(
            context,
            ref,
            onBusy: (v) {
              if (mounted) setState(() => _photoBusy = v);
            },
          ),
          onAddUsername: () => context.push('/profile/edit'),
          isMe: true,
        ),
        const SizedBox(height: AppSpace.l),
        PsButton(
          label: l10n.editProfile,
          icon: Icons.edit_outlined,
          variant: PsButtonVariant.secondary,
          compact: true,
          onPressed: () => context.push('/profile/edit'),
        ),
        const SizedBox(height: AppSpace.m),
        const PalRequestsRow(),
        const SizedBox(height: AppSpace.xxl),

        PsSectionHeader(title: l10n.privateDetailsTitle),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: AppSpace.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: AppSpace.s),
              Expanded(child: Text(l10n.privateDetailsNote, style: AppText.footnote)),
            ],
          ),
        ),
        PsInfoRow(
          label: l10n.profilePhone,
          value: user.phoneMasked,
          trailing: _Verified(ok: user.phoneVerified, l10n: l10n),
        ),
        PsInfoRow(
          label: l10n.profileEmail,
          value: user.email ?? '—',
          trailing: user.emailVerified || user.email == null
              ? _Verified(ok: user.emailVerified, l10n: l10n)
              : PsButton(
                  label: l10n.verifyShort,
                  compact: true,
                  expand: false,
                  onPressed: () => _openEmailVerify(context, user),
                ),
        ),
        PsInfoRow(label: l10n.profileNic, value: user.nicMasked),
        PsInfoRow(label: l10n.profileAge, value: '${user.age}'),
        const SizedBox(height: AppSpace.xxxl),

        PsSectionHeader(
          title: l10n.settingsTitle,
          trailing: PsPillLink(label: l10n.settingsOpen, icon: Icons.settings_rounded, onTap: () => context.push('/settings')),
        ),
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
        const SizedBox(height: AppSpace.xl),
        PsGroupLabel(l10n.profileLanguage),
        PsSegmented<String>(
          segments: [('en', l10n.languageEnglish), ('si', l10n.languageSinhala), ('ta', l10n.languageTamil)],
          selected: locale.languageCode,
          onChanged: (code) => ref.read(localeProvider.notifier).set(Locale(code)),
        ),
        const SizedBox(height: AppSpace.xl),
        PsGroupLabel(l10n.accountGroup),
        const _PaymentMethodsRow(),
        PsListRow(
          icon: Icons.phone_iphone_rounded,
          tone: PsBadgeTone.mint,
          title: l10n.changePhoneTitle,
          showChevron: true,
          onTap: () => context.push('/profile/phone'),
        ),
        PsListRow(
          icon: Icons.lock_reset_rounded,
          tone: PsBadgeTone.mint,
          title: l10n.changePasswordTitle,
          showChevron: true,
          onTap: () => context.push('/profile/password'),
        ),
        if (user.isCommunityOfficer)
          PsListRow(
            icon: Icons.shield_rounded,
            tone: PsBadgeTone.info,
            title: l10n.communityTitle,
            subtitle: l10n.communityRowHint,
            showChevron: true,
            onTap: () => context.push('/community'),
          ),
        PsListRow(
          icon: Icons.logout_rounded,
          tone: PsBadgeTone.danger,
          title: l10n.logOut,
          titleColor: AppColors.danger,
          showChevron: true,
          onTap: () => _confirmLogout(context, ref),
        ),
      ],
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

  void _openEmailVerify(BuildContext context, UserProfile user) {
    final l10n = AppLocalizations.of(context);
    showPsSheet<void>(
      context: context,
      title: l10n.emailVerifyTitle,
      subtitle: l10n.emailVerifySent(user.email ?? ''),
      builder: (_) => const _EmailVerifyBody(),
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified({required this.ok, required this.l10n});

  final bool ok;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Semantics(
        label: ok ? l10n.verifiedBadge : l10n.notVerifiedBadge,
        excludeSemantics: true,
        child: Icon(
          ok ? Icons.verified_rounded : Icons.error_outline_rounded,
          size: 22,
          color: ok ? AppColors.success : AppColors.warning,
        ),
      );
}

class _EmailVerifyBody extends ConsumerStatefulWidget {
  const _EmailVerifyBody();

  @override
  ConsumerState<_EmailVerifyBody> createState() => _EmailVerifyBodyState();
}

class _EmailVerifyBodyState extends ConsumerState<_EmailVerifyBody> {
  final _otpKey = GlobalKey<PsOtpFieldState>();
  bool _sent = false;
  bool _busy = false;
  String? _devCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = await ref.read(authApiProvider).requestEmailOtp();
      if (mounted) {
        setState(() {
          _sent = true;
          _devCode = c.devCode;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(String code) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authApiProvider).verifyEmailOtp(code);
      ref.read(authControllerProvider.notifier).markEmailVerified();
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.emailVerifiedToast)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = messageFor(l10n, e));
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_sent) ...[
        PsOtpField(key: _otpKey, hasError: _error != null, semanticLabel: l10n.otpFieldLabel, onCompleted: _verify),
        if (_devCode != null) ...[
          const SizedBox(height: AppSpace.m),
          Text(l10n.devCodeNotice(_devCode!), style: AppText.caption, textAlign: TextAlign.center),
        ],
      ],
      if (_error != null) ...[
        const SizedBox(height: AppSpace.l),
        ErrorBanner(_error!),
      ],
      const SizedBox(height: AppSpace.l),
      if (_busy)
        const Center(child: CircularProgressIndicator(strokeWidth: 2))
      else if (_sent)
        Center(
          child: TextButton(
            onPressed: _send,
            child: Text(l10n.resendCode, style: AppText.label.copyWith(decoration: TextDecoration.underline)),
          ),
        ),
    ]);
  }
}

/// "How you get paid", with the default method as the subtitle.
class _PaymentMethodsRow extends ConsumerWidget {
  const _PaymentMethodsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final methods = ref.watch(myPayoutMethodsProvider).value;
    final def = methods?.where((m) => m.isDefault).firstOrNull ?? methods?.firstOrNull;
    return PsListRow(
      icon: Icons.account_balance_wallet_rounded,
      tone: def == null ? PsBadgeTone.warning : PsBadgeTone.mint,
      title: l10n.paymentMethodsTitle,
      subtitle: def?.summary ?? l10n.howYouGetPaidEmpty,
      showChevron: true,
      onTap: () => context.push('/profile/payment-methods'),
    );
  }
}
