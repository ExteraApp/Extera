import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:collection/collection.dart';
import 'package:highlight_selectable/highlight_selectable.dart';
import 'package:highlight_selectable/theme_map.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:latext/latext.dart';
import 'package:linkify/linkify.dart';
import 'package:matrix/matrix.dart';

import 'package:extera_next/config/setting_keys.dart';
import 'package:extera_next/generated/l10n/l10n.dart';
import 'package:extera_next/widgets/avatar.dart';
import 'package:extera_next/widgets/mxc_image.dart';
import '../../../utils/url_launcher.dart';

class HtmlMessage extends StatefulWidget {
  final String html;
  final Room room;
  final Color textColor;
  final double fontSize;
  final TextStyle linkStyle;

  final void Function(LinkableElement) onOpen;
  final void Function() onCopy;

  final bool selectable;

  const HtmlMessage({
    super.key,
    required this.html,
    required this.room,
    required this.fontSize,
    required this.linkStyle,
    this.textColor = Colors.black,
    required this.onOpen,
    required this.onCopy,
    this.selectable = false,
  });

  /// Keep in sync with: https://spec.matrix.org/latest/client-server-api/#mroommessage-msgtypes
  static const Set<String> allowedHtmlTags = {
    'font',
    'del',
    's',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'blockquote',
    'p',
    'a',
    'ul',
    'ol',
    'sup',
    'sub',
    'li',
    'b',
    'i',
    'u',
    'strong',
    'em',
    'strike',
    'code',
    'hr',
    'br',
    'div',
    'table',
    'thead',
    'tbody',
    'tr',
    'th',
    'td',
    'caption',
    'pre',
    'span',
    'img',
    'details',
    'summary',
    // Not in the allowlist of the matrix spec yet but should be harmless:
    'ruby',
    'rp',
    'rt',
    'html',
    'body',
    // tg-forward will be rendered without formatting otherwise
    'tg-forward',
  };

  static const Set<String> ignoredHtmlTags = {'mx-reply'};

  /// We add line breaks before these tags:
  static const Set<String> blockHtmlTags = {
    'p',
    'ul',
    'ol',
    'pre',
    'div',
    'table',
    'details',
    'blockquote',
  };

  /// We add line breaks before these tags:
  static const Set<String> fullLineHtmlTag = {
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
  };

  @override
  State<HtmlMessage> createState() => _HtmlMessageState();
}

class _HtmlMessageState extends State<HtmlMessage> {
  /// Tracks the open/closed state of \<details> elements by their index.
  final Map<int, bool> _detailsOpenState = {};

  /// Tracks the revealed/hidden state of spoiler <span> elements by their index.
  final Map<int, bool> _spoilerRevealedState = {};

  /// Counter used during rendering to assign stable indices to \<details> elements.
  int _detailsCounter = 0;

  /// Counter used during rendering to assign stable indices to spoiler elements.
  int _spoilerCounter = 0;

  // Convenience accessors for widget properties
  String get html => widget.html;
  Room get room => widget.room;
  Color get textColor => widget.textColor;
  double get fontSize => widget.fontSize;
  TextStyle get linkStyle => widget.linkStyle;
  void Function(LinkableElement) get onOpen => widget.onOpen;

