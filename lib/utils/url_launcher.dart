import 'package:flutter/material.dart';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:punycode/punycode.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:extera_next/config/app_config.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/show_profile.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:extera_next/widgets/future_loading_dialog.dart';
import 'package:extera_next/widgets/matrix.dart';
import '../widgets/adaptive_dialogs/public_room_dialog.dart';
import 'platform_infos.dart';

class UrlLauncher {
  /// The url to open.
  final String? url;

  /// The visible name in the GUI. For example the name of a markdown link
  /// which may differ from the actual url to open.
  final String? name;

  final BuildContext context;

  const UrlLauncher(this.context, this.url, [this.name]);

  void launchUrl() async {
    if (url!.toLowerCase().startsWith(AppConfig.schemePrefix)) {
      return openMatrixUrl();
    }
    if (url!.toLowerCase().startsWith(AppConfig.deepLinkPrefix) ||
        url!.toLowerCase().startsWith(AppConfig.inviteLinkPrefix) ||
        {'#', '@', '!', '+', '\$'}.contains(url![0])) {
      return openMatrixToUrl();
    }
    final uri = Uri.tryParse(url!);
    if (uri == null) {
      // we can't open this thing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).cantOpenUri(url!))),
      );
      return;
    }

    //if (name != null && url != name) {
    // If there is a name which differs from the url, we need to make sure
    // that the user can see the actual url before opening the browser.
    final consent = await showOkCancelAlertDialog(
      context: context,
      title: L10n.of(context).openLinkInBrowser,
      message: url,
      okLabel: L10n.of(context).open,
      cancelLabel: L10n.of(context).cancel,
    );
    if (consent != OkCancelResult.ok) return;
    //}

