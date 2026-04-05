import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/favourite_stickers_extension.dart';
import 'package:extera_next/utils/matrix_sdk_extensions/recent_stickers_extension.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import '../../widgets/avatar.dart';

// import 'package:extera_next/utils/url_launcher.dart';

class StickerPickerDialog extends StatefulWidget {
  final Room room;
  final void Function(ImagePackImageContent) onSelected;

  const StickerPickerDialog({
    required this.onSelected,
    required this.room,
    super.key,
  });

  @override
  StickerPickerDialogState createState() => StickerPickerDialogState();
}

class StickerPickerDialogState extends State<StickerPickerDialog> {
  String? searchFilter;

  void _onStickerSelected(ImagePackImageContent sticker) {
    widget.room.client.addRecentSticker(sticker);
    widget.onSelected(sticker);
  }

  void _showStickerInfoDialog({
    required ImagePackImageContent sticker,
    String? packName,
    String? packAttribution,
    bool isFromRecents = false,
  }) {
    final client = widget.room.client;
    showDialog(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isFavourite = client.isFavouriteSticker(sticker);
            return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MxcImage(
                    uri: sticker.url,
                    isThumbnail: false,
                    width: 384,
                    fit: BoxFit.contain,
                    animated: true,
                  ),
                  const SizedBox(height: 16),
                  if (sticker.body != null && sticker.body!.isNotEmpty)
                    Text(
                      sticker.body!,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  if (packName != null && packName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      packName,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (packAttribution != null &&
                      packAttribution.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      packAttribution,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],

                  Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                    clipBehavior: .hardEdge,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.send_outlined),
                          title: Text(L10n.of(context).sendSticker),
                          onTap: () async {
                            _onStickerSelected(sticker);
                            setDialogState(() {});
                            setState(() {});
                            if (mounted) {
                              Navigator.of(context, rootNavigator: false).pop();
                            }
                          },
                        ),
                        ListTile(
                          leading: Icon(
                            isFavourite ? Icons.star : Icons.star_border,
                          ),
                          title: Text(
                            isFavourite
                                ? L10n.of(context).removeFromFavourites
                                : L10n.of(context).addToFavourites,
                          ),
                          onTap: () async {
                            if (isFavourite) {
                              await client.removeFavouriteSticker(sticker);
                            } else {
                              await client.addFavouriteSticker(sticker);
                            }
                            setDialogState(() {});
                            setState(() {});
                          },
                        ),
                        if (isFromRecents)
                          ListTile(
                            iconColor: Theme.of(context).colorScheme.error,
                            leading: const Icon(Icons.delete_outline),
                            title: Text(
                              L10n.of(context).removeFromRecents,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            onTap: () async {
                              await client.removeRecentSticker(sticker);
                              setState(() {});
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStickerGrid(
    List<ImagePackImageContent> stickers, {
    bool isFromRecents = false,
  }) {
    return GridView.builder(
      itemCount: stickers.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 84,
        mainAxisSpacing: 8.0,
        crossAxisSpacing: 8.0,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (BuildContext context, int index) {
        final image = stickers[index];
        return Tooltip(
          message: image.body ?? '',
          child: InkWell(
            radius: AppConfig.borderRadius,
            key: ValueKey(image.url.toString()),
            onTap: () {
              final imageCopy = ImagePackImageContent.fromJson(
                image.toJson().copy(),
              );
              _onStickerSelected(imageCopy);
            },
            onLongPress: () {
              _showStickerInfoDialog(
                sticker: image,
                isFromRecents: isFromRecents,
              );
            },
            child: AbsorbPointer(
              absorbing: true,
              child: MxcImage(
                uri: image.url,
                fit: BoxFit.contain,
                width: 128,
                height: 128,
                animated: true,
                isThumbnail: false,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = widget.room.client;

    final stickerPacks = widget.room.getImagePacks(ImagePackUsage.sticker);
    final packSlugs = stickerPacks.keys.toList();

    final recentStickers = client.recentStickers;
    final hasRecentStickers =
        recentStickers.isNotEmpty && !(searchFilter?.isNotEmpty ?? false);

    // ignore: prefer_function_declarations_over_variables
    final packBuilder = (BuildContext context, int packIndex) {
      final pack = stickerPacks[packSlugs[packIndex]]!;
      final filteredImagePackImageEntried = pack.images.entries.toList();
      if (searchFilter?.isNotEmpty ?? false) {
        filteredImagePackImageEntried.removeWhere(
          (e) =>
              !(e.key.toLowerCase().contains(searchFilter!.toLowerCase()) ||
                  (e.value.body?.toLowerCase().contains(
                        searchFilter!.toLowerCase(),
                      ) ??
                      false)),
        );
      }
      final imageKeys = filteredImagePackImageEntried
          .map((e) => e.key)
          .toList();
      if (imageKeys.isEmpty) {
        return const SizedBox.shrink();
      }
      final packName = pack.pack.displayName ?? packSlugs[packIndex];
      return Column(
        children: <Widget>[
          if (packIndex != 0 || hasRecentStickers) const SizedBox(height: 20),
          if (packName != 'user')
            ListTile(
              leading: Avatar(
                mxContent: pack.pack.avatarUrl,
                name: packName,
                client: widget.room.client,
              ),
              title: Text(packName),
            ),
          const SizedBox(height: 6),
          GridView.builder(
            itemCount: imageKeys.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 84,
              mainAxisSpacing: 8.0,
              crossAxisSpacing: 8.0,
            ),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemBuilder: (BuildContext context, int imageIndex) {
              final image = pack.images[imageKeys[imageIndex]]!;
              return Tooltip(
                message: image.body ?? imageKeys[imageIndex],
                child: InkWell(
                  radius: AppConfig.borderRadius,
                  key: ValueKey(image.url.toString()),
                  onTap: () {
                    // copy the image
                    final imageCopy = ImagePackImageContent.fromJson(
                      image.toJson().copy(),
                    );
                    // set the body, if it doesn't exist, to the key
                    imageCopy.body ??= imageKeys[imageIndex];
                    _onStickerSelected(imageCopy);
                  },
                  onLongPress: () {
                    final stickerCopy = ImagePackImageContent.fromJson(
                      image.toJson().copy(),
                    );
                    stickerCopy.body ??= imageKeys[imageIndex];
                    _showStickerInfoDialog(
                      sticker: stickerCopy,
                      packName: pack.pack.displayName ?? packSlugs[packIndex],
                      packAttribution: pack.pack.attribution,
                    );
                  },
                  child: AbsorbPointer(
                    absorbing: true,
                    child: MxcImage(
                      uri: image.url,
                      fit: BoxFit.contain,
                      width: 128,
                      height: 128,
                      animated: true,
                      isThumbnail: false,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
    };

    return Scaffold(
      backgroundColor: theme.colorScheme.onInverseSurface,
      body: SizedBox(
        width: double.maxFinite,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              floating: true,
              pinned: true,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              title: SizedBox(
                height: 42,
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    filled: true,
                    hintText: L10n.of(context).search,
                    prefixIcon: const Icon(Icons.search_outlined),
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (s) => setState(() => searchFilter = s),
                ),
              ),
            ),
            if (hasRecentStickers)
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(L10n.of(context).recentStickers),
                    ),
                    const SizedBox(height: 6),
                    _buildStickerGrid(recentStickers, isFromRecents: true),
                  ],
                ),
              ),
            if (packSlugs.isEmpty && !hasRecentStickers)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Text(L10n.of(context).noEmotesFound)],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  packBuilder,
                  childCount: packSlugs.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
