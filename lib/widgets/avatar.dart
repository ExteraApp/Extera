import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/utils/string_color.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import 'package:extera_next/widgets/presence_builder.dart';

class Avatar extends StatelessWidget {
  final Uri? mxContent;
  final String? name;
  final double size;
  final void Function()? onTap;
  static const double defaultSize = 44;
  final Client? client;
  final String? presenceUserId;
  final Color? presenceBackgroundColor;
  final BorderRadius? borderRadius;
  final IconData? icon;
  final BorderSide? border;
  final Color? backgroundColor;
  final Color? textColor;

  const Avatar({
    this.mxContent,
    this.name,
    this.size = defaultSize,
    this.onTap,
    this.client,
    this.presenceUserId,
    this.presenceBackgroundColor,
    this.borderRadius,
    this.border,
    this.icon,
    this.backgroundColor,
    this.textColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate expensive or logic-heavy primitives once
    final borderRadius =
        this.borderRadius ??
        BorderRadius.circular(
          (size / 2) * AppSettings.avatarBorderRadius.value,
        );

    // 2. Wrap the layout in a Stack
    final container = Stack(
      children: [
        // 3. Optimization: RepaintBoundary
        // This isolates the heavy image painting. Even if 'Avatar' is rebuilt
        // 2500 times, the GPU will reuse the texture of this child
        // as long as the widget parameters here don't change visually.
        RepaintBoundary(
          child: _AvatarVisuals(
            mxContent: mxContent,
            name: name,
            size: size,
            client: client,
            borderRadius: borderRadius,
            border: border,
            backgroundColor: backgroundColor,
            textColor: textColor,
          ),
        ),

        // Presence is dynamic and sits on top
        if (presenceUserId != null)
          _AvatarPresence(
            client: client,
            userId: presenceUserId!,
            presenceBackgroundColor: presenceBackgroundColor,
          ),
      ],
    );

    if (onTap == null) return container;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: container),
    );
  }
}

// Extracted to keep the main build method clean and allow for specific optimization
class _AvatarVisuals extends StatelessWidget {
  final Uri? mxContent;
  final String? name;
  final double size;
  final Client? client;
  final BorderRadius borderRadius;
  final BorderSide? border;
  final Color? backgroundColor;
  final Color? textColor;

  const _AvatarVisuals({
    required this.mxContent,
    required this.name,
    required this.size,
    required this.client,
    required this.borderRadius,
    this.border,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Efficient fallback logic
    final hasNoPic =
        mxContent == null ||
        mxContent!.path.isEmpty ||
        mxContent.toString() == 'null';

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: theme.brightness == Brightness.light
            ? Colors.white
            : Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: border ?? BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: MxcImage(
          client: client,
          borderRadius: borderRadius,
          // Optimization: Use Object key directly, avoid .toString() allocation
          key: ValueKey(mxContent),
          cacheKey: '${mxContent}_$size',
          uri: mxContent,
          fit: BoxFit.cover,
          width: size,
          height: size,
          // Optimization: Extract placeholder to method to keep indentation clean
          placeholder: (_) => hasNoPic
              ? _buildFallback(theme)
              : Center(
                  child: Icon(
                    Icons.person_2,
                    color: theme.colorScheme.tertiary,
                    size: size / 1.5,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFallback(ThemeData theme) {
    final displayName = name;
    final fallbackLetters = (displayName == null || displayName.isEmpty)
        ? '@'
        : displayName.substring(0, 1);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? displayName?.lightColorAvatar,
      ),
      alignment: Alignment.center,
      child: Text(
        fallbackLetters,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'RobotoMono',
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: (size / 2.5).roundToDouble(),
        ),
      ),
    );
  }
}

// Extracted Presence logic
class _AvatarPresence extends StatelessWidget {
  final Client? client;
  final String userId;
  final Color? presenceBackgroundColor;

  const _AvatarPresence({
    required this.client,
    required this.userId,
    this.presenceBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return PresenceBuilder(
      client: client,
      userId: userId,
      builder: (context, presence) {
        if (presence == null ||
            (presence.presence == PresenceType.offline &&
                presence.lastActiveTimestamp == null)) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final dotColor = presence.presence.isOnline
            ? Colors.green
            : presence.presence.isUnavailable
            ? Colors.orange
            : Colors.grey;

        return Positioned(
          bottom: -3,
          right: -3,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: presenceBackgroundColor ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(32),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(width: 1, color: theme.colorScheme.surface),
              ),
            ),
          ),
        );
      },
    );
  }
}
