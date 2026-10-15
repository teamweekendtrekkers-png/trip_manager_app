import 'dart:io';
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
    setState(() => checking = true);
    final client =
        widget.updateClient ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ),
        );
    String message;
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
      final hasDownload = ((artifacts.data as Map)['artifacts'] as List).any(
        (item) =>
            item is Map && item['name'] == name && item['expired'] == false,
      );
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
          ? 'Update available: $tag. Open downloads to get it. GitHub sign-in may be required.'
          : comparison == 0
          ? 'You’re up to date with the latest successful manager build.'
          : 'This installed build is newer than the latest successful manager build ($tag).';
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
      });
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
            const Text(
              '• Original prices crossed out beside discounted prices\n• Visible version and update checks\n• Clearer trip filters and quick actions\n• Discard and delete local drafts\n• Easier website access and publishing status',
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
        onTap: details,
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
            if (status != null) Text(status!),
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
                  onPressed: () async {
                    final opened = await launchUrl(
                      Uri.parse(managerReleasesUrl),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && mounted)
                      setState(
                        () => status = 'Could not open downloads. Try again.',
                      );
                  },
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
