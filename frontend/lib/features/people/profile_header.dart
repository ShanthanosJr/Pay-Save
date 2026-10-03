import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/ps_user_avatar.dart';
import '../../l10n/gen/app_localizations.dart';
import 'person_row.dart';

/// Instagram-style top of a profile: photo beside counts, then name,
/// @username, bio and a few facts. Shows only public fields.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.username,
    this.verified = false,
    this.bio,
    this.city,
    this.memberSince,
    this.followers,
    this.following,
    this.sharedCircles,
    this.onFollowers,
    this.onFollowing,
    this.onEditPhoto,
    this.photoBusy = false,
    this.onAddUsername,
    this.badge,
    this.isMe = false,
  });

  final String name;
  final String? avatarUrl;
  final String? username;
  final bool verified;
  final String? bio;
  final String? city;
  final DateTime? memberSince;
  final int? followers;
  final int? following;
  final int? sharedCircles;
  final VoidCallback? onFollowers;
  final VoidCallback? onFollowing;

  /// When set, the photo shows a camera button (own profile only).
  final VoidCallback? onEditPhoto;
  final bool photoBusy;
  final VoidCallback? onAddUsername;

  /// e.g. a "Follows you" pill.
  final Widget? badge;

  /// On your own profile the third count is all your circles, not shared ones.
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatar = PsUserAvatar(name: name, avatarUrl: avatarUrl, size: 92, ring: true, tone: AppColors.mint);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onEditPhoto == null)
              avatar
            else
              Semantics(
                button: true,
                label: l10n.changePhotoLabel,
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: photoBusy ? null : onEditPhoto,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      avatar,
                      if (photoBusy)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: AppColors.scrim, shape: BoxShape.circle),
                            child: Center(child: CircularProgressIndicator(color: AppColors.onForest, strokeWidth: 2)),
                          ),
                        ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.forest700,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 3),
                          ),
                          child: const Icon(Icons.photo_camera_rounded, size: 16, color: AppColors.onForest),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: AppSpace.l),
            Expanded(
              child: Row(
                children: [
                  _Stat(count: followers, label: l10n.followersLabel, onTap: onFollowers),
                  _Stat(count: following, label: l10n.followingLabel, onTap: onFollowing),
                  _Stat(count: sharedCircles, label: isMe ? l10n.navCircles : l10n.sharedCirclesLabel),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.l),
        NameWithTick(name: name, verified: verified, style: AppText.title, maxLines: 2),
        if (username != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('@$username', style: AppText.callout.copyWith(color: AppColors.inkMuted)),
          )
        else if (onAddUsername != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSpace.minTouch),
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.forest700,
              ),
              onPressed: onAddUsername,
              icon: const Icon(Icons.alternate_email_rounded, size: 18),
              label: Text(l10n.addUsernamePrompt, style: AppText.label.copyWith(color: AppColors.forest700)),
            ),
          ),
        if (badge != null) ...[const SizedBox(height: AppSpace.s), badge!],
        if (bio != null && bio!.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s),
          Text(bio!, style: AppText.body.copyWith(color: AppColors.ink)),
        ],
        const SizedBox(height: AppSpace.s),
        Wrap(
          spacing: AppSpace.l,
          runSpacing: AppSpace.xs,
          children: [
            if (city != null && city!.isNotEmpty) _Fact(icon: Icons.place_outlined, text: city!),
            if (memberSince != null)
              _Fact(
                icon: Icons.calendar_month_outlined,
                text: l10n.memberSince(DateFormat.yMMM(l10n.localeName).format(memberSince!)),
              ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.count, required this.label, this.onTap});

  final int? count;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = count == null
        ? '–'
        : NumberFormat.compact(locale: AppLocalizations.of(context).localeName).format(count);
    return Expanded(
      child: Semantics(
        button: onTap != null,
        label: '$value $label',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.small),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: AppText.figureSmall),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, maxLines: 2, style: AppText.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppColors.inkMuted),
      const SizedBox(width: 4),
      Flexible(child: Text(text, style: AppText.footnote)),
    ],
  );
}
