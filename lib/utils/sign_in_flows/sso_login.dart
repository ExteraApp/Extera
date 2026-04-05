import 'package:flutter/material.dart' hide Intent;

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/utils/platform_infos.dart';
import 'package:extera_next/utils/sign_in_flows/calc_redirect_url.dart';
import 'package:extera_next/widgets/adaptive_dialogs/show_modal_action_popup.dart';

Future<void> ssoLoginFlow(
  Client client,
  BuildContext context,
  bool signUp,
  List<LoginFlow> loginFlows,
) async {
  final (redirectUrl, urlScheme) = calcRedirectUrl(withAuthHtmlPath: true);

  Logs().i('Starting legacy SSO Flow with redirect URL', redirectUrl);

  final ssoProviders =
      (loginFlows
                  .firstWhere((flow) => flow.type == 'm.login.sso')
                  .additionalProperties['identity_providers']
              as List?)
          ?.map(
            (json) => (
              name: json['name'] as String,
              id: json['id'] as String,
              brand: json['brand'] as String?,
              icon: json['icon'] as String?,
            ),
          )
          .toList();

  final provider = ssoProviders == null
      ? null
      : await showModalActionPopup(
          context: context,
          title: L10n.of(context).logInTo(client.homeserver!.host),
          actions: ssoProviders
              .map(
                (provider) =>
                    AdaptiveModalAction(label: provider.name, value: provider),
              )
              .toList(),
        );

  final url = client.homeserver!.replace(
    path:
        '/_matrix/client/v3/login/sso/redirect${provider == null ? '' : '/${provider.id}'}',
    queryParameters: {
      'redirectUrl': redirectUrl.toString(),
      'action': signUp ? 'register' : 'login',
    },
  );

  final result = await FlutterWebAuth2.authenticate(
    url: url.toString(),
    callbackUrlScheme: urlScheme,
    options: FlutterWebAuth2Options(
      useWebview: false,
      preferEphemeral: true,
      // intentFlags: ephemeralIntentFlags,
    ),
  );
  final token = Uri.parse(result).queryParameters['loginToken'];
  if (token?.isEmpty ?? false) return;

  await client.login(
    LoginType.mLoginToken,
    token: token,
    initialDeviceDisplayName: PlatformInfos.clientName,
  );
}
