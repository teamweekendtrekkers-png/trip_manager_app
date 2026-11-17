import 'package:flutter/material.dart';

class GoogleReviewControls extends StatefulWidget {
  const GoogleReviewControls({
    super.key,
    required this.section,
    required this.onChanged,
    this.loadFeed,
  });
  final Map section;
  final VoidCallback onChanged;
  final Future<Map<String, dynamic>> Function()? loadFeed;
  @override
  State<GoogleReviewControls> createState() => _GoogleReviewControlsState();
}

class _GoogleReviewControlsState extends State<GoogleReviewControls> {
  bool busy = false;
  String? status;
  Future<void> check() async {
    setState(() {
      busy = true;
      status = null;
    });
    try {
      final result = await widget.loadFeed!();
      if (!mounted) return;
      setState(
        () => status = result['connected'] == true
            ? 'Google is connected. The website refreshes its latest five-star reviews automatically (up to every 15 minutes).'
            : 'Google is not connected yet. Your selected manual reviews will continue to appear until setup is complete.',
      );
    } catch (_) {
      if (mounted)
        setState(
          () => status =
              'Could not check Google right now. Your selected manual reviews remain available.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('google-review-source-${widget.section['source']}'),
          initialValue: widget.section['source'] == 'google'
              ? 'google'
              : 'manual',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Review display mode',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'manual', child: Text('Manual selection')),
            DropdownMenuItem(
              value: 'google',
              child: Text('Automatic five-star reviews'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              widget.section['source'] = value;
              widget.onChanged();
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          widget.section['source'] == 'google'
              ? 'Show the five most recently updated five-star Google reviews. Your manual selections below remain the fallback if Google cannot be reached.'
              : 'Choose exactly which reviews appear using Show review below. Switch to automatic mode whenever you prefer.',
        ),
        if (widget.loadFeed != null) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : check,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(busy ? 'Checking Google…' : 'Check Google connection'),
          ),
        ],
        if (status != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(status!),
            ),
          ),
      ],
    ),
  );
}
