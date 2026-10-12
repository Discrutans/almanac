import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/app_providers.dart';
import '../core/theme/almanac_tokens.dart';
import '../core/ui/almanac_avatar.dart';
import 'profile_manager_sheet.dart';
import 'profile_quick_menu.dart';

/// Кнопка активного профиля с компактным выпадающим меню.
class ProfileSwitcher extends ConsumerStatefulWidget {
  const ProfileSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  ConsumerState<ProfileSwitcher> createState() => _ProfileSwitcherState();
}

class _ProfileSwitcherState extends ConsumerState<ProfileSwitcher> {
  final _anchorKey = GlobalKey();

  Future<void> _openMenu() async {
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null || !mounted) return;

    final renderObject = anchorContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final box = renderObject;
    final overlayObject = Overlay.of(context).context.findRenderObject();
    if (overlayObject is! RenderBox || !overlayObject.hasSize) return;

    final overlay = overlayObject;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    const menuWidth = ProfileQuickMenuPanel.minWidth;
    final left = (topLeft.dx + box.size.width - menuWidth).clamp(
      8.0,
      overlay.size.width - menuWidth - 8,
    );
    final top = topLeft.dy + box.size.height + 4;
    final scheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      builder: (dialogContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                behavior: HitTestBehavior.translucent,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: Material(
                elevation: 6,
                shadowColor: scheme.shadow.withValues(alpha: 0.14),
                borderRadius: AlmanacRadius.card,
                clipBehavior: Clip.antiAlias,
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.98),
                child: ProfileQuickMenuPanel(
                  onClose: () => Navigator.pop(dialogContext),
                  hostContext: context,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleLabel = ref.watch(
      contextProfilesProvider.select((state) => state.visibleLabel),
    );
    final active = ref.watch(
      contextProfilesProvider.select((state) => state.active),
    );

    final avatar = AlmanacProfileAvatar(
      name: active.name,
      seedColor: active.seedColor,
      isActive: true,
      size: AlmanacAvatarSize.sm,
    );

    if (widget.compact) {
      return GestureDetector(
        onLongPress: () => ProfileManagerSheet.show(context),
        child: IconButton(
          key: _anchorKey,
          tooltip: visibleLabel,
          onPressed: _openMenu,
          icon: avatar,
        ),
      );
    }

    return TextButton(
      key: _anchorKey,
      onPressed: _openMenu,
      onLongPress: () => ProfileManagerSheet.show(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: AlmanacSpacing.xs),
          Flexible(child: Text(visibleLabel, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: AlmanacSpacing.xxs),
          Icon(
            Icons.expand_more,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
