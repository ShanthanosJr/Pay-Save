import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_models.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_otp_field.dart';
import '../../core/widgets/ps_tag.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthLoggedIn) return const SizedBox.shrink();
    final user = auth.user;
    final locale = ref.watch(localeProvider);
    void setLocale(String code) => ref.read(localeProvider.notifier).set(Locale(code));

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.xl, AppSpace.screen, AppSpace.xxl),
            children: [
              Text(l10n.profileTitle, style: AppText.caption),
              const SizedBox(height: AppSpace.s),
              Text(user.fullName, style: AppText.headline),
              const SizedBox(height: AppSpace.xl),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Column(children: [
                  _Row(label: l10n.profileAge, value: '${user.age}'),
                  _Row(
                    label: l10n.profilePhone,
                    value: user.phoneMasked,
                    verified: user.phoneVerified,
                    verifiedLabel: l10n.verifiedBadge,
                    notVerifiedLabel: l10n.notVerifiedBadge,
                  ),
                  _Row(label: l10n.profileNic, value: user.nicMasked),
                  _Row(
                    label: l10n.profileEmail,
                    value: user.email ?? '—',
                    verified: user.emailVerified,
                    verifiedLabel: l10n.verifiedBadge,
                    notVerifiedLabel: l10n.notVerifiedBadge,
                    last: true,
                  ),
                ]),
              ),
              if (!user.emailVerified && user.email != null) ...[
                const SizedBox(height: AppSpace.l),
                PsButton(
                  label: l10n.verifyEmail,
                  variant: PsButtonVariant.light,
                  trailing: Icons.mark_email_read_outlined,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.bg,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.cardLarge)),
                    ),
                    builder: (_) => _EmailVerifySheet(user: user),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              Text(l10n.profileLanguage, style: AppText.label),
              const SizedBox(height: AppSpace.s),
              Wrap(spacing: AppSpace.s, runSpacing: AppSpace.s, children: [
                _LangChip(label: l10n.languageEnglish, selected: locale.languageCode == 'en', onTap: () => setLocale('en')),
                _LangChip(label: l10n.languageSinhala, selected: locale.languageCode == 'si', onTap: () => setLocale('si')),
                _LangChip(label: l10n.languageTamil, selected: locale.languageCode == 'ta', onTap: () => setLocale('ta')),
              ]),
              const SizedBox(height: AppSpace.xxxl),
              PsButton(
                label: l10n.logOut,
                variant: PsButtonVariant.primary,
                trailing: Icons.logout,
                onPressed: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.chip),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AppSpace.minTouch, minWidth: AppSpace.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppText.label.copyWith(color: selected ? AppColors.onDark : AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.verified,
    this.verifiedLabel = '',
    this.notVerifiedLabel = '',
    this.last = false,
  });

  final String label;
  final String value;
  final bool? verified;
  final String verifiedLabel;
  final String notVerifiedLabel;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l, vertical: AppSpace.m),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AppText.caption),
              const SizedBox(height: 2),
              Text(value, style: AppText.bodyStrong),
            ]),
          ),
          if (verified != null)
            verified!
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, size: 16, color: AppColors.statusVerified),
                    const SizedBox(width: 4),
                    Text(
                      verifiedLabel,
                      style: AppText.caption.copyWith(color: AppColors.statusVerified, fontWeight: FontWeight.w600),
                    ),
                  ])
                : PsTag(label: notVerifiedLabel),
        ],
      ),
    );
  }
}

class _EmailVerifySheet extends ConsumerStatefulWidget {
  const _EmailVerifySheet({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_EmailVerifySheet> createState() => _EmailVerifySheetState();
}

class _EmailVerifySheetState extends ConsumerState<_EmailVerifySheet> {
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.xxl,
        AppSpace.screen,
        AppSpace.xxl + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.emailVerifyTitle, style: AppText.headline),
          const SizedBox(height: AppSpace.s),
          Text(l10n.emailVerifySent(widget.user.email ?? ''), style: AppText.body),
          const SizedBox(height: AppSpace.xl),
          if (_sent) ...[
            PsOtpField(
              key: _otpKey,
              hasError: _error != null,
              semanticLabel: l10n.otpFieldLabel,
              onCompleted: _verify,
            ),
            if (_devCode != null) ...[
              const SizedBox(height: AppSpace.m),
              Text(l10n.devCodeNotice(_devCode!), style: AppText.caption),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.l),
            ErrorBanner(_error!),
          ],
          if (_busy) ...[
            const SizedBox(height: AppSpace.l),
            const Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2)),
          ] else if (_sent) ...[
            const SizedBox(height: AppSpace.m),
            Center(child: TextButton(onPressed: _send, child: Text(l10n.resendCode, style: AppText.label))),
          ],
        ],
      ),
    );
  }
}
