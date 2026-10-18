import 'package:flutter/material.dart';

/// Only call with live=true after the exact saved commit has deployed.
class PublishingProgress extends StatelessWidget {
  const PublishingProgress({super.key, required this.live, required this.running});
  final bool live, running;
  @override
  Widget build(BuildContext context) => Semantics(
    label: live ? 'Saved draft, published to GitHub, website live'
      : running ? 'Saved draft, publishing website' : 'Saved draft, website deployment not confirmed',
    child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      _stage(context, 'Draft saved', true),
      _stage(context, 'Publishing', running || live),
      _stage(context, 'Live', live),
    ]),
  );
  Widget _stage(BuildContext context, String text, bool complete) => Chip(
    avatar: Icon(complete ? Icons.check_circle_outline : Icons.radio_button_unchecked,
      size: 18, color: complete ? Theme.of(context).colorScheme.primary : null),
    label: Text(text),
  );
}
