import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/config/themes.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/pages/chat_list/chat_list.dart';
import 'package:extera_next/pages/chat_list/client_chooser_button.dart';
import 'package:extera_next/utils/sync_status_localization.dart';
import '../../widgets/matrix.dart';

class ChatListHeader extends StatelessWidget {
  final ChatListController controller;
  final bool globalSearch;

  const ChatListHeader({
    super.key,
    required this.controller,
    this.globalSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      floating: true,
      delegate: _ChatListHeaderDelegate(
        controller: controller,
        globalSearch: globalSearch,
        topPadding: MediaQuery.of(context).padding.top,
      ),
    );
  }
}

class _ChatListHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ChatListController controller;
  final bool globalSearch;
  final double topPadding;

  static const double _titleHeight = 56.0;
  static const double _searchBarHeight = 48.0; // 40 + 8 padding

  _ChatListHeaderDelegate({
    required this.controller,
    required this.globalSearch,
    required this.topPadding,
  });

  @override
  double get minExtent => _titleHeight + topPadding;

  @override
  double get maxExtent => _titleHeight + _searchBarHeight + topPadding;

  @override
  bool shouldRebuild(covariant _ChatListHeaderDelegate oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final client = Matrix.of(context).client;

    // 0.0 = fully collapsed, 1.0 = fully expanded
    final progress = controller.isSearchMode
        ? 1.0
        : (1.0 - (shrinkOffset / _searchBarHeight)).clamp(0.0, 1.0);

    return Material(
      elevation: shrinkOffset > 0 ? 4 : 0,
      surfaceTintColor: theme.colorScheme.surfaceTint,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Column(
          children: [
            SizedBox(
              height: _titleHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      AppConfig.applicationName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (progress == 0.0 && !controller.isSearchMode)
                      IconButton(
                        onPressed: () {
                          controller.scrollController.animateTo(
                            0,
                            duration: FluffyThemes.animationDuration,
                            curve: FluffyThemes.animationCurve,
                          );
                          controller.isSearchMode = true;
                          controller.searchFocusNode.requestFocus();
                        },
                        icon: const Icon(Icons.search),
                      ),
                    ClientChooserButton(controller),
                  ],
                ),
              ),
            ),

            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: progress,
                child: Opacity(
                  opacity: progress,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8,
                    ),
                    child: StreamBuilder(
                      stream: client.onSyncStatus.stream,
                      builder: (context, snapshot) {
                        final status =
                            client.onSyncStatus.value ??
                            const SyncStatusUpdate(
                              SyncStatus.waitingForResponse,
                            );
                        final hide =
                            client.onSync.value != null &&
                            status.status != SyncStatus.error &&
                            client.prevBatch != null;
                        return SizedBox(
                          height: 40,
                          child: TextField(
                            controller: controller.searchController,
                            focusNode: controller.searchFocusNode,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (text) => controller.onSearchEnter(
                              text,
                              globalSearch: false,
                            ),
                            onSubmitted: (text) => controller.onSearchEnter(
                              text,
                              globalSearch: globalSearch,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.colorScheme.secondaryContainer,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              hintText: hide
                                  ? L10n.of(context).searchChatsRooms
                                  : status.calcLocalizedString(context),
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: status.error != null
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.normal,
                              ),
                              prefixIcon: hide
                                  ? controller.isSearchMode
                                        ? IconButton(
                                            tooltip: L10n.of(context).cancel,
                                            icon: const Icon(
                                              Icons.close_outlined,
                                              size: 20,
                                            ),
                                            onPressed: controller.cancelSearch,
                                            color: theme
                                                .colorScheme
                                                .onSecondaryContainer,
                                          )
                                        : IconButton(
                                            onPressed: controller.startSearch,
                                            icon: Icon(
                                              Icons.search_outlined,
                                              size: 20,
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                            ),
                                          )
                                  : Container(
                                      margin: const EdgeInsets.all(8),
                                      width: 8,
                                      height: 8,
                                      child: Center(
                                        child:
                                            CircularProgressIndicator.adaptive(
                                              constraints: const .tightFor(
                                                width: 24,
                                                height: 32,
                                              ),
                                              strokeWidth: 2,
                                              value: status.progress,
                                              valueColor: status.error != null
                                                  ? AlwaysStoppedAnimation<
                                                      Color
                                                    >(theme.colorScheme.error)
                                                  : null,
                                            ),
                                      ),
                                    ),
                              suffixIcon:
                                  controller.isSearchMode && globalSearch
                                  ? controller.isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 8.0,
                                              horizontal: 10,
                                            ),
                                            child: SizedBox.square(
                                              dimension: 20,
                                              child:
                                                  CircularProgressIndicator.adaptive(
                                                    strokeWidth: 2,
                                                  ),
                                            ),
                                          )
                                        : TextButton.icon(
                                            onPressed: controller.setServer,
                                            style: TextButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              textStyle: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 14,
                                            ),
                                            label: Text(
                                              controller.searchServer ??
                                                  Matrix.of(
                                                    context,
                                                  ).client.homeserver!.host,
                                              maxLines: 2,
                                            ),
                                          )
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
