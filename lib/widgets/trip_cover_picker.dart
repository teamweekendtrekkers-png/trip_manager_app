import 'package:flutter/material.dart';
import '../services/trip_cover.dart';

class TripCoverPicker extends StatelessWidget {
  const TripCoverPicker({
    super.key,
    required this.controller,
    required this.galleryPhotos,
    required this.onUpload,
    required this.onCamera,
    required this.onLibrary,
    required this.previewBuilder,
  });
  final TextEditingController controller;
  final List<String> galleryPhotos;
  final VoidCallback onUpload, onCamera, onLibrary;
  final Widget Function(String) previewBuilder;

  Future<void> _chooseGalleryPhoto(BuildContext context) async {
    final photos = galleryPhotos
        .where((p) => p.trim().isNotEmpty && !isPlaceholderTripCover(p))
        .toSet()
        .toList();
    final photo = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Choose a gallery photo as the cover',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: photos.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 64,
                        height: 48,
                        child: previewBuilder(photos[index]),
                      ),
                    ),
                    title: Text('Photo ${index + 1}'),
                    subtitle: Text(
                      photos[index].split('/').last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: controller.text.trim() == photos[index]
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () => Navigator.pop(context, photos[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (photo != null) controller.text = photo;
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, _) {
      final path = value.text.trim();
      final missing = path.isEmpty || isPlaceholderTripCover(path);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            missing ? 'Choose your trip cover' : 'Trip cover photo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a photo for the trip page. Adding gallery photos does not select a cover automatically.',
          ),
          const SizedBox(height: 12),
          if (missing)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                isPlaceholderTripCover(path)
                    ? 'The old placeholder cannot be published. Upload a photo or choose one from your gallery below.'
                    : 'No cover selected yet. You can save your draft and add a photo later.',
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(height: 170, child: previewBuilder(path)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onUpload,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload photo'),
              ),
              OutlinedButton.icon(
                onPressed: onLibrary,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Photo library'),
              ),
              if (galleryPhotos.any(
                (p) => p.trim().isNotEmpty && !isPlaceholderTripCover(p),
              ))
                OutlinedButton.icon(
                  onPressed: () => _chooseGalleryPhoto(context),
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('Use gallery photo'),
                ),
              TextButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Recommended: 1800 × 1200 px. Keep the subject near the centre for mobile crops.',
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced: image path'),
            children: [
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Repository image path',
                  hintText: 'images/trips/your-photo.jpg',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
