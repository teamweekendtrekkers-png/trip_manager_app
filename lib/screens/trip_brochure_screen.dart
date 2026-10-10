import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/trip_brochure_service.dart';

class TripBrochureScreen extends StatefulWidget {
  const TripBrochureScreen({
    super.key,
    required this.brochure,
    this.generator,
    this.sharePdf,
  });
  final TripBrochure brochure;
  final Future<Uint8List> Function(TripBrochure brochure)? generator;
  final Future<void> Function(Uint8List bytes, String filename)? sharePdf;
  @override
  State<TripBrochureScreen> createState() => _TripBrochureScreenState();
}

class _TripBrochureScreenState extends State<TripBrochureScreen> {
  bool _busy = false;
  String? _error;
  Uint8List? _pdf;
  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _pdf ??= await (widget.generator ?? TripBrochurePdf.generate)(
        widget.brochure,
      );
      if (!mounted) return;
      if (widget.sharePdf != null) {
        await widget.sharePdf!(_pdf!, widget.brochure.filename);
      } else {
        final directory = await getTemporaryDirectory();
        final exportDirectory = await Directory(
          '${directory.path}/trip-brochures',
        ).create(recursive: true);
        final file = File(
          '${exportDirectory.path}/${widget.brochure.filename}',
        );
        await file.writeAsBytes(_pdf!, flush: true);
        if (!mounted) return;
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'application/pdf'),
        ], subject: widget.brochure.title);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not create or share the PDF. Your trip edits are unchanged. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trip Brochure')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Preview of your current trip draft. Sharing a PDF does not save or publish any trip changes. Use the Android share sheet to send or save it.',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              key: const Key('brochure-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_busy) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.brochure.blocks.length,
            itemBuilder: (context, index) {
              final block = widget.brochure.blocks[index];
              return Padding(
                padding: EdgeInsets.only(
                  top: block.kind == 'body' ? 6 : 16,
                  bottom: 4,
                ),
                child: Text(
                  block.text,
                  style: block.kind == 'title'
                      ? Theme.of(context).textTheme.headlineSmall
                      : block.kind == 'heading'
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              key: const Key('brochure-share'),
              onPressed: _busy ? null : _share,
              icon: const Icon(Icons.picture_as_pdf),
              label: Text(_busy ? 'Preparing PDF…' : 'Share / save PDF'),
            ),
          ),
        ),
      ],
    ),
  );
}
