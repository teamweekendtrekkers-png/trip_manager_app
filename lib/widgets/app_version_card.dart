import 'dart:io';
import 'dart:ui' as ui;
import '../models/manager_release_notes.dart';
import 'package:provider/provider.dart';
import '../providers/trips_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

const managerReleasesUrl =
    'https://github.com/teamweekendtrekkers-png/trip_manager_app/actions/workflows/build.yml';

/// Accept only stable, numeric release tags. Build numbers break version ties.
int? compareManagerVersions(String release, String installed) {
  List<int>? parts(String text) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$',
    ).firstMatch(text.trim());
    return match == null
        ? null
        : [for (var i = 1; i <= 4; i++) int.parse(match[i] ?? '0')];
  }

  final a = parts(release), b = parts(installed);
  if (a == null || b == null) return null;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

Future<void> confirmManagerClose(BuildContext context) async {
  final workspace = context.read<TripsProvider?>();
  final platform = Theme.of(context).platform;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Close Trip Manager?'),
      content: Text(
        workspace?.hasUnsavedChanges == true
            ? 'Your workspace has unpublished changes. Save a draft before closing if you want to keep editing later.'
            : 'You can open Trip Manager again whenever you need it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Keep open'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Close app'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await workspace?.flushDraft();
  if (!context.mounted) return;
  if (workspace?.draftError != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The workspace draft could not be saved. Trip Manager is still open.',
        ),
      ),
    );
    return;
  }
  if (platform == TargetPlatform.android) {
    await SystemNavigator.pop();
  } else {
    await ServicesBinding.instance.exitApplication(ui.AppExitType.cancelable);
  }
}

void showManagerUpdates(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('App updates'),
      content: const SizedBox(
        width: 460,
        child: SingleChildScrollView(child: AppVersionCard()),
      ),
      actions: [
        TextButton(
          onPressed: () => confirmManagerClose(context),
          child: const Text('Close app'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close window'),
        ),
      ],
    ),
  );
}

class AppVersionCard extends StatefulWidget {
  const AppVersionCard({super.key, this.compact = false, this.updateClient});
  final bool compact;
  final Dio? updateClient;
  @override
  State<AppVersionCard> createState() => _AppVersionCardState();
}

