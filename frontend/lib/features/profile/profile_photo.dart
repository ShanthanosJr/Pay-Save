import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api/error_messages.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/widgets/ps_icon_badge.dart';
import '../../core/widgets/ps_list_row.dart';
import '../../core/widgets/ps_sheet.dart';
import '../../l10n/gen/app_localizations.dart';

/// Picks the image. Overridable in tests.
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

enum _PhotoAction { camera, gallery, remove }

/// Take / choose / remove the signed-in user's profile photo. [onBusy] wraps
/// the upload so the caller can show progress on the avatar.
Future<void> showProfilePhotoSheet(BuildContext context, WidgetRef ref, {required ValueChanged<bool> onBusy}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final picker = ref.read(imagePickerProvider);
  final auth = ref.read(authControllerProvider);
  if (auth is! AuthLoggedIn) return;
  final hasPhoto = auth.user.avatarUrl != null;
  final canUseCamera = !kIsWeb && picker.supportsImageSource(ImageSource.camera);

  final action = await showPsSheet<_PhotoAction>(
    context: context,
    title: l10n.changePhotoLabel,
    builder: (ctx) => Column(
      children: [
        if (canUseCamera)
          PsListRow(
            icon: Icons.photo_camera_rounded,
            title: l10n.photoTake,
            onTap: () => Navigator.of(ctx).pop(_PhotoAction.camera),
          ),
        PsListRow(
          icon: Icons.photo_library_rounded,
          tone: PsBadgeTone.mint,
          title: l10n.photoChoose,
          onTap: () => Navigator.of(ctx).pop(_PhotoAction.gallery),
        ),
        if (hasPhoto)
          PsListRow(
            icon: Icons.delete_outline_rounded,
            tone: PsBadgeTone.danger,
            title: l10n.photoRemove,
            onTap: () => Navigator.of(ctx).pop(_PhotoAction.remove),
          ),
      ],
    ),
  );
  if (action == null) return;

  final api = ref.read(authApiProvider);
  final controller = ref.read(authControllerProvider.notifier);
  try {
    if (action == _PhotoAction.remove) {
      onBusy(true);
      controller.setUser(await api.removeAvatar());
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoRemovedToast)));
      return;
    }
    // Downscaled and re-encoded on device: a profile photo never needs more.
    final file = await picker.pickImage(
      source: action == _PhotoAction.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return;
    onBusy(true);
    final bytes = await file.readAsBytes();
    controller.setUser(await api.uploadAvatar(bytes, file.name));
    messenger.showSnackBar(SnackBar(content: Text(l10n.photoUpdatedToast)));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(messageFor(l10n, e))));
  } finally {
    onBusy(false);
  }
}
