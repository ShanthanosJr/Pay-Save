import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_otp_field.dart';
import '../../../core/widgets/ps_text_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../register_draft.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

class RegisterPhoneScreen extends ConsumerStatefulWidget {
  const RegisterPhoneScreen({super.key});

  @override
  ConsumerState<RegisterPhoneScreen> createState() => _RegisterPhoneScreenState();
}

class _RegisterPhoneScreenState extends ConsumerState<RegisterPhoneScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otpKey = GlobalKey<PsOtpFieldState>();

  String? _sentTo;
  String? _devCode;
  String? _error;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else if (mounted) {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendCode() async {
    if (_sentTo == null && !_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final phone = _sentTo ?? normalizePhone(_phone.text)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(authApiProvider).requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() {
        _sentTo = phone;
        _devCode = challenge.devCode;
      });
      _startCooldown(challenge.resendAfterSeconds);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(String code) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await ref.read(authApiProvider).verifyPhoneOtp(_sentTo!, code);
      ref.read(registerDraftProvider.notifier).update(
            (d) => d.copyWith(phone: _sentTo, phoneVerificationToken: token),
          );
      if (mounted) context.go('/register/credentials');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = messageFor(l10n, e));
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() {
      _sentTo = null;
      _devCode = null;
      _error = null;
      _cooldown = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = Validators(l10n);
    final stage2 = _sentTo != null;

    return AuthScaffold(
      titlePlain: l10n.regPhoneTitlePlain,
      titleAccent: l10n.regPhoneTitleAccent,
      subtitle: stage2 ? l10n.otpSentTo(_sentTo!) : l10n.regPhoneSubtitle,
      stepLabel: l10n.registerStep(2, 3),
      step: 2,
      totalSteps: 3,
      onBack: () => stage2 ? _changeNumber() : context.go('/register/details'),
      child: stage2
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.enterCode, style: AppText.label),
                const SizedBox(height: AppSpace.m),
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
                if (_error != null) ...[
                  const SizedBox(height: AppSpace.l),
                  ErrorBanner(_error!),
                ],
                const SizedBox(height: AppSpace.xl),
                if (_busy)
                  const Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2))
                else ...[
                  Center(
                    child: _cooldown > 0
                        ? Text(l10n.resendIn(_cooldown), style: AppText.small)
                        : TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.ink,
                              minimumSize: const Size(AppSpace.minTouch, AppSpace.minTouch),
                            ),
                            onPressed: _sendCode,
                            child: Text(
                              l10n.resendCode,
                              style: AppText.label.copyWith(decoration: TextDecoration.underline),
                            ),
                          ),
                  ),
                  Center(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.inkMuted,
                        minimumSize: const Size(AppSpace.minTouch, AppSpace.minTouch),
                      ),
                      onPressed: _changeNumber,
                      child: Text(l10n.changeNumber, style: AppText.small),
                    ),
                  ),
                ],
              ],
            )
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PsTextField(
                    label: l10n.phoneLabel,
                    hint: l10n.phoneHint,
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-]'))],
                    validator: v.phone,
                    onSubmitted: (_) => _sendCode(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.l),
                    ErrorBanner(_error!),
                  ],
                  const SizedBox(height: AppSpace.xxxl),
                  PsButton(label: l10n.sendCode, onPressed: _sendCode, loading: _busy),
                ],
              ),
            ),
    );
  }
}
