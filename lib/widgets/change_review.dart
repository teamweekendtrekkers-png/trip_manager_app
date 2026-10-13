import 'package:flutter/material.dart';
import '../services/workspace_changes.dart';

class ChangeReview extends StatelessWidget {
  const ChangeReview({super.key, required this.changes});
  final List<FieldChange> changes;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (changes.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No content changes.'),
        ),
      for (final change in changes)
        ExpansionTile(
          title: Text(change.label),
          children: [
            _value(context, 'Before', change.before),
            _value(context, 'After', change.after),
          ],
        ),
    ],
  );
  Widget _value(BuildContext context, String label, Object? value) => Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        SelectableText(FieldChange.describe(value)),
      ],
    ),
  );
}
