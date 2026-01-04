import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/trips_provider.dart';
import '../providers/settings_provider.dart';
import '../services/image_upload_service.dart';
import '../services/trips_parser.dart';

class TripEditScreen extends StatefulWidget {
  final Map<String, dynamic>? trip;
  final int? index;

  const TripEditScreen({super.key, this.trip, this.index});

  @override
  State<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends State<TripEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _tripData;
  
  // Controllers for text fields
  late TextEditingController _nameController;
  late TextEditingController _destinationController;
  late TextEditingController _descriptionController;
  late TextEditingController _dateController;
  late TextEditingController _priceController;
  late TextEditingController _discountedPriceController;
  late TextEditingController _groupSizeController;
  late TextEditingController _pickupPointController;
  late TextEditingController _imageController;
  // Website-specific fields
  late TextEditingController _badgeController;
  late TextEditingController _distanceController;
  late TextEditingController _elevationController;
  late TextEditingController _bestTimeController;
  late TextEditingController _durationController;
  late TextEditingController _availableDatesController;

  bool get isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();
    _tripData = Map<String, dynamic>.from(widget.trip ?? _getDefaultTrip());
    
    // Handle field name variations from parser (title/name, location/destination, about/description)
    _nameController = TextEditingController(text: _tripData['title'] ?? _tripData['name'] ?? '');
    _destinationController = TextEditingController(text: _tripData['location'] ?? _tripData['destination'] ?? '');
    _descriptionController = TextEditingController(text: _tripData['about'] ?? _tripData['description'] ?? '');
    _dateController = TextEditingController(text: _tripData['date'] ?? '');
    _priceController = TextEditingController(text: _tripData['price']?.toString() ?? '₹0');
    _discountedPriceController = TextEditingController(
      text: _tripData['discountedPrice']?.toString() ?? '',
    );
    _groupSizeController = TextEditingController(
      text: _tripData['groupSize']?.toString() ?? '20',
    );
    _pickupPointController = TextEditingController(text: _tripData['pickupPoint'] ?? '');
    _imageController = TextEditingController(text: _tripData['image'] ?? '');
    // Website-specific fields
    _badgeController = TextEditingController(text: _tripData['badge']?.toString() ?? 'Trek');
    _distanceController = TextEditingController(text: _tripData['distance']?.toString() ?? '');
    _elevationController = TextEditingController(text: _tripData['elevation']?.toString() ?? '');
    _bestTimeController = TextEditingController(text: _tripData['bestTime']?.toString() ?? '');
    _durationController = TextEditingController(text: _tripData['duration']?.toString() ?? '');
    // Available dates as newline-separated string
    final availableDates = _tripData['availableDates'] as List<dynamic>? ?? [];
    _availableDatesController = TextEditingController(text: availableDates.join('\n'));
  }

  Map<String, dynamic> _getDefaultTrip() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return {
      'id': 'trip_$id',
      'name': '',
      'destination': '',
      'description': '',
      'date': '',
      'image': 'images/trips/default.jpg',
      'price': '₹0',
      'difficulty': 'Moderate',
      'groupSize': '',
      'pickupPoint': 'Bangalore',
      'featured': false,
      'badge': 'Trek',
      'distance': '',
      'elevation': '',
      'bestTime': '',
      'duration': '',
      'availableDates': <String>[],
      'highlights': <String>[],
      'itinerary': <Map<String, dynamic>>[],
      'inclusions': <String>[],
      'exclusions': <String>[],
      'galleryImages': <String>[],
      'boardingLocations': <Map<String, dynamic>>[],
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _priceController.dispose();
    _discountedPriceController.dispose();
    _groupSizeController.dispose();
    _pickupPointController.dispose();
    _imageController.dispose();
    _badgeController.dispose();
    _distanceController.dispose();
    _elevationController.dispose();
    _bestTimeController.dispose();
    _durationController.dispose();
    _availableDatesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Trip' : 'New Trip'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveTrip,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Basic Info Card
              _buildSectionCard(
                title: 'Basic Information',
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Trip Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _destinationController,
                    decoration: const InputDecoration(
                      labelText: 'Destination *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // About Trip Card
              _buildSectionCard(
                title: 'About This Trip',
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Trip Description / About',
                      hintText: 'Describe the trip experience, what makes it special, scenic beauty, etc.',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                    minLines: 5,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date & Pricing Card
              _buildSectionCard(
                title: 'Date & Pricing',
                children: [
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Date (e.g., Jan 15-17, 2025)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(
                            labelText: 'Price (₹) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _discountedPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Discounted Price (₹)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_offer),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Trip Details Card
              _buildSectionCard(
                title: 'Trip Details',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _tripData['difficulty'] ?? 'Moderate',
                          decoration: const InputDecoration(
                            labelText: 'Difficulty',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.trending_up),
                          ),
                          items: ['Easy', 'Moderate', 'Difficult', 'Extreme']
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _tripData['difficulty'] = v;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _groupSizeController,
                          decoration: const InputDecoration(
                            labelText: 'Group Size',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.group),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _pickupPointController,
                    decoration: const InputDecoration(
                      labelText: 'Pickup Point',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.directions_bus),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Website Fields Card (badge, distance, elevation, etc.)
              _buildSectionCard(
                title: 'Website Display Fields',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _badgeController,
                          decoration: const InputDecoration(
                            labelText: 'Badge/Type',
                            hintText: 'e.g., Weekend Trek, Road Trip',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.label),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          decoration: const InputDecoration(
                            labelText: 'Duration',
                            hintText: 'e.g., 2D/1N',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.schedule),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _distanceController,
                          decoration: const InputDecoration(
                            labelText: 'Distance',
                            hintText: 'e.g., 15-20 km',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _elevationController,
                          decoration: const InputDecoration(
                            labelText: 'Elevation',
                            hintText: 'e.g., 1,420 m',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.terrain),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bestTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Best Time to Visit',
                      hintText: 'e.g., Oct - Feb',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wb_sunny),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _availableDatesController,
                    decoration: const InputDecoration(
                      labelText: 'Available Dates (one per line)',
                      hintText: 'Jan 18-19, 2026\\nJan 25-26, 2026',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Image Card
              _buildSectionCard(
                title: 'Image',
                children: [
                  TextFormField(
                    controller: _imageController,
                    decoration: const InputDecoration(
                      labelText: 'Image Path (e.g., images/trips/goa.jpg)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image),
                    ),
                  ),
                  if (_imageController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _getImageUrl(_imageController.text),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Featured Toggle
              _buildSectionCard(
                title: 'Visibility',
                children: [
                  SwitchListTile(
                    title: const Text('Featured Trip'),
                    subtitle: const Text('Show on homepage carousel'),
                    value: _tripData['featured'] ?? false,
                    onChanged: (v) {
                      setState(() {
                        _tripData['featured'] = v;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Highlights Card
              _buildListSection(
                title: 'Highlights',
                items: List<String>.from(_tripData['highlights'] ?? []),
                onAdd: () => _addListItem('highlights'),
                onRemove: (index) => _removeListItem('highlights', index),
                onEdit: (index, value) => _editListItem('highlights', index, value),
              ),
              const SizedBox(height: 16),

              // Itinerary Card
              _buildItinerarySection(),
              const SizedBox(height: 16),

              // Inclusions Card
              _buildListSection(
                title: 'Inclusions',
                items: List<String>.from(_tripData['inclusions'] ?? []),
                onAdd: () => _addListItem('inclusions'),
                onRemove: (index) => _removeListItem('inclusions', index),
                onEdit: (index, value) => _editListItem('inclusions', index, value),
              ),
              const SizedBox(height: 16),

              // Exclusions Card
              _buildListSection(
                title: 'Exclusions',
                items: List<String>.from(_tripData['exclusions'] ?? []),
                onAdd: () => _addListItem('exclusions'),
                onRemove: (index) => _removeListItem('exclusions', index),
                onEdit: (index, value) => _editListItem('exclusions', index, value),
              ),
              const SizedBox(height: 16),

              // Boarding Locations Card
              _buildBoardingLocationsSection(),
              const SizedBox(height: 16),

              // Gallery Images Card
              _buildGallerySection(),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton.icon(
                onPressed: _saveTrip,
                icon: const Icon(Icons.save),
                label: Text(isEditing ? 'Update Trip' : 'Create Trip'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required List<String> items,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required Function(int, String) onEdit,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: onAdd,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'No items yet. Tap + to add.',
                style: TextStyle(color: Colors.grey[500]),
              )
            else
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 12,
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(item),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () async {
                          final newValue = await _showEditDialog(item);
                          if (newValue != null) {
                            onEdit(index, newValue);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                        onPressed: () => onRemove(index),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildItinerarySection() {
    final itinerary = List<Map<String, dynamic>>.from(_tripData['itinerary'] ?? []);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Itinerary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  onPressed: _addItineraryDay,
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (itinerary.isEmpty)
              Text(
                'No itinerary yet. Tap + to add days.',
                style: TextStyle(color: Colors.grey[500]),
              )
            else
              ...itinerary.asMap().entries.map((entry) {
                final index = entry.key;
                final day = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.grey[50],
                  child: ListTile(
                    title: Text('Day ${day['day'] ?? index + 1}: ${day['title'] ?? ''}'),
                    subtitle: Text(
                      day['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editItineraryDay(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              itinerary.removeAt(index);
                              _tripData['itinerary'] = itinerary;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
  Widget _buildGallerySection() {
    final galleryImages = List<String>.from(_tripData['galleryImages'] ?? []);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gallery Images',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_photo_alternate),
                      onPressed: () => _pickAndUploadImage(),
                      color: Colors.green,
                      tooltip: 'Upload from gallery',
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _pickAndUploadImage(fromCamera: true),
                      color: Colors.blue,
                      tooltip: 'Take photo',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (galleryImages.isEmpty)
              Text(
                'No gallery images yet. Tap icons to add photos.',
                style: TextStyle(color: Colors.grey[500]),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: galleryImages.length,
                itemBuilder: (context, index) {
                  final imagePath = galleryImages[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _getImageUrl(imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeGalleryImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 8),
            // Manual path input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Or enter image path manually',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          galleryImages.add(value);
                          _tripData['galleryImages'] = galleryImages;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles;
    
    if (fromCamera) {
      final photo = await picker.pickImage(source: ImageSource.camera);
      pickedFiles = photo != null ? [photo] : [];
    } else {
      pickedFiles = await picker.pickMultiImage();
    }
    
    if (pickedFiles.isEmpty) return;
    
    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Uploading images...'),
          ],
        ),
      ),
    );
    
    try {
      final settings = context.read<SettingsProvider>().settings;
      final uploadService = ImageUploadService(settings: settings);
      final tripId = _tripData['id']?.toString() ?? 'trip_${DateTime.now().millisecondsSinceEpoch}';
      
      final galleryImages = List<String>.from(_tripData['galleryImages'] ?? []);
      
      for (final pickedFile in pickedFiles) {
        final file = File(pickedFile.path);
        final result = await uploadService.uploadImage(
          imageFile: file,
          tripId: tripId,
        );
        
        if (result.success && result.imagePath != null) {
          galleryImages.add(result.imagePath!);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to upload: ${result.error}')),
            );
          }
        }
      }
      
      setState(() {
        _tripData['galleryImages'] = galleryImages;
      });
    } finally {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
      }
    }
  }

  void _removeGalleryImage(int index) {
    setState(() {
      final galleryImages = List<String>.from(_tripData['galleryImages'] ?? []);
      galleryImages.removeAt(index);
      _tripData['galleryImages'] = galleryImages;
    });
  }

  Widget _buildBoardingLocationsSection() {
    final boardingLocations = List<Map<String, dynamic>>.from(_tripData['boardingLocations'] ?? []);
    final defaultPickupPoints = TripsParser.getDefaultPickupPoints();
    final hasCustomLocations = boardingLocations.isNotEmpty;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Boarding Locations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasCustomLocations)
                      TextButton.icon(
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Use Defaults'),
                        onPressed: () {
                          setState(() {
                            _tripData['boardingLocations'] = List<Map<String, dynamic>>.from(
                              defaultPickupPoints.map((p) => Map<String, dynamic>.from(p))
                            );
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Default pickup points copied. You can now edit them.')),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: _addBoardingLocation,
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Show info about what's displayed on website
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasCustomLocations ? Colors.green[50] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasCustomLocations ? Colors.green[200]! : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasCustomLocations ? Icons.check_circle : Icons.info,
                    color: hasCustomLocations ? Colors.green[700] : Colors.blue[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasCustomLocations 
                        ? 'Website shows custom pickup points below'
                        : 'Website shows default Bangalore pickup points (Majestic, Koramangala, Silk Board, Electronic City)',
                      style: TextStyle(
                        color: hasCustomLocations ? Colors.green[700] : Colors.blue[700],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Show default points if no custom locations
            if (!hasCustomLocations) ...[
              const Text(
                'Default Pickup Points (shown on website):',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              ...defaultPickupPoints.map((loc) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.grey[100],
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.blue),
                  title: Text(loc['name']?.toString() ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Landmark: ${loc['landmark']}'),
                      Text('Time: ${loc['time']}'),
                    ],
                  ),
                  trailing: const Icon(Icons.lock, color: Colors.grey, size: 18),
                ),
              )),
              const SizedBox(height: 8),
              Text(
                'Tap "Use Defaults" to copy and customize these points',
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
            
            // Show custom locations if any
            if (hasCustomLocations) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Custom Pickup Points:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 18, color: Colors.red),
                    label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Custom Points?'),
                          content: const Text('This will remove all custom pickup points. The website will show default Bangalore pickup points instead.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _tripData['boardingLocations'] = <Map<String, dynamic>>[];
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Clear', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...boardingLocations.asMap().entries.map((entry) {
                final index = entry.key;
                final loc = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.green[50],
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.green),
                    title: Text(loc['name']?.toString() ?? 'Unnamed Location'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (loc['landmark']?.toString().isNotEmpty == true)
                          Text('Landmark: ${loc['landmark']}'),
                        if (loc['time']?.toString().isNotEmpty == true)
                          Text('Time: ${loc['time']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editBoardingLocation(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              boardingLocations.removeAt(index);
                              _tripData['boardingLocations'] = boardingLocations;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _addBoardingLocation() async {
    final result = await _showBoardingLocationDialog(null);
    if (result != null) {
      setState(() {
        final boardingLocations = List<Map<String, dynamic>>.from(_tripData['boardingLocations'] ?? []);
        boardingLocations.add(result);
        _tripData['boardingLocations'] = boardingLocations;
      });
    }
  }

  void _editBoardingLocation(int index) async {
    final boardingLocations = List<Map<String, dynamic>>.from(_tripData['boardingLocations'] ?? []);
    final loc = boardingLocations[index];
    
    final result = await _showBoardingLocationDialog(loc);
    if (result != null) {
      setState(() {
        boardingLocations[index] = result;
        _tripData['boardingLocations'] = boardingLocations;
      });
    }
  }

  Future<Map<String, dynamic>?> _showBoardingLocationDialog(Map<String, dynamic>? location) async {
    final nameController = TextEditingController(text: location?['name']?.toString() ?? '');
    final landmarkController = TextEditingController(text: location?['landmark']?.toString() ?? '');
    final timeController = TextEditingController(text: location?['time']?.toString() ?? '');
    final mapLinkController = TextEditingController(text: location?['mapLink']?.toString() ?? '');
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(location == null ? 'Add Boarding Location' : 'Edit Boarding Location'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Location Name *',
                    hintText: 'e.g., Silk Board, Majestic',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: landmarkController,
                  decoration: const InputDecoration(
                    labelText: 'Landmark',
                    hintText: 'e.g., Near Metro Station',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                    labelText: 'Pickup Time',
                    hintText: 'e.g., 10:00 PM',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: mapLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Google Maps Link',
                    hintText: 'https://maps.google.com/...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location name is required')),
                );
                return;
              }
              Navigator.pop(context, {
                'name': nameController.text,
                'landmark': landmarkController.text,
                'time': timeController.text,
                'mapLink': mapLinkController.text,
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  void _addListItem(String key) async {
    final value = await _showEditDialog('');
    if (value != null && value.isNotEmpty) {
      setState(() {
        final list = List<String>.from(_tripData[key] ?? []);
        list.add(value);
        _tripData[key] = list;
      });
    }
  }

  void _removeListItem(String key, int index) {
    setState(() {
      final list = List<String>.from(_tripData[key] ?? []);
      list.removeAt(index);
      _tripData[key] = list;
    });
  }

  void _editListItem(String key, int index, String value) {
    setState(() {
      final list = List<String>.from(_tripData[key] ?? []);
      list[index] = value;
      _tripData[key] = list;
    });
  }

  Future<String?> _showEditDialog(String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(initialValue.isEmpty ? 'Add Item' : 'Edit Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addItineraryDay() async {
    final itinerary = List<Map<String, dynamic>>.from(_tripData['itinerary'] ?? []);
    final dayNumber = itinerary.length;
    final dayLabel = 'Day $dayNumber';
    
    final result = await _showItineraryDialog(dayLabel, '', []);
    if (result != null) {
      setState(() {
        itinerary.add(result);
        _tripData['itinerary'] = itinerary;
      });
    }
  }

  void _editItineraryDay(int index) async {
    final itinerary = List<Map<String, dynamic>>.from(_tripData['itinerary'] ?? []);
    final day = itinerary[index];
    
    // Handle activities as list or description as string
    List<String> activities = [];
    if (day['activities'] != null) {
      activities = List<String>.from(day['activities']);
    } else if (day['description'] != null) {
      activities = day['description'].toString().split('\n');
    }
    
    final result = await _showItineraryDialog(
      day['day']?.toString() ?? 'Day ${index + 1}',
      day['title']?.toString() ?? '',
      activities,
    );
    
    if (result != null) {
      setState(() {
        itinerary[index] = result;
        _tripData['itinerary'] = itinerary;
      });
    }
  }

  Future<Map<String, dynamic>?> _showItineraryDialog(
    String dayLabel,
    String title,
    List<String> activities,
  ) async {
    final dayController = TextEditingController(text: dayLabel);
    final titleController = TextEditingController(text: title);
    final activitiesController = TextEditingController(text: activities.join('\n'));
    
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Day'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: dayController,
                  decoration: const InputDecoration(
                    labelText: 'Day Label',
                    hintText: 'e.g., Day 0, Day 1',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Trek to Summit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: activitiesController,
                  decoration: const InputDecoration(
                    labelText: 'Activities (one per line)',
                    hintText: '6:00 AM - Wake up\n7:00 AM - Breakfast\n8:00 AM - Start trek',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final actList = activitiesController.text
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              Navigator.pop(context, {
                'day': dayController.text,
                'title': titleController.text,
                'activities': actList,
                'description': actList.join('\n'),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  String _getImageUrl(String image) {
    if (image.startsWith('http')) {
      return image;
    }
    return 'https://raw.githubusercontent.com/teamweekendtrekkers-png/teamweekendtrekkerwebsite/main/$image';
  }

  void _saveTrip() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // Update trip data from controllers - use both field name variations for compatibility
    _tripData['title'] = _nameController.text;
    _tripData['name'] = _nameController.text;
    _tripData['location'] = _destinationController.text;
    _tripData['destination'] = _destinationController.text;
    _tripData['about'] = _descriptionController.text;
    _tripData['description'] = _descriptionController.text;
    _tripData['date'] = _dateController.text;
    // Keep price as string (e.g., "₹4,000")
    final priceText = _priceController.text.trim();
    _tripData['price'] = priceText.startsWith('₹') ? priceText : '₹$priceText';
    _tripData['image'] = _imageController.text;
    _tripData['groupSize'] = _groupSizeController.text;
    _tripData['pickupPoint'] = _pickupPointController.text;
    
    // Website-specific fields
    _tripData['badge'] = _badgeController.text.isNotEmpty ? _badgeController.text : 'Trek';
    _tripData['distance'] = _distanceController.text;
    _tripData['elevation'] = _elevationController.text;
    _tripData['bestTime'] = _bestTimeController.text;
    _tripData['duration'] = _durationController.text;
    // Parse available dates from newline-separated text
    _tripData['availableDates'] = _availableDatesController.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    
    // Ensure galleryImages and boardingLocations are preserved
    _tripData['galleryImages'] = _tripData['galleryImages'] ?? <String>[];
    _tripData['boardingLocations'] = _tripData['boardingLocations'] ?? <Map<String, dynamic>>[];
    
    if (_discountedPriceController.text.isNotEmpty) {
      _tripData['discountedPrice'] = double.tryParse(_discountedPriceController.text);
    } else {
      _tripData.remove('discountedPrice');
    }

    final provider = context.read<TripsProvider>();
    
    if (isEditing && widget.index != null) {
      provider.updateTrip(widget.index!, _tripData);
    } else {
      provider.addTrip(_tripData);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Trip updated!' : 'Trip added!'),
        action: SnackBarAction(
          label: 'Save to GitHub',
          onPressed: () {
            // This will be handled in the list screen
          },
        ),
      ),
    );
  }
}
