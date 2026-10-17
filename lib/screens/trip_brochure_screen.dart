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
  final List<Uint8List> _pages = [];
  bool _showPages = false;
  Future<Uint8List> _prepare() async {
    if (_pdf != null) return _pdf!;
    _pages.clear();
    final bytes = widget.generator != null
        ? await widget.generator!(widget.brochure)
        : await TripBrochurePdf.generate(widget.brochure, onPageRendered: (image, _) {
            if (!mounted) throw StateError('Preview closed.');
            _pages.add(image);
          });
    _pdf = bytes;
    return bytes;
  }
  Future<void> _preview() async {
    if (_busy) return;
    if (_showPages) { setState(() => _showPages = false); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await _prepare();
      if (mounted) setState(() => _showPages = _pages.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not prepare the PDF preview. Please try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _share() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _prepare();
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Your current trip draft, ready to keep or share. Preview the PDF pages before sending. Trip edits are published separately.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            key: const Key('brochure-preview-pages'),
            onPressed: _busy ? null : _preview,
            icon: Icon(_showPages ? Icons.subject : Icons.preview_outlined),
            label: Text(_showPages ? 'Read trip details' : 'Preview PDF pages'),
          ),
        ),
        if (_pdf != null && !_busy)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('${_pages.isEmpty ? 'PDF ready' : '${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}'} · ${(_pdf!.length / 1024).ceil()} KB${_showPages ? ' · Pinch to zoom' : ''}',
              key: const Key('brochure-ready')),
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
          child: _showPages ? ListView.builder(
            key: const Key('brochure-page-list'),
            padding: const EdgeInsets.all(16),
            itemCount: _pages.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(children: [
                InteractiveViewer(
                  minScale: 1, maxScale: 3,
                  child: Image.memory(_pages[index],
                    semanticLabel: '${widget.brochure.title} - PDF page ${index + 1}',
                    gaplessPlayback: true),
                ),
                const SizedBox(height: 6),
                Text('Page ${index + 1} of ${_pages.length}'),
              ]),
            ),
          ) : ListView.builder(
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

