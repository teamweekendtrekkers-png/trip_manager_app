import 'package:flutter/material.dart';

/// Keeps long forms readable while preserving the full height for scrolling.
class ManagerPageBody extends StatelessWidget {
  const ManagerPageBody({super.key, required this.child, this.maxWidth = 1120});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Uses available content width and larger text settings, not device width.
class ManagerCardGrid extends StatelessWidget {
  const ManagerCardGrid({
    super.key,
    required this.children,
    this.minWidth = 240,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 12.0;
      final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
      final columns =
          ((constraints.maxWidth + gap) /
                  (minWidth * scale.clamp(1.0, 2.0) + gap))
              .floor()
              .clamp(1, maxColumns);
      return Column(
        children: [
          for (var start = 0; start < children.length; start += columns)
            Padding(
              padding: EdgeInsets.only(
                bottom: start + columns < children.length ? gap : 0,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: gap),
                      Expanded(
                        child: start + column < children.length
                            ? children[start + column]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class ManagerSectionPicker extends StatelessWidget {
  const ManagerSectionPicker({
    super.key,
    required this.sections,
    required this.selected,
    required this.onChanged,
  });

  final List<String> sections;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560 ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: const Key('homepage-section-picker'),
            initialValue: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Website section'),
            items: [
              for (final section in {...sections, selected})
                DropdownMenuItem(
                  value: section,
                  child: Text(section == 'All' ? 'All sections' : section),
                ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        );
      }
      return Wrap(
        spacing: 8,
        children: [
          for (final section in sections)
            ChoiceChip(
              key: ValueKey('homepage-group-$section'),
              label: Text(section),
              selected: selected == section,
              onSelected: (_) => onChanged(section),
            ),
        ],
      );
    },
  );
}