  // to fix issue 7
  TextSpan _buildLinkifySpan(
    BuildContext context, {
    required String text,
    LinkifyOptions options = const LinkifyOptions(humanize: false),
  }) {
    final elements = linkify(text, options: options);
    return TextSpan(
      children: elements.map((element) {
        if (element is LinkableElement) {
          return WidgetSpan(
            child: GestureDetector(
              onTap: () => onOpen(element),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: element.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.of(context).copiedToClipboard)),
                );
              },
              child: Text(element.text, style: linkStyle),
            ),
          );
        } else {
          return TextSpan(text: element.text);
        }
      }).toList(),
    );
  }

  List<InlineSpan> _renderWithLineBreaks(
    dom.NodeList nodes,
    BuildContext context, {
    int depth = 1,
    bool insideAnchor = false,
  }) {
    final onlyElements = nodes.whereType<dom.Element>().toList();
    return [
      for (var i = 0; i < nodes.length; i++) ...[
        // Actually render the node child:
        _renderHtml(
          nodes[i],
          context,
          depth: depth + 1,
          insideAnchor: insideAnchor,
        ),
        // Add linebreaks between blocks:
        if (nodes[i] is dom.Element &&
            onlyElements.indexOf(nodes[i] as dom.Element) <
                onlyElements.length - 1) ...[
          if (HtmlMessage.blockHtmlTags.contains(
            (nodes[i] as dom.Element).localName,
          ))
            const TextSpan(text: '\n\n'),
          if (HtmlMessage.fullLineHtmlTag.contains(
            (nodes[i] as dom.Element).localName,
          ))
            const TextSpan(text: '\n'),
        ],
      ],
    ];
  }

  InlineSpan _renderHtml(
    dom.Node node,
    BuildContext context, {
    int depth = 1,
    bool insideAnchor = false,
  }) {
    if (depth >= 100) return const TextSpan();

    if (node is dom.Element &&
        HtmlMessage.ignoredHtmlTags.contains(node.localName)) {
      return const TextSpan();
    }

    if (node is! dom.Element ||
        !HtmlMessage.allowedHtmlTags.contains(node.localName)) {
      var text = node.text ?? '';

      // Whitespace-only text nodes inside block containers (ul, ol, li, etc.)
      // are just HTML formatting artifacts and should not be rendered.
      final parentTag = node.parent?.localName;
      if (const {
            'ul',
            'ol',
            'li',
            'table',
            'thead',
            'tbody',
            'tr',
          }.contains(parentTag) &&
          text.trim().isEmpty) {
        return const TextSpan();
      }

      text = text.replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty) return const TextSpan();

      return insideAnchor
          ? TextSpan(text: text)
          : _buildLinkifySpan(context, text: text);
    }

    switch (node.localName) {
      case 'br':
        return const TextSpan(text: '\n');
      case 'a':
        final href = node.attributes['href'];
        if (href == null) continue block;
        final matrixId = node.attributes['href']
            ?.parseIdentifierIntoParts()
            ?.primaryIdentifier;
        if (matrixId != null) {
          if (matrixId.sigil == '@') {
            final user = room.unsafeGetUserFromMemoryOrFallback(matrixId);
            return WidgetSpan(
              child: MatrixPill(
                key: Key('user_pill_$matrixId'),
                name: user.calcDisplayname(),
                avatar: user.avatarUrl,
                uri: href,
                outerContext: context,
                fontSize: fontSize,
                color: linkStyle.color,
              ),
            );
          }
          if (matrixId.sigil == '#' || matrixId.sigil == '!') {
            final room = matrixId.sigil == '!'
                ? this.room.client.getRoomById(matrixId)
                : this.room.client.getRoomByAlias(matrixId);
            return WidgetSpan(
              child: MatrixPill(
                name: room?.getLocalizedDisplayname() ?? matrixId,
                avatar: room?.avatar,
                uri: href,
                outerContext: context,
                fontSize: fontSize,
                color: linkStyle.color,
              ),
            );
          }
        }
        return WidgetSpan(
          child: Tooltip(
            message: href,
            child: InkWell(
              splashColor: Colors.transparent,
              onTap: () => UrlLauncher(context, href, node.text).launchUrl(),
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: href));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.of(context).copiedToClipboard)),
                );
              },
              child: Text.rich(
                TextSpan(
                  children: _renderWithLineBreaks(
                    node.nodes,
                    context,
                    depth: depth,
                    insideAnchor: true,
                  ),
                  style: linkStyle,
                ),
                style: const TextStyle(height: 1.25),
              ),
            ),
          ),
        );
      case 'li':
        if (!{'ol', 'ul'}.contains(node.parent?.localName)) {
          continue block;
        }
        return WidgetSpan(
          child: Padding(
            padding: EdgeInsets.only(left: fontSize),
            child: Text.rich(
              TextSpan(
                children: [
                  if (node.parent?.localName == 'ul')
                    const TextSpan(text: '• '),
                  if (node.parent?.localName == 'ol')
                    TextSpan(
                      text:
                          '${(node.parent?.nodes.whereType<dom.Element>().toList().indexOf(node) ?? 0) + (int.tryParse(node.parent?.attributes['start'] ?? '1') ?? 1)}. ',
                    ),
                  ..._renderWithLineBreaks(node.nodes, context, depth: depth),
                ],
                style: TextStyle(fontSize: fontSize, color: textColor),
              ),
            ),
          ),
        );
      case 'blockquote':
        return WidgetSpan(
          child: Container(
            padding: const EdgeInsets.only(left: 8.0),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: textColor, width: 5)),
            ),
            child: Text.rich(
              TextSpan(
                children: _renderWithLineBreaks(
                  node.nodes,
                  context,
                  depth: depth,
                ),
              ),
              style: TextStyle(fontSize: fontSize, color: textColor),
            ),
          ),
        );
      case 'code':
        final isInline = node.parent?.localName != 'pre';
        return isInline
            ? TextSpan(
                text: node.text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontFamily: 'RobotoMono',
                  backgroundColor: const Color(0xff2d2b57),
                  color: const Color(0xffe3dfff),
                ),
              )
            : WidgetSpan(
                child: HighlightSelectable(
                  node.text,
                  language:
                      node.className
                          .split(' ')
                          .singleWhereOrNull(
                            (className) => className.startsWith('language-'),
                          )
                          ?.split('language-')
                          .last ??
                      'md',
                  theme: themeMap['shades-of-purple']!,
                  selectable: true,
                  showCopyButton: !isInline,
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: isInline ? 0 : 8,
                  ),
                  textStyle: TextStyle(
                    fontSize: fontSize,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              );
      case 'img':
        final mxcUrl = Uri.tryParse(node.attributes['src'] ?? '');
        if (mxcUrl == null || mxcUrl.scheme != 'mxc') {
          return TextSpan(text: node.attributes['alt']);
        }

        final width = double.tryParse(node.attributes['width'] ?? '');
        final height = double.tryParse(node.attributes['height'] ?? '');
        const defaultDimension = 64.0;
        final actualWidth = width ?? height ?? defaultDimension;
        final actualHeight = height ?? width ?? defaultDimension;

        return WidgetSpan(
          child: SizedBox(
            width: actualWidth,
            height: actualHeight,
            child: MxcImage(
              uri: mxcUrl,
              width: actualWidth,
              height: actualHeight,
              isThumbnail: (actualWidth * actualHeight) > (256 * 256),
            ),
          ),
        );
      case 'hr':
        return const WidgetSpan(child: Divider());
      case 'details':
        final index = _detailsCounter++;
        final isOpen = _detailsOpenState[index] ?? false;
        return WidgetSpan(
          child: InkWell(
            splashColor: Colors.transparent,
            onTap: () => setState(() {
              _detailsOpenState[index] = !isOpen;
            }),
            child: Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    child: Icon(
                      isOpen ? Icons.arrow_drop_down : Icons.arrow_right,
                      size: fontSize * 1.2,
                      color: textColor,
                    ),
                  ),
                  if (!isOpen)
                    ...node.nodes
                        .where(
                          (node) =>
                              node is dom.Element &&
                              node.localName == 'summary',
                        )
                        .map((node) => _renderHtml(node, context, depth: depth))
                  else
                    ..._renderWithLineBreaks(node.nodes, context, depth: depth),
                ],
              ),
              style: TextStyle(fontSize: fontSize, color: textColor),
            ),
          ),
        );
      case 'div':
        if (node.attributes.containsKey('data-mx-maths') &&
            AppSettings.latexMath.value) {
          final maths = node.attributes['data-mx-maths']!;
          return WidgetSpan(
            child: InkWell(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: maths));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.of(context).copiedToClipboard)),
                );
              },
              child: LatexSpan(
                math: maths,
                fontSize: fontSize,
                color: textColor,
              ),
            ),
          );
        } else {
          continue block;
        }
      case 'span':
        if (node.attributes.containsKey('data-mx-maths') &&
            AppSettings.latexMath.value) {
          final maths = node.attributes['data-mx-maths']!;
          return WidgetSpan(
            child: InkWell(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: maths));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.of(context).copiedToClipboard)),
                );
              },
              child: LatexSpan(
                math: maths,
                fontSize: fontSize,
                color: textColor,
              ),
            ),
          );
        }
        if (!node.attributes.containsKey('data-mx-spoiler')) {
          continue block;
        }
        final index = _spoilerCounter++;
        final isRevealed = _spoilerRevealedState[index] ?? false;
        return WidgetSpan(
          child: InkWell(
            splashColor: Colors.transparent,
            onTap: () => setState(() {
              _spoilerRevealedState[index] = !isRevealed;
            }),
            child: Text.rich(
              TextSpan(
                children: _renderWithLineBreaks(
                  node.nodes,
                  context,
                  depth: depth,
                ),
              ),
              style: TextStyle(
                fontSize: fontSize,
                color: textColor,
                backgroundColor: isRevealed ? null : textColor,
              ),
            ),
          ),
        );
      block:
      default:
        return TextSpan(
          style: switch (node.localName) {
            'body' => TextStyle(fontSize: fontSize, color: textColor),
            'a' => linkStyle,
            'strong' => const TextStyle(fontWeight: FontWeight.bold),
            'em' || 'i' => const TextStyle(fontStyle: FontStyle.italic),
            'del' || 's' || 'strikethrough' => TextStyle(
              decoration: TextDecoration.lineThrough,
              decorationColor: textColor,
            ),
            'u' => const TextStyle(decoration: TextDecoration.underline),
            'h1' => TextStyle(fontSize: fontSize * 1.6, height: 2),
            'h2' => TextStyle(fontSize: fontSize * 1.5, height: 2),
            'h3' => TextStyle(fontSize: fontSize * 1.4, height: 2),
            'h4' => TextStyle(fontSize: fontSize * 1.3, height: 1.75),
            'h5' => TextStyle(fontSize: fontSize * 1.2, height: 1.75),
            'h6' => TextStyle(fontSize: fontSize * 1.1, height: 1.5),
            'span' => TextStyle(
              color:
                  node.attributes['color']?.hexToColor ??
                  node.attributes['data-mx-color']?.hexToColor ??
                  textColor,
              backgroundColor: node.attributes['data-mx-bg-color']?.hexToColor,
            ),
            'sup' => const TextStyle(
              fontFeatures: [FontFeature.superscripts()],
            ),
            'sub' => const TextStyle(fontFeatures: [FontFeature.subscripts()]),
            _ => null,
          },
          children: _renderWithLineBreaks(node.nodes, context, depth: depth),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reset counters before each build so indices are assigned consistently.
    _detailsCounter = 0;
    _spoilerCounter = 0;

    final textSpan = _renderHtml(
      parser.parse(html).body ?? dom.Element.html(''),
      context,
    );
    final textStyle = TextStyle(fontSize: fontSize, color: textColor);

    if (widget.selectable) {
      return SelectionArea(child: Text.rich(textSpan, style: textStyle));
    }

    return Text.rich(textSpan, style: textStyle);
  }
}