class _AppVersionCardState extends State<AppVersionCard> {
  PackageInfo? info;
  bool checking = false;
  String? status;
  Uri? updateDownload;
  String? updateLabel;
  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((value) {
          if (mounted) setState(() => info = value);
        })
        .catchError((Object _) {
          if (mounted)
            setState(() => status = 'Installed version unavailable.');
        });
  }

  Future<void> checkUpdates() async {
    if (info == null) return;
    final platform = Theme.of(context).platform;
    setState(() {
      checking = true;
      status = null;
      updateDownload = null;
      updateLabel = null;
    });
    final client =
        widget.updateClient ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
    String message;
    Uri? download;
    String? downloadLabel;
    try {
      const api =
          'https://api.github.com/repos/teamweekendtrekkers-png/trip_manager_app';
      final response = await client.get(
        '$api/actions/workflows/build.yml/runs',
        queryParameters: {
          'branch': 'main',
          'status': 'success',
          'event': 'push',
          'per_page': 1,
        },
      );
      final runs = (response.data as Map)['workflow_runs'] as List;
      if (runs.isEmpty) throw StateError('No completed manager builds');
      final run = runs.first as Map;
      final sha = run['head_sha']?.toString() ?? '';
      final id = run['id']?.toString() ?? '';
      if (!RegExp(r'^[a-f0-9]{40}$').hasMatch(sha) ||
          !RegExp(r'^\d+$').hasMatch(id))
        throw StateError('Invalid build metadata');
      final artifacts = await client.get(
        '$api/actions/runs/$id/artifacts',
        queryParameters: {'per_page': 100},
      );
      final name = platform == TargetPlatform.android
          ? 'trip-manager-android-apk'
          : platform == TargetPlatform.windows
          ? 'trip-manager-windows-x64'
          : '';
      final matching = ((artifacts.data as Map)['artifacts'] as List)
          .whereType<Map>()
          .where((item) => item['name'] == name && item['expired'] == false);
      final artifactId = matching.firstOrNull?['id']?.toString() ?? '';
      final hasDownload = RegExp(r'^[0-9]+$').hasMatch(artifactId);
      final manifest = await client.get(
        'https://raw.githubusercontent.com/teamweekendtrekkers-png/trip_manager_app/$sha/pubspec.yaml',
        options: Options(responseType: ResponseType.plain),
      );
      final tag =
          RegExp(
            r'^version:\s*([^\s#]+)',
            multiLine: true,
          ).firstMatch(manifest.data.toString())?.group(1) ??
          '';
      final comparison = compareManagerVersions(
        tag,
        '${info!.version}+${info!.buildNumber}',
      );
      message = comparison == null
          ? 'Latest completed build version could not be compared.'
          : !hasDownload
          ? 'Latest build is $tag, but its download is unavailable for this device.'
          : comparison > 0
          ? 'Update available: $tag. GitHub sign-in may be required to download it.'
          : comparison == 0
          ? 'You’re up to date with the latest successful manager build.'
          : 'This installed build is newer than the latest successful manager build ($tag).';
      if (hasDownload && comparison != null && comparison > 0) {
        download = Uri.https(
          'github.com',
          '/teamweekendtrekkers-png/trip_manager_app/actions/runs/$id/artifacts/$artifactId',
        );
        downloadLabel = platform == TargetPlatform.android
            ? 'Download Android update'
            : 'Download Windows update';
      }
    } on DioException {
      message =
          'Could not check for updates. Check your connection or try again later.';
    } catch (_) {
      message =
          'No successful manager build could be verified. Try again later.';
    } finally {
      if (widget.updateClient == null) client.close();
    }
    if (mounted)
      setState(() {
        checking = false;
        status = message;
        updateDownload = download;
        updateLabel = downloadLabel;
      });
  }

  Future<void> openDownload(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // The system browser can be unavailable on managed devices.
    }
    if (mounted)
      setState(() => status = 'Could not open downloads. Try again.');
  }

  void details() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('About Trip Manager'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              info == null
                  ? 'Installed version unavailable'
                  : 'Version ${info!.version} · Build ${info!.buildNumber}',
            ),
            const SizedBox(height: 16),
            const Text(
              'What’s new',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              managerReleaseNotes[[info?.version, info?.buildNumber].join('+')]
                      ?.map((note) => '• $note')
                      .join('\n') ??
                  'Release notes are unavailable for this build.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Drafts stay on this device until you publish. Removing an editor draft never changes the live website.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: info == null
              ? null
              : () async {
                  await Clipboard.setData(
                    ClipboardData(
                      text:
                          'Trip Manager ${info!.version}+${info!.buildNumber}\nPlatform: ${Platform.operatingSystem}\nOS: ${Platform.operatingSystemVersion}',
                    ),
                  );
                  if (ctx.mounted)
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'App details copied. No account details included.',
                        ),
                      ),
                    );
                },
          child: const Text('Copy app details'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final label = info == null
        ? 'App version'
        : 'v${info!.version} · Build ${info!.buildNumber}';
    if (widget.compact)
      return ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline),
        title: Text(label),
        subtitle: const Text('Version & what’s new'),
        onTap: () => showManagerUpdates(context),
      );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: Text(label),
              subtitle: const Text('Installed manager app'),
              onTap: details,
            ),
            if (status != null)
              Semantics(liveRegion: true, child: Text(status!)),
            if (updateDownload case final Uri uri)
              FilledButton.icon(
                onPressed: () => openDownload(uri),
                icon: const Icon(Icons.download),
                label: Text(updateLabel!),
              ),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: checking || info == null ? null : checkUpdates,
                  icon: checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update),
                  label: Text(checking ? 'Checking…' : 'Check for updates'),
                ),
                TextButton(onPressed: details, child: const Text('What’s new')),
                TextButton(
                  onPressed: () => openDownload(Uri.parse(managerReleasesUrl)),
                  child: const Text('Open downloads'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
