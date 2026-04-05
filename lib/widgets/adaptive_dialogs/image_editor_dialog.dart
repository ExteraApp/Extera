import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MaterialYouEditor extends StatefulWidget {
  /// Creates a new [MaterialYouEditor] widget.
  const MaterialYouEditor({
    super.key,
    required this.byteArray,
    required this.onImageEditingComplete,
  });

  /// The URL of the image to display.
  final Uint8List byteArray;
  final Future<void> Function(Uint8List) onImageEditingComplete;

  @override
  State<MaterialYouEditor> createState() => _MaterialYouEditorState();
}

class _MaterialYouEditorState extends State<MaterialYouEditor> {
  /// Calculates the number of columns for the EmojiPicker.
  int _calculateEmojiColumns(BoxConstraints constraints) =>
      max(1, 6 / 400 * constraints.maxWidth - 1).floor();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ProImageEditor.memory(
          widget.byteArray,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: widget.onImageEditingComplete,
          ),
          configs: ProImageEditorConfigs(
            designMode: ImageEditorDesignMode.material,
            theme: Theme.of(context),
            paintEditor: PaintEditorConfigs(
              style: const PaintEditorStyle(initialStrokeWidth: 5),
            ),
            textEditor: TextEditorConfigs(
              customTextStyles: [
                GoogleFonts.roboto(),
                GoogleFonts.averiaLibre(),
                GoogleFonts.lato(),
                GoogleFonts.comicNeue(),
                GoogleFonts.actor(),
                GoogleFonts.odorMeanChey(),
                GoogleFonts.nabla(),
              ],
            ),
            cropRotateEditor: const CropRotateEditorConfigs(),
            filterEditor: const FilterEditorConfigs(
              style: FilterEditorStyle(
                filterListSpacing: 7,
                filterListMargin: EdgeInsets.fromLTRB(8, 15, 8, 10),
              ),
            ),
            tuneEditor: const TuneEditorConfigs(),
            blurEditor: const BlurEditorConfigs(),
            emojiEditor: EmojiEditorConfigs(
              checkPlatformCompatibility: !kIsWeb,
              style: EmojiEditorStyle(
                emojiViewConfig: EmojiViewConfig(
                  gridPadding: EdgeInsets.zero,
                  horizontalSpacing: 0,
                  verticalSpacing: 0,
                  recentsLimit: 40,
                  buttonMode: ButtonMode.MATERIAL,
                  loadingIndicator: const Center(
                    child: CircularProgressIndicator(),
                  ),
                  columns: _calculateEmojiColumns(constraints),
                  emojiSizeMax: 64,
                  replaceEmojiOnLimitExceed: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<Uint8List?> showImageEditor({
  required BuildContext context,
  required Uint8List byteArray,
}) {
  return showAdaptiveDialog<Uint8List>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return MaterialYouEditor(
        byteArray: byteArray,
        onImageEditingComplete: (bytes) async {
          Navigator.of(context).pop<Uint8List>(bytes);
        },
      );
    },
  );
}