    if (!{'https', 'http'}.contains(uri.scheme)) {
      // just launch non-https / non-http uris directly

      // we need to transmute geo URIs on desktop and on iOS
      if ((!PlatformInfos.isMobile || PlatformInfos.isIOS) &&
          uri.scheme == 'geo') {
        final latlong = uri.path
            .split(';')
            .first
            .split(',')
            .map((s) => double.tryParse(s))
            .toList();
        if (latlong.length == 2 &&
            latlong.first != null &&
            latlong.last != null) {
          if (PlatformInfos.isIOS) {
            // iOS is great at not following standards, so we need to transmute the geo URI
            // to an apple maps thingy
            // https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html
            final ll = '${latlong.first},${latlong.last}';
            launchUrlString('https://maps.apple.com/?q=$ll&sll=$ll');
          } else {
            // transmute geo URIs on desktop to openstreetmap links, as those usually can't handle
            // geo URIs
            launchUrlString(
              'https://www.openstreetmap.org/?mlat=${latlong.first}&mlon=${latlong.last}#map=16/${latlong.first}/${latlong.last}',
            );
          }
          return;
        }
      }
      launchUrlString(url!);
      return;
    }
    if (uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).cantOpenUri(url!))),
      );
      return;
    }
    // okay, we have either an http or an https URI.
    // As some platforms have issues with opening unicode URLs, we are going to help
    // them out by punycode-encoding them for them ourself.
    final newHost = uri.host
        .split('.')
        .map((hostPartEncoded) {
          final hostPart = Uri.decodeComponent(hostPartEncoded);
          final hostPartPunycode = punycodeEncode(hostPart);
          return hostPartPunycode != '$hostPart-'
              ? 'xn--$hostPartPunycode'
              : hostPart;
        })
        .join('.');
    // Force LaunchMode.externalApplication, otherwise url_launcher will default
    // to opening links in a webview on mobile platforms.
    launchUrlString(
      url!.replaceFirst(uri.host, newHost),
      mode: LaunchMode.externalApplication,
    );
  }

  void openMatrixUrl() async {
    final matrix = Matrix.of(context);
    final rawUrl = url;
    if (rawUrl == null) return;

    // 1. Parse the URI into components
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    // 2. Verify scheme is 'matrix'
    if (uri.scheme.toLowerCase() != 'matrix') return;

    // 3. Split the path into segments separated by '/'
    // Uri.pathSegments already handles this, but for matrix: URIs
    // we need to handle the path manually since Dart's Uri parser
    // may treat the first path segment as authority for some forms.
    // We'll use the raw path from the URI.
    var path = uri.path;
    // Remove leading slash if present (from authority form matrix://authority/path)
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    final segments = path.split('/');

    // 4. Check that the URI contains either 2 or 4 segments
    if (segments.length != 2 && segments.length != 4) return;

    // 5. Construct the top-level (primary) Matrix identifier
    final typeSpecifier = segments[0].toLowerCase();
    String sigil;
    switch (typeSpecifier) {
      case 'u':
      case 'user': // deprecated
        sigil = '@';
        break;
      case 'r':
      case 'room': // deprecated
        sigil = '#';
        break;
      case 'roomid':
        sigil = '!';
        break;
      default:
        return; // invalid type specifier
    }

    final idWithoutSigil1 = Uri.decodeComponent(segments[1]);
    if (idWithoutSigil1.isEmpty) return;
    final primaryId = '$sigil$idWithoutSigil1';

    // 6. If we have 4 segments and the primary is a room (! or #),
    //    try to construct a secondary (event) identifier
    String? eventId;
    if (segments.length == 4 && (sigil == '!' || sigil == '#')) {
      final secondTypeSpecifier = segments[2].toLowerCase();
      if (secondTypeSpecifier != 'e' && secondTypeSpecifier != 'event') {
        return; // invalid second-level type specifier
      }
      final idWithoutSigil2 = Uri.decodeComponent(segments[3]);
      if (idWithoutSigil2.isEmpty) return;
      eventId = '\$$idWithoutSigil2';
    } else if (segments.length == 4) {
      // 4 segments but primary is not a room - invalid
      return;
    }

    // 7. Parse query parameters
    String? action;
    final servers = <String>{};
    for (final entry in uri.queryParametersAll.entries) {
      switch (entry.key) {
        case 'action':
          // Use the last action= value as per spec
          if (entry.value.isNotEmpty) {
            action = entry.value.last;
          }
          break;
        case 'via':
          servers.addAll(entry.value);
          break;
      }
    }

    // Now handle the parsed URI based on sigil type
    if (sigil == '@') {
      // User identifier
      if (action == 'chat') {
        // Open or create a direct chat with this user
        final userId = primaryId;
        final client = matrix.client;
        final roomId = client.getDirectChatFromUserId(userId);
        if (roomId != null) {
          context.go('/rooms/$roomId');
          return;
        } // Do not create DM
      }
      // Default: show user profile
      final userId = primaryId;
      var noProfileWarning = false;
      final profileResult = await showFutureLoadingDialog(
        context: context,
        future: () =>
            matrix.client.getProfileFromUserId(userId).catchError((_) {
              noProfileWarning = true;
              return Profile(userId: userId);
            }),
      );
      if (profileResult.result == null) return;
      showProfile(
        context: context,
        profile: profileResult.result!,
        noProfileWarning: noProfileWarning,
      );
    } else if (sigil == '#' || sigil == '!') {
      // Room alias or room ID
      final roomIdOrAlias = primaryId;
      var room =
          matrix.client.getRoomByAlias(roomIdOrAlias) ??
          matrix.client.getRoomById(roomIdOrAlias);
      var roomId = room?.id;

      if (room == null && sigil == '#') {
        // Resolve alias
        final response = await showFutureLoadingDialog(
          context: context,
          future: () => matrix.client.getRoomIdByAlias(roomIdOrAlias),
        );
        final result = response.result;
        if (result != null) {
          roomId = result.roomId;
          servers.addAll(result.servers ?? []);
          room = matrix.client.getRoomById(roomId!);
        }
      }

      if (action == 'join') {
        if (room != null && room.membership == Membership.join) {
          // Already joined, just open
          _navigateToRoom(room.id, eventId);
        } else {
          // Ask for confirmation before joining
          if (await showOkCancelAlertDialog(
                useRootNavigator: false,
                context: context,
                title: L10n.of(
                  context,
                ).joinRoomByLinkConfirmation(roomIdOrAlias),
              ) ==
              OkCancelResult.ok) {
            final joinId = roomId ?? roomIdOrAlias;
            final response = await showFutureLoadingDialog(
              context: context,
              future: () => matrix.client.joinRoom(
                joinId,
                serverName: servers.isNotEmpty ? servers.toList() : null,
              ),
            );
            if (response.error != null) return;
            // Wait for sync
            await showFutureLoadingDialog(
              context: context,
              future: () => Future.delayed(const Duration(seconds: 2)),
            );
            _navigateToRoom(response.result!, eventId);
          }
        }
      } else {
        // Default: open the room
        if (room != null) {
          if (room.isSpace) {
            context.go('/rooms/${room.id}');
            return;
          }
          _navigateToRoom(room.id, eventId);
        } else {
          // Room not found locally - show public room dialog or offer to join
          if (sigil == '#') {
            await showAdaptiveDialog(
              context: context,
              useRootNavigator: false,
              builder: (c) => PublicRoomDialog(roomAlias: roomIdOrAlias),
            );
          } else {
            // Room ID not found locally, offer to join
            if (await showOkCancelAlertDialog(
                  useRootNavigator: false,
                  context: context,
                  title: L10n.of(
                    context,
                  ).joinRoomByLinkConfirmation(roomIdOrAlias),
                ) ==
                OkCancelResult.ok) {
              final response = await showFutureLoadingDialog(
                context: context,
                future: () => matrix.client.joinRoom(
                  roomIdOrAlias,
                  serverName: servers.isNotEmpty ? servers.toList() : null,
                ),
              );
              if (response.error != null) return;
              await showFutureLoadingDialog(
                context: context,
                future: () => Future.delayed(const Duration(seconds: 2)),
              );
              _navigateToRoom(response.result!, eventId);
            }
          }
        }
      }
    }
  }

  void _navigateToRoom(String roomId, String? eventId) {
    if (eventId != null) {
      context.go(
        Uri(
          pathSegments: ['', 'rooms', roomId],
          queryParameters: {'event': eventId},
        ).toString(),
      );
    } else {
      context.go('/rooms/$roomId');
    }
  }

  void openMatrixToUrl() async {
    final matrix = Matrix.of(context);
    final url = this.url!.replaceFirst(
      AppConfig.deepLinkPrefix,
      AppConfig.inviteLinkPrefix,
    );

    // The identifier might be a matrix.to url and needs escaping. Or, it might have multiple
    // identifiers (room id & event id), or it might also have a query part.
    // All this needs parsing.
    final identityParts =
        url.parseIdentifierIntoParts() ??
        Uri.tryParse(url)?.host.parseIdentifierIntoParts() ??
        Uri.tryParse(url)?.pathSegments
            .lastWhereOrNull((_) => true)
            ?.parseIdentifierIntoParts();
    if (identityParts == null) {
      return; // no match, nothing to do
    }
    if (identityParts.primaryIdentifier.sigil == '#' ||
        identityParts.primaryIdentifier.sigil == '!') {
      // we got a room! Let's open that one
      final roomIdOrAlias = identityParts.primaryIdentifier;
      final event = identityParts.secondaryIdentifier;
      var room =
          matrix.client.getRoomByAlias(roomIdOrAlias) ??
          matrix.client.getRoomById(roomIdOrAlias);
      var roomId = room?.id;
      // we make the servers a set and later on convert to a list, so that we can easily
      // deduplicate servers added via alias lookup and query parameter
      final servers = <String>{};
      if (room == null && roomIdOrAlias.sigil == '#') {
        // we were unable to find the room locally...so resolve it
        final response = await showFutureLoadingDialog(
          context: context,
          future: () => matrix.client.getRoomIdByAlias(roomIdOrAlias),
        );
        final result = response.result;
        if (result != null) {
          roomId = result.roomId;
          servers.addAll(result.servers!);
          room = matrix.client.getRoomById(roomId!);
        }
      }
      servers.addAll(identityParts.via);
      if (room != null) {
        if (room.isSpace) {
          // TODO: Implement navigate to space
          context.go('/rooms/${room.id}');

          return;
        }
        // we have the room, so....just open it
        if (event != null) {
          context.go(
            '/${Uri(pathSegments: ['rooms', room.id], queryParameters: {'event': event})}',
          );
        } else {
          context.go('/rooms/${room.id}');
        }
        return;
      } else {
        await showAdaptiveDialog(
          context: context,
          useRootNavigator: false,
          builder: (c) =>
              PublicRoomDialog(roomAlias: identityParts.primaryIdentifier),
        );
      }
      if (roomIdOrAlias.sigil == '!') {
        if (await showOkCancelAlertDialog(
              useRootNavigator: false,
              context: context,
              title: 'Join room $roomIdOrAlias',
            ) ==
            OkCancelResult.ok) {
          roomId = roomIdOrAlias;
          final response = await showFutureLoadingDialog(
            context: context,
            future: () => matrix.client.joinRoom(
              roomIdOrAlias,
              serverName: servers.isNotEmpty ? servers.toList() : null,
            ),
          );
          if (response.error != null) return;
          // wait for two seconds so that it probably came down /sync
          await showFutureLoadingDialog(
            context: context,
            future: () => Future.delayed(const Duration(seconds: 2)),
          );
          if (event != null) {
            context.go(
              Uri(
                pathSegments: ['rooms', response.result!],
                queryParameters: {'event': event},
              ).toString(),
            );
          } else {
            context.go('/rooms/${response.result!}');
          }
        }
      }
    } else if (identityParts.primaryIdentifier.sigil == '@') {
      final userId = identityParts.primaryIdentifier;
      var noProfileWarning = false;
      final profileResult = await showFutureLoadingDialog(
        context: context,
        future: () =>
            matrix.client.getProfileFromUserId(userId).catchError((_) {
              noProfileWarning = true;
              return Profile(userId: userId);
            }),
      );
      showProfile(
        context: context,
        profile: profileResult.result!,
        noProfileWarning: noProfileWarning,
      );
    }
  }
}
