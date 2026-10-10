import 'package:flutter/material.dart';
import '../../../core/widgets/ps_password_strength.dart';
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
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

/// Reset a forgotten password with a code sent to the account's phone or email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  /// Normalised identifier the code was sent for; null until then.
  String? _sentTo;
  String? _channel;
  String? _devCode;
  String _code = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final identifier = normalizeIdentifier(_identifier.text);
    await _run(() async {
      final c = await ref.read(authApiProvider).forgotPassword(identifier);
      if (!mounted) return;
      setState(() {
        _sentTo = identifier;
        _channel = c.channel;
        _devCode = c.devCode;
      });
    });
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    if (_code.length != 6) {
      setState(() => _error = l10n.errInvalidCode);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await _run(() async {
      await ref.read(authApiProvider).resetPassword(
            identifier: _sentTo!,
            code: _code,
            newPassword: _password.text,
          );
      router.go('/login');
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordResetToast)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = Validators(l10n);
    final sent = _sentTo != null;

    return AuthScaffold(
      titlePlain: l10n.forgotTitlePlain,
      titleAccent: l10n.forgotTitleAccent,
      subtitle: sent
          ? (_channel == 'email' ? l10n.resetCodeSentEmail(_sentTo!) : l10n.resetCodeSentSms(_sentTo!))
          : l10n.forgotSubtitle,
      onBack: () => sent ? setState(() => _sentTo = null) : context.go('/login'),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!sent)
              PsTextField(
                label: l10n.identifierLabel,
                hint: l10n.identifierHint,
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: v.identifier,
                onSubmitted: (_) => _send(),
              )
            else ...[
              PsOtpField(
                hasError: _error != null,
                semanticLabel: l10n.otpFieldLabel,
                onChanged: (c) => _code = c,
                onCompleted: (c) => _code = c,
              ),
              if (_devCode != null) ...[
                const SizedBox(height: AppSpace.m),
                Text(l10n.devCodeNotice(_devCode!), style: AppText.caption),
              ],
              const SizedBox(height: AppSpace.xl),
              PsTextField(
                label: l10n.newPasswordLabel,
                hint: l10n.passwordHint,
                controller: _password,
                obscure: true,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.newPassword,
                below: PsPasswordStrength(controller: _password),
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.confirmPasswordLabel,
                hint: l10n.passwordHint,
                controller: _confirm,
                obscure: true,
                textInputAction: TextInputAction.done,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.confirmPassword(() => _password.text),
                onSubmitted: (_) => _reset(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpace.l),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: AppSpace.xxl),
            PsButton(
              label: sent ? l10n.resetPasswordAction : l10n.sendCode,
              onPressed: sent ? _reset : _send,
              loading: _busy,
            ),
          ],
        ),
      ),
    );
  }
}
