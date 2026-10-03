import 'package:flutter/material.dart';

import '../../core/social/social_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';

/// One member in a list: photo, name (+ verified tick), @username or a reason line.
class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person, required this.onTap, this.subtitle, this.trailing});

  final Person person;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final line = subtitle ?? (person.username == null ? null : '@${person.username}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.stroke),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  PsUserAvatar(name: person.fullName, avatarUrl: person.avatarUrl, size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NameWithTick(name: person.fullName, verified: person.verified, style: AppText.headline),
                        if (line != null) ...[
                          const SizedBox(height: 2),
                          Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.footnote),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ] else
                    Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted, semanticLabel: l10n.viewProfile),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Name followed by a verified tick that is announced, not just coloured.
class NameWithTick extends StatelessWidget {
  const NameWithTick({super.key, required this.name, required this.verified, required this.style, this.maxLines = 1});

  final String name;
  final bool verified;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text(name, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style)),
      if (verified) ...[
        const SizedBox(width: 4),
        Icon(
          Icons.verified_rounded,
          size: (style.fontSize ?? 16) * 0.95,
          color: AppColors.success,
          semanticLabel: l10n.verifiedMember,
        ),
      ],
    ]);
  }
}