class MatrixPill extends StatelessWidget {
  final String name;
  final BuildContext outerContext;
  final Uri? avatar;
  final String uri;
  final double? fontSize;
  final Color? color;

  const MatrixPill({
    super.key,
    required this.name,
    required this.outerContext,
    this.avatar,
    required this.uri,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      onTap: UrlLauncher(outerContext, uri).launchUrl,
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              child: Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Avatar(mxContent: avatar, name: name, size: 16),
              ),
            ),
            TextSpan(
              text: name,
              style: TextStyle(
                color: color,
                decorationColor: color,
                decoration: TextDecoration.underline,
                fontSize: fontSize,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LatexSpan extends StatelessWidget {
  final Color color;
  final double fontSize;
  final String math;

  const LatexSpan({
    required this.math,
    required this.fontSize,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LaTexT(
      laTeXCode: Text(
        '\$$math\$',
        style: TextStyle(color: color, fontSize: fontSize),
      ),
      onErrorFallback: (text) {
        return "$text (LaTeX Error)";
      },
    );
  }
}

extension on String {
  Color? get hexToColor {
    var hexCode = this;
    if (hexCode.startsWith('#')) hexCode = hexCode.substring(1);
    if (hexCode.length == 6) hexCode = 'FF$hexCode';
    final colorValue = int.tryParse(hexCode, radix: 16);
    return colorValue == null ? null : Color(colorValue);
  }
}
