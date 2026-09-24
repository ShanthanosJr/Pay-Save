import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/error_messages.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/ps_button.dart';
import '../../../core/widgets/ps_text_field.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(
            normalizeIdentifier(_identifier.text),
            _password.text,
          );
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
      titlePlain: l10n.loginTitlePlain,
      titleAccent: l10n.loginTitleAccent,
      subtitle: l10n.loginSubtitle,
      onBack: () => context.go('/'),
      footer: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${l10n.noAccountPrompt} ', style: AppText.small),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink,
              minimumSize: const Size(AppSpace.minTouch, AppSpace.minTouch),
            ),
            onPressed: () => context.go('/register/details'),
            child: Text(l10n.createAccount, style: AppText.label.copyWith(decoration: TextDecoration.underline)),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PsTextField(
                label: l10n.identifierLabel,
                hint: l10n.identifierHint,
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                validator: v.identifier,
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.passwordLabel,
                hint: l10n.passwordHint,
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.required,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpace.l),
                ErrorBanner(_error!),
              ],
              const SizedBox(height: AppSpace.xxl),
              PsButton(label: l10n.logIn, onPressed: _submit, loading: _busy),
            ],
          ),
        ),
      ),
    );
  }
}
