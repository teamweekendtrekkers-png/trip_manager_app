import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import '../services/trip_date_utils.dart';

/// Severity levels for health check issues
enum HealthSeverity { error, warning, info }

/// A single health check issue
class HealthIssue {
  final HealthSeverity severity;
  final String title;
  final String description;
  final String? tripId;
  final String? field;
  final bool autoFixable;
  final VoidCallback? fix;

  HealthIssue({
    required this.severity,
    required this.title,
    required this.description,
    this.tripId,
    this.field,
    this.autoFixable = false,
    this.fix,
  });
}

class DataHealthScreen extends StatefulWidget {
  const DataHealthScreen({super.key});

  @override
  State<DataHealthScreen> createState() => _DataHealthScreenState();
}

class _DataHealthScreenState extends State<DataHealthScreen> {
  List<HealthIssue> _issues = [];
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runHealthCheck());
  }

  void _runHealthCheck() {
    final provider = context.read<TripsProvider>();
    final trips = provider.trips;
    final issues = <HealthIssue>[];

    // Surface provider errors before inspecting the in-memory data. This is
    // especially useful when a load or schema failure leaves no trips to scan.
    _checkProviderError(provider, issues);

    // A schema-invalid document can intentionally yield partial trip maps so
    // the load error is diagnosable. Do not run legacy health scans over those
    // maps: several checks assume validated list/object shapes, and offering
    // fixes against invalid source would be unsafe. The provider error above
    // remains visible with the exact blocking fields.
    if (provider.publicationErrors.isNotEmpty) {
      setState(() {
        _issues = issues;
        _hasScanned = true;
      });
      return;
    }

    // 1. Check for duplicate trip IDs
    _checkDuplicateIds(trips, issues);

    // The embedded `featured` values are canonical. Report companion-file
    // drift without mutating either representation during a health scan.
    _checkFeaturedDrift(provider, issues);

    // 2. Check for corrupted strings (apostrophe fragments)
    _checkCorruptedStrings(trips, issues);

    // 3. Check for missing required fields
    _checkMissingFields(trips, issues);

    // 4. Check for broken image paths
    _checkImagePaths(trips, issues);

    // 5. Check for empty arrays that should have content
    _checkEmptyArrays(trips, issues);

    // 6. Check for price format inconsistencies
    _checkPriceFormats(trips, issues);

    // 7. Check for date format issues
    _checkDateFormats(trips, issues);

    // 8. Check for inactive trips
    _checkInactiveTrips(trips, issues);

    setState(() {
      _issues = issues;
      _hasScanned = true;
    });
  }

  void _checkProviderError(TripsProvider provider, List<HealthIssue> issues) {
    final providerError = provider.error?.trim();
    if (providerError == null || providerError.isEmpty) return;

    issues.add(
      HealthIssue(
        severity: HealthSeverity.error,
        title: 'Trip Data Error',
        description: providerError,
      ),
    );
  }

  void _checkFeaturedDrift(TripsProvider provider, List<HealthIssue> issues) {
    if (!provider.hasFeaturedDrift) return;

    final driftIds = provider.featuredDriftIds.toList()..sort();
    issues.add(
      HealthIssue(
        severity: HealthSeverity.warning,
        title: 'Featured Trips Out of Sync',
        description:
            'Featured status differs for: ${driftIds.join(', ')}. The embedded '
            '`featured` value in trips-data.js is canonical; the next atomic '
            'save will synchronize featured-trips.js.',
      ),
    );
  }

  void _checkDuplicateIds(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    final idCounts = <String, int>{};
    for (final trip in trips) {
      final id = trip['id']?.toString() ?? '';
      idCounts[id] = (idCounts[id] ?? 0) + 1;
    }
    for (final entry in idCounts.entries) {
      if (entry.value > 1) {
        issues.add(
          HealthIssue(
            severity: HealthSeverity.error,
            title: 'Duplicate Trip ID',
            description:
                '"${entry.key}" appears ${entry.value} times. The website silently uses only the last occurrence, making earlier entries invisible.',
            tripId: entry.key,
            autoFixable: false,
          ),
        );
      }
    }
  }

  void _checkCorruptedStrings(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    for (final trip in trips) {
      final tripId = trip['id']?.toString() ?? 'unknown';

      // Check string arrays for fragment patterns caused by apostrophe corruption
      final arrayFields = {
        'highlights': trip['highlights'],
        'inclusions': trip['inclusions'],
        'exclusions': trip['exclusions'],
        'thingsToCarry': trip['thingsToCarry'],
      };

      for (final entry in arrayFields.entries) {
        if (entry.value is List) {
          final list = entry.value as List;
          for (int i = 0; i < list.length; i++) {
            final item = list[i].toString();
            // Detect fragment patterns: standalone ", " or single-char items like "s"
            if (item == ', ' ||
                item == ',' ||
                (item.length <= 2 &&
                    i > 0 &&
                    !RegExp(r'^\d+$').hasMatch(item))) {
              issues.add(
                HealthIssue(
                  severity: HealthSeverity.error,
                  title: 'Corrupted String Fragment',
                  description:
                      'Trip "$tripId" → ${entry.key}[$i] = "$item". This is likely an apostrophe-corrupted fragment (e.g., "Sim\'s Park" was split into "Sim", ", ", "s Park").',
                  tripId: tripId,
                  field: entry.key,
                  autoFixable: true,
                  fix: () => _fixCorruptedArray(trip, entry.key),
                ),
              );
              break; // One error per field is enough
            }
          }
        }
      }

      // Check itinerary activities for the same issue
      final itinerary = trip['itinerary'] as List<dynamic>? ?? [];
      for (int d = 0; d < itinerary.length; d++) {
        final day = itinerary[d];
        if (day is Map) {
          final activities = day['activities'] as List<dynamic>? ?? [];
          for (int a = 0; a < activities.length; a++) {
            final item = activities[a].toString();
            if (item == ', ' ||
                item == ',' ||
                (item.length <= 2 &&
                    a > 0 &&
                    !RegExp(r'^\d+$').hasMatch(item))) {
              issues.add(
                HealthIssue(
                  severity: HealthSeverity.error,
                  title: 'Corrupted Itinerary Fragment',
                  description:
                      'Trip "$tripId" → itinerary[Day ${d + 1}].activities[$a] = "$item". Apostrophe corruption detected.',
                  tripId: tripId,
                  field: 'itinerary',
                  autoFixable: true,
                  fix: () => _fixCorruptedItinerary(trip),
                ),
              );
              break;
            }
          }
        }
      }
    }
  }

  void _checkMissingFields(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    for (final trip in trips) {
      final tripId = trip['id']?.toString() ?? 'unknown';
      final requiredFields = {
        'title': trip['title'] ?? trip['name'],
        'location': trip['location'] ?? trip['destination'],
        'price': trip['price'],
        'image': trip['image'],
      };

      for (final entry in requiredFields.entries) {
        if (entry.value == null || entry.value.toString().isEmpty) {
          issues.add(
            HealthIssue(
              severity: HealthSeverity.error,
              title: 'Missing Required Field',
              description: 'Trip "$tripId" is missing "${entry.key}".',
              tripId: tripId,
              field: entry.key,
            ),
          );
        }
      }
    }
  }

  void _checkImagePaths(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    for (final trip in trips) {
      final tripId = trip['id']?.toString() ?? 'unknown';
      final image = trip['image']?.toString() ?? '';

      if (image.isNotEmpty &&
          !image.startsWith('http') &&
          !image.startsWith('images/')) {
        issues.add(
          HealthIssue(
            severity: HealthSeverity.warning,
            title: 'Unusual Image Path',
            description:
                'Trip "$tripId" has image path "$image" which doesn\'t match expected pattern "images/trips/..." or "images/gallery/...".',
            tripId: tripId,
            field: 'image',
          ),
        );
      }

      // Check gallery images
      final gallery = trip['galleryImages'] as List<dynamic>? ?? [];
      for (final img in gallery) {
        final imgStr = img.toString();
        if (imgStr.isNotEmpty &&
            !imgStr.startsWith('http') &&
            !imgStr.startsWith('images/')) {
          issues.add(
            HealthIssue(
              severity: HealthSeverity.warning,
              title: 'Unusual Gallery Path',
              description:
                  'Trip "$tripId" has gallery image "$imgStr" with unexpected path format.',
              tripId: tripId,
              field: 'galleryImages',
            ),
          );
          break;
        }
      }
    }
  }

  void _checkEmptyArrays(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    for (final trip in trips) {
      final tripId = trip['id']?.toString() ?? 'unknown';

      final highlights = trip['highlights'] as List<dynamic>? ?? [];
      if (highlights.isEmpty) {
        issues.add(
          HealthIssue(
            severity: HealthSeverity.info,
            title: 'No Highlights',
            description: 'Trip "$tripId" has no highlights listed.',
            tripId: tripId,
            field: 'highlights',
          ),
        );
      }

      final itinerary = trip['itinerary'] as List<dynamic>? ?? [];
      if (itinerary.isEmpty) {
        issues.add(
          HealthIssue(
            severity: HealthSeverity.info,
            title: 'No Itinerary',
            description: 'Trip "$tripId" has no itinerary defined.',
            tripId: tripId,
            field: 'itinerary',
          ),
        );
      }
    }
  }

  void _checkPriceFormats(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    for (final trip in trips) {
      final tripId = trip['id']?.toString() ?? 'unknown';
      final price = trip['price']?.toString() ?? '';

      if (price.isNotEmpty && !price.startsWith('₹')) {
        issues.add(
          HealthIssue(
            severity: HealthSeverity.warning,
            title: 'Price Missing ₹ Symbol',
            description: 'Trip "$tripId" has price "$price" without ₹ prefix.',
            tripId: tripId,
            field: 'price',
          ),
        );
      }

      // Check for missing comma in prices > 999
      if (price.startsWith('₹')) {
        final numStr = price.substring(1).replaceAll(',', '');
        final num = int.tryParse(numStr);
        if (num != null && num >= 1000 && !price.contains(',')) {
          issues.add(
            HealthIssue(
              severity: HealthSeverity.warning,
              title: 'Price Missing Comma',
              description:
                  'Trip "$tripId" has price "$price" — should have comma formatting (e.g., "₹${_formatWithComma(num)}").',
              tripId: tripId,
              field: 'price',
              autoFixable: true,
              fix: () {
                final provider = context.read<TripsProvider>();
                if (provider.isLoading) return;
                trip['price'] = '₹${_formatWithComma(num)}';
                provider.markDataModified();
                _runHealthCheck();
              },
            ),
          );
        }
      }
    }
  }

  void _checkDateFormats(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    for (final trip in trips) {
      final tripId = trip['id']?.toString() ?? 'unknown';
      final rawDates = trip['availableDates'];
      if (rawDates == null) continue;
      if (rawDates is! List) {
        issues.add(
          HealthIssue(
            severity: HealthSeverity.error,
            title: 'Invalid Trip Date',
            description:
                'Trip "$tripId" has an invalid availableDates value. Expected a list of website-compatible date labels.',
            tripId: tripId,
            field: 'availableDates',
          ),
        );
        continue;
      }

      // An empty list is valid and intentionally renders as
      // "New dates coming soon" on the website.
      final firstLabelByRange = <String, String>{};
      for (final rawDate in rawDates) {
        if (rawDate is! String) {
          issues.add(
            HealthIssue(
              severity: HealthSeverity.error,
              title: 'Invalid Trip Date',
              description:
                  'Trip "$tripId" has a non-text date value "$rawDate". Dates must use a website-compatible text format.',
              tripId: tripId,
              field: 'availableDates',
            ),
          );
          continue;
        }

        final parsed = TripDateUtils.parse(rawDate);
        if (parsed == null) {
          issues.add(
            HealthIssue(
              severity: HealthSeverity.error,
              title: 'Invalid Trip Date',
              description:
                  'Trip "$tripId" has date "$rawDate", which the website date parser cannot read.',
              tripId: tripId,
              field: 'availableDates',
            ),
          );
          continue;
        }

        final firstLabel = firstLabelByRange[parsed.key];
        if (firstLabel != null) {
          issues.add(
            HealthIssue(
              severity: HealthSeverity.warning,
              title: 'Duplicate Date Range',
              description:
                  'Trip "$tripId" has "$rawDate", which duplicates "$firstLabel" as ${TripDateUtils.formatCanonical(parsed)}.',
              tripId: tripId,
              field: 'availableDates',
            ),
          );
        } else {
          firstLabelByRange[parsed.key] = rawDate;
        }
      }
    }
  }

  void _checkInactiveTrips(
    List<Map<String, dynamic>> trips,
    List<HealthIssue> issues,
  ) {
    final inactiveCount = trips.where((t) => t['isActive'] == false).length;
    if (inactiveCount > 0) {
      issues.add(
        HealthIssue(
          severity: HealthSeverity.info,
          title: 'Inactive Trips',
          description:
              '$inactiveCount trip(s) are marked as inactive and hidden from bookings.',
        ),
      );
    }
  }

  /// Attempt to merge corrupted string fragments back together
  void _fixCorruptedArray(Map<String, dynamic> trip, String fieldKey) {
    final provider = context.read<TripsProvider>();
    if (provider.isLoading) return;
    final list = List<String>.from(trip[fieldKey] ?? []);
    final fixed = _mergeFragments(list);
    trip[fieldKey] = fixed;
    provider.markDataModified();
    _runHealthCheck();
  }

  /// Attempt to merge corrupted itinerary activity fragments
  void _fixCorruptedItinerary(Map<String, dynamic> trip) {
    final provider = context.read<TripsProvider>();
    if (provider.isLoading) return;
    final itinerary = List<Map<String, dynamic>>.from(
      (trip['itinerary'] as List<dynamic>? ?? []).map(
        (d) => Map<String, dynamic>.from(d as Map),
      ),
    );
    for (final day in itinerary) {
      if (day['activities'] is List) {
        final activities = List<String>.from(day['activities']);
        day['activities'] = _mergeFragments(activities);
        day['description'] = (day['activities'] as List).join('\n');
      }
    }
    trip['itinerary'] = itinerary;
    provider.markDataModified();
    _runHealthCheck();
  }

  /// Merge string fragments that were split by apostrophe corruption
  /// Pattern: ["Sim", ", ", "s Park"] → ["Sim's Park"]
  List<String> _mergeFragments(List<String> items) {
    if (items.length < 2) return items;
    final result = <String>[];
    int i = 0;
    while (i < items.length) {
      // Check if next items form a fragment pattern
      if (i + 2 < items.length && items[i + 1] == ', ') {
        // Merge: current + apostrophe + next meaningful part
        var merged = items[i];
        int j = i + 1;
        while (j < items.length &&
            (items[j] == ', ' ||
                (items[j].length <= 2 &&
                    !RegExp(r'^\d+$').hasMatch(items[j])))) {
          if (items[j] == ', ') {
            merged += "'";
          } else {
            merged += items[j];
          }
          j++;
        }
        // If we consumed some fragments, check if there's a trailing part
        if (j > i + 1 && j < items.length) {
          // The next item might be the continuation (e.g., "s Park viewpoint")
          merged += items[j];
          j++;
        }
        result.add(merged);
        i = j;
      } else if (items[i] == ', ' ||
          (items[i].length == 1 &&
              i > 0 &&
              !RegExp(r'^\d$').hasMatch(items[i]))) {
        // Skip orphaned fragments (shouldn't happen after merge above)
        i++;
      } else {
        result.add(items[i]);
        i++;
      }
    }
    return result;
  }

  String _formatWithComma(int num) {
    final str = num.toString();
    if (str.length <= 3) return str;
    // Indian number formatting: last 3 digits, then groups of 2
    final last3 = str.substring(str.length - 3);
    final rest = str.substring(0, str.length - 3);
    final parts = <String>[];
    for (int i = rest.length; i > 0; i -= 2) {
      final start = i - 2 < 0 ? 0 : i - 2;
      parts.insert(0, rest.substring(start, i));
    }
    return '${parts.join(',')},$last3';
  }

  int _fixAllAutoFixable() {
    if (context.read<TripsProvider>().isLoading) return 0;
    int fixed = 0;
    // Get auto-fixable issues and run their fixes
    final autoFixable = _issues
        .where((i) => i.autoFixable && i.fix != null)
        .toList();
    for (final issue in autoFixable) {
      issue.fix!();
      fixed++;
    }
    return fixed;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripsProvider>();
    final operationInProgress = provider.isLoading;
    final errorCount = _issues
        .where((i) => i.severity == HealthSeverity.error)
        .length;
    final warningCount = _issues
        .where((i) => i.severity == HealthSeverity.warning)
        .length;
    final infoCount = _issues
        .where((i) => i.severity == HealthSeverity.info)
        .length;
    final autoFixCount = _issues.where((i) => i.autoFixable).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Health Check'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: operationInProgress ? null : _runHealthCheck,
            tooltip: 'Re-scan',
          ),
        ],
      ),
      body: !_hasScanned
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: _issues.isEmpty
                      ? Colors.green[50]
                      : (errorCount > 0 ? Colors.red[50] : Colors.orange[50]),
                  child: Column(
                    children: [
                      Icon(
                        _issues.isEmpty
                            ? Icons.check_circle
                            : (errorCount > 0 ? Icons.error : Icons.warning),
                        size: 48,
                        color: _issues.isEmpty
                            ? Colors.green
                            : (errorCount > 0 ? Colors.red : Colors.orange),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _issues.isEmpty
                            ? 'All Clear!'
                            : '${_issues.length} Issues Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _issues.isEmpty
                              ? Colors.green[800]
                              : (errorCount > 0
                                    ? Colors.red[800]
                                    : Colors.orange[800]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer<TripsProvider>(
                        builder: (context, provider, _) {
                          return Text(
                            'Scanning ${provider.tripCount} trips',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSeverityChip(
                            '🔴 Errors',
                            errorCount,
                            Colors.red,
                          ),
                          const SizedBox(width: 12),
                          _buildSeverityChip(
                            '🟡 Warnings',
                            warningCount,
                            Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _buildSeverityChip(
                            '🟢 Info',
                            infoCount,
                            Colors.green,
                          ),
                        ],
                      ),
                      if (autoFixCount > 0) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: operationInProgress
                              ? null
                              : () {
                                  final fixed = _fixAllAutoFixable();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Auto-fixed $fixed issue(s). Push to save changes.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text('Fix $autoFixCount Auto-Fixable Issues'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Issues list
                Expanded(
                  child: _issues.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.thumb_up,
                                size: 64,
                                color: Colors.green[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No issues found!',
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                'Your trip data looks healthy.',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _issues.length,
                          itemBuilder: (context, index) {
                            final issue = _issues[index];
                            return _buildIssueCard(
                              issue,
                              operationInProgress: operationInProgress,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSeverityChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildIssueCard(
    HealthIssue issue, {
    required bool operationInProgress,
  }) {
    final Color color;
    final IconData icon;
    switch (issue.severity) {
      case HealthSeverity.error:
        color = Colors.red;
        icon = Icons.error;
      case HealthSeverity.warning:
        color = Colors.orange;
        icon = Icons.warning;
      case HealthSeverity.info:
        color = Colors.blue;
        icon = Icons.info;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Row(
          children: [
            Expanded(
              child: Text(
                issue.title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
            if (issue.autoFixable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Auto-fix',
                  style: TextStyle(fontSize: 10, color: Colors.deepPurple[700]),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(issue.description, style: const TextStyle(fontSize: 13)),
            if (issue.tripId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Trip: ${issue.tripId}${issue.field != null ? ' → ${issue.field}' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: issue.autoFixable && issue.fix != null
            ? IconButton(
                icon: const Icon(Icons.auto_fix_high, color: Colors.deepPurple),
                onPressed: operationInProgress
                    ? null
                    : () {
                        issue.fix!();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Fixed: ${issue.title}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                tooltip: 'Auto-fix this issue',
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}
