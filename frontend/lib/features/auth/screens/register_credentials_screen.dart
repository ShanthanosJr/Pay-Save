import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_text_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../register_draft.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

class RegisterCredentialsScreen extends ConsumerStatefulWidget {
  const RegisterCredentialsScreen({super.key});

  @override
  ConsumerState<RegisterCredentialsScreen> createState() => _RegisterCredentialsScreenState();
}

class _RegisterCredentialsScreenState extends ConsumerState<RegisterCredentialsScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final draft = ref.read(registerDraftProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref.read(authApiProvider).register(
            fullName: draft.fullName,
            age: draft.age,
            nic: draft.nic,
            phone: draft.phone,
            email: _email.text.trim().toLowerCase(),
            password: _password.text,
            phoneVerificationToken: draft.phoneVerificationToken,
          );
      ref.read(registerDraftProvider.notifier).reset();
      await ref.read(authControllerProvider.notifier).completeRegistration(session);
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = Validators(l10n);

    return AuthScaffold(
      titlePlain: l10n.regCredTitlePlain,
      titleAccent: l10n.regCredTitleAccent,
      subtitle: l10n.regCredSubtitle,
      stepLabel: l10n.registerStep(3, 3),
      step: 3,
      totalSteps: 3,
      onBack: () => context.go('/register/phone'),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PsTextField(
                label: l10n.emailLabel,
                hint: l10n.emailHint,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: v.email,
              ),
              const SizedBox(height: 16),
              PsTextField(
                label: l10n.createPasswordLabel,
                hint: l10n.createPasswordHint,
                controller: _password,
                obscure: true,
                autofillHints: const [AutofillHints.newPassword],
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.newPassword,
              ),
              const SizedBox(height: 16),
              PsTextField(
                label: l10n.confirmPasswordLabel,
                controller: _confirm,
                obscure: true,
                textInputAction: TextInputAction.done,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.confirmPassword(() => _password.text),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(_error!),
              ],
              const SizedBox(height: 32),
              PsButton(label: l10n.createAccount, onPressed: _submit, loading: _busy),
            ],
          ),
        ),
      ),
    );
  }
}
