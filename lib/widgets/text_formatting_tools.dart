import 'package:flutter/material.dart';
import 'inline_formatting.dart';

/// Visible controls for the website's existing portable inline text markers.
class TextFormattingTools extends StatefulWidget {
  const TextFormattingTools({super.key, required this.controller});
  final TextEditingController controller;

  @override
  State<TextFormattingTools> createState() => _TextFormattingToolsState();
}

class _TextFormattingToolsState extends State<TextFormattingTools> {
  bool _preview = false;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          final selected =
              value.selection.isValid &&
              !value.selection.isCollapsed &&
              value.selection.end <= value.text.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: selected
                        ? () => widget.controller.value = toggleInlineStyle(
                            widget.controller.value,
                            InlineStyle.bold,
                          )
                        : null,
                    icon: const Icon(Icons.format_bold),
                    label: const Text('Bold'),
                  ),
                  TextButton.icon(
                    onPressed: selected
                        ? () => widget.controller.value = toggleInlineStyle(
                            widget.controller.value,
                            InlineStyle.italic,
                          )
                        : null,
                    icon: const Icon(Icons.format_italic),
                    label: const Text('Italic'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _preview = !_preview),
                    icon: Icon(
                      _preview
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    label: Text(_preview ? 'Hide preview' : 'Preview text'),
                  ),
                ],
              ),
              Text(
                'Select words above, then tap Bold or Italic.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_preview)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: value.text.trim().isEmpty
                      ? const Text('Your formatted text will appear here.')
                      : FormattedText(value.text),
                ),
            ],
          );
        },
      );
}
