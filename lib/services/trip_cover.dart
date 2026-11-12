/// The old new-trip template used this path, but the website has no such file.
bool isPlaceholderTripCover(Object? value) =>
    value?.toString().trim().replaceFirst(RegExp(r'^/'), '') ==
    'images/trips/default.jpg';
