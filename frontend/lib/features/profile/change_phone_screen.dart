import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_otp_field.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';

/// New number → SMS code → swap. Same OTP endpoints as registration.
class ChangePhoneScreen extends ConsumerStatefulWidget {
  const ChangePhoneScreen({super.key});

  @override
  ConsumerState<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends ConsumerState<ChangePhoneScreen> {
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
      if (!mounted || _cooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _cooldown = 0);
      } else {
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
      final c = await ref.read(authApiProvider).requestPhoneOtp(phone);
      if (!mounted) return;
      setState(() {
        _sentTo = phone;
        _devCode = c.devCode;
      });
      _startCooldown(c.resendAfterSeconds);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify(String code) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ref.read(authApiProvider);
      final token = await api.verifyPhoneOtp(_sentTo!, code);
      final user = await api.changePhone(_sentTo!, token);
      ref.read(authControllerProvider.notifier).setUser(user);
      messenger.showSnackBar(SnackBar(content: Text(l10n.phoneChangedToast)));
      router.pop();
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
    final v = Validators(l10n);
    final sent = _sentTo != null;

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.changePhoneTitle, backLabel: l10n.backLabel),
        children: [
          Text(sent ? l10n.otpSentTo(_sentTo!) : l10n.changePhoneSubtitle, style: AppText.body),
          const SizedBox(height: AppSpace.xxl),
          if (!sent)
            Form(
              key: _form,
              child: PsTextField(
                label: l10n.newPhoneLabel,
                hint: l10n.phoneHint,
                controller: _phone,
                validator: v.phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                onSubmitted: (_) => _sendCode(),
              ),
            )
          else ...[
            Text(l10n.enterCode, style: AppText.label),
            const SizedBox(height: AppSpace.m),
            PsOtpField(key: _otpKey, hasError: _error != null, semanticLabel: l10n.otpFieldLabel, onCompleted: _verify),
            if (_devCode != null) ...[
              const SizedBox(height: AppSpace.m),
              Text(l10n.devCodeNotice(_devCode!), style: AppText.caption),
            ],
          ],
          if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
          const SizedBox(height: AppSpace.xxl),
          if (!sent)
            PsButton(label: l10n.sendCode, loading: _busy, onPressed: _sendCode)
          else if (_busy)
            const Center(child: CircularProgressIndicator(color: AppColors.ink, strokeWidth: 2))
          else ...[
            PsButton(
              label: _cooldown > 0 ? l10n.resendIn(_cooldown) : l10n.resendCode,
              variant: PsButtonVariant.secondary,
              onPressed: _cooldown > 0 ? null : _sendCode,
            ),
            const SizedBox(height: AppSpace.m),
            PsButton(
              label: l10n.changeNumber,
              variant: PsButtonVariant.secondary,
              onPressed: () => setState(() {
                _timer?.cancel();
                _sentTo = null;
                _devCode = null;
                _error = null;
                _cooldown = 0;
              }),
            ),
          ],
        ],
      ),
    );
  }
}
