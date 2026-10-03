import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_models.dart';
import '../../core/social/social_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/ps_back_header.dart';
import '../../core/widgets/ps_button.dart';
import '../../core/widgets/ps_forest_page.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_text_field.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../auth/widgets/error_banner.dart';
import 'profile_photo.dart';

/// Everything a member may change about themselves except email and password.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final UserProfile _initial;
  late final _name = TextEditingController(text: _initial.fullName);
  late final _username = TextEditingController(text: _initial.username ?? '');
  late final _bio = TextEditingController(text: _initial.bio ?? '');
  late final _city = TextEditingController(text: _initial.city ?? '');
  late final _age = TextEditingController(text: '${_initial.age}');
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initial = (ref.read(authControllerProvider) as AuthLoggedIn).user;
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _bio, _city, _age]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    String? changed(String now, String? before) => now == (before ?? '') ? null : now;
    final name = _name.text.trim();
    final age = int.parse(_age.text.trim());
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authApiProvider)
          .updateProfile(
            fullName: name == _initial.fullName ? null : name,
            age: age == _initial.age ? null : age,
            username: changed(Validators.normalizeUsername(_username.text), _initial.username),
            bio: changed(_bio.text.trim(), _initial.bio),
            city: changed(_city.text.trim(), _initial.city),
          );
      ref.read(authControllerProvider.notifier).setUser(user);
      ref.invalidate(publicProfileProvider(user.id));
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileSavedToast)));
      router.pop();
    } catch (e) {
      if (mounted) setState(() => _error = messageFor(l10n, e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final v = Validators(l10n);
    final auth = ref.watch(authControllerProvider);
    final user = auth is AuthLoggedIn ? auth.user : _initial;

    return Scaffold(
      body: PsForestPage(
        header: PsBackHeader(title: l10n.editProfile, backLabel: l10n.backLabel),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PsUserAvatar(
                  name: user.fullName,
                  avatarUrl: user.avatarUrl,
                  size: 104,
                  ring: true,
                  tone: AppColors.mint,
                ),
                if (_photoBusy) const CircularProgressIndicator(color: AppColors.forest700, strokeWidth: 2),
              ],
            ),
          ),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(0, AppSpace.minTouch)),
              onPressed: _photoBusy
                  ? null
                  : () => showProfilePhotoSheet(
                      context,
                      ref,
                      onBusy: (b) {
                        if (mounted) setState(() => _photoBusy = b);
                      },
                    ),
              child: Text(l10n.changePhotoLabel, style: AppText.label.copyWith(color: AppColors.forest700)),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PsTextField(
                  label: l10n.fullNameLabel,
                  controller: _name,
                  validator: v.fullName,
                  maxLength: 80,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: AppSpace.l),
                PsTextField(
                  label: l10n.usernameLabel,
                  controller: _username,
                  hint: l10n.usernameHint,
                  prefixText: '@',
                  helper: l10n.usernameHelper,
                  validator: v.username,
                  maxLength: 31,
                  autofillHints: const [AutofillHints.username],
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._@]'))],
                ),
                const SizedBox(height: AppSpace.l),
                PsTextField(
                  label: l10n.bioLabel,
                  controller: _bio,
                  hint: l10n.bioHint,
                  maxLength: 160,
                  maxLines: 4,
                  showCounter: true,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: AppSpace.l),
                PsTextField(
                  label: l10n.cityLabel,
                  controller: _city,
                  hint: l10n.cityHint,
                  maxLength: 60,
                  autofillHints: const [AutofillHints.addressCity],
                ),
                const SizedBox(height: AppSpace.l),
                PsTextField(
                  label: l10n.ageLabel,
                  controller: _age,
                  validator: v.age,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          PsInfoRow(label: l10n.profilePhone, value: user.phoneMasked),
          PsListRow(
            icon: Icons.phone_iphone_rounded,
            title: l10n.changePhoneTitle,
            showChevron: true,
            onTap: () => context.push('/profile/phone'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: AppSpace.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.inkMuted),
                const SizedBox(width: AppSpace.s),
                Expanded(child: Text(l10n.lockedFieldsNote, style: AppText.footnote)),
              ],
            ),
          ),
          if (_error != null) ...[const SizedBox(height: AppSpace.l), ErrorBanner(_error!)],
          const SizedBox(height: AppSpace.xxl),
          PsButton(label: l10n.saveChanges, loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
