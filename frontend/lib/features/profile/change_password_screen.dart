import 'package:flutter/material.dart';
import '../../core/widgets/ps_password_strength.dart';
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
import '../../core/widgets/ps_text_field.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).changePassword(_current.text, _next.text);
      router.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChangedToast)));
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
    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.changePasswordTitle, backLabel: l10n.backLabel),
        children: [
          Text(l10n.changePasswordNote, style: AppText.body),
          const SizedBox(height: AppSpace.xl),
          Form(
            key: _form,
            child: Column(children: [
              PsTextField(
                label: l10n.currentPasswordLabel,
                hint: l10n.passwordHint,
                controller: _current,
                obscure: true,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.required,
              ),
              const SizedBox(height: AppSpace.l),
              PsTextField(
                label: l10n.newPasswordLabel,
                hint: l10n.passwordHint,
                controller: _next,
                obscure: true,
                showLabel: l10n.showPassword,
                hideLabel: l10n.hidePassword,
                validator: v.newPassword,
                below: PsPasswordStrength(controller: _next),
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
                validator: v.confirmPassword(() => _next.text),
                onSubmitted: (_) => _submit(),
              ),
            ]),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.l),
            ErrorBanner(_error!),
          ],
          const SizedBox(height: AppSpace.xxl),
          PsButton(label: l10n.changePasswordTitle, onPressed: _submit, loading: _busy),
        ],
      ),
    );
  }
}
