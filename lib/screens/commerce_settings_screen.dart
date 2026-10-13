import '../widgets/local_draft.dart';
import '../widgets/change_review.dart';
import '../services/workspace_changes.dart';
import '../services/draft_store.dart';
import 'deployment_status_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/trips_provider.dart';
import '../services/github_service.dart';
import '../services/commerce_settings_service.dart';

class CommerceSettingsScreen extends StatefulWidget {
  const CommerceSettingsScreen({super.key, this.service});
  final CommerceSettingsService? service;
  @override
  State<CommerceSettingsScreen> createState() => _CommerceSettingsScreenState();
}

class _CommerceSettingsScreenState extends State<CommerceSettingsScreen>
    with LocalDraft<CommerceSettingsScreen> {
  late String _scope;
  Map<String, dynamic>? _baseline;
  bool _allowLeave = false;
  String? _commit;
  @override
  String get localScope => _scope;
  @override
  String get localSlot => 'payments';
  @override
  bool get draftBusy => busy;
  @override
  Map<String, dynamic>? get currentDocument => config == null
      ? null
      : {
          ...copyDocument(config!),
          'payment': {
            ...(config!['payment'] as Map),
            'upiId': upi.text,
            'receiverName': receiver.text,
          },
        };
  @override
  void applyDocument(Map<String, dynamic> value) {
    config = copyDocument(value);
    upi.text = config!['payment']['upiId'];
    receiver.text = config!['payment']['receiverName'];
    dirty = true;
  }

  late CommerceSettingsService service;
  Map<String, dynamic>? config;
  final upi = TextEditingController();
  final receiver = TextEditingController();
  String? error;
  bool busy = false;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    _scope = DraftStore.scope(context.read<SettingsProvider>().settings);
    service =
        widget.service ??
        CommerceSettingsService(
          GitHubService(settings: context.read<SettingsProvider>().settings),
        );
    _load();
  }

  @override
  void dispose() {
    upi.dispose();
    receiver.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await service.load();
      if (!mounted) return;
      setState(() {
        config = value;
        upi.text = value['payment']['upiId'];
        receiver.text = value['payment']['receiverName'];
        dirty = false;
        _baseline = copyDocument(value);
        startLocalDraft(value);
        dirty = hasLocalEdits;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    dirty = true;
  });
  Future<void> _save() async {
    if (DraftStore.scope(context.read<SettingsProvider>().settings) != _scope) {
      setState(() => error = 'Repository changed. Reopen this editor.');
      return;
    }
    final draft = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(config)) as Map,
    );
    draft['payment']['upiId'] = upi.text.trim();
    draft['payment']['receiverName'] = receiver.text.trim();
    try {
      CommerceSettingsService.validate(draft);
    } catch (e) {
      setState(() => error = e.toString());
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish payment settings and coupons?'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ChangeReview(changes: WorkspaceChanges.diff(_baseline, draft)),
                _preview(draft),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    final previous = copyDocument(_baseline!);
    final result = await service.save(draft);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (result.success) {
        config = draft;
        dirty = false;
      } else {
        error = result.error;
      }
    });
    if (result.success) {
      _baseline = copyDocument(draft);
      _commit = result.commitSha;
      await publishedLocalDraft(previous, draft);
      await DraftStore.recordPublication(localScope, _commit);
      if (!mounted) return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Published. The website updates after deployment passes.'
              : 'Publishing failed. Your edits are retained.',
        ),
      ),
    );
  }

  Widget _preview(Map<String, dynamic> value) {
    final payment = value['payment'] as Map;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Pay only after our team confirms availability',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (payment['showReceiverName'] == true &&
            payment['receiverName'].toString().isNotEmpty)
          Text('Receiver: ${payment['receiverName']}'),
        Text(
          'UPI ID: ${payment['upiId'].toString().isEmpty ? 'Existing UPI account' : payment['upiId']}',
        ),
        const SizedBox(height: 8),
        const Text('Copy UPI ID · Open UPI App · Chat on WhatsApp'),
        const SizedBox(height: 12),
        Text(
          'Coupon entry: ${value['showCoupons'] == true ? 'Visible' : 'Hidden'}',
        ),
        Text(
          'Razorpay: ${payment['showRazorpay'] == true ? 'Visible; online payment link must be confirmed by the team' : 'Hidden'}',
        ),
        const SizedBox(height: 8),
        const Text(
          'Send your payment screenshot on WhatsApp after paying. Your place is confirmed after availability and payment are verified.',
        ),
      ],
    );
  }

  Future<void> _coupon([int? index]) async {
    final coupons = config!['coupons'] as List;
    final existing = index == null
        ? null
        : Map<String, dynamic>.from(coupons[index] as Map);
    final available = context.read<TripsProvider>().trips;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CouponEditor(coupon: existing, trips: available),
    );
    if (result != null && mounted)
      _changed(() {
        if (index == null) {
          coupons.add(result);
        } else {
          coupons[index] = result;
        }
      });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowLeave || !hasLocalEdits && !busy,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || busy) return;
      if (await leaveLocalDraft() && mounted) {
        setState(() {
          dirty = false;
          _allowLeave = true;
        });
        Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Payment Settings & Coupons')),
      body: busy && config == null
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (error != null) ...[
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (config == null)
                      FilledButton(
                        onPressed: busy ? null : _load,
                        child: const Text('Retry loading'),
                      ),
                    if (config != null) ...[
                      localDraftBar(),
                      if (_commit != null)
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeploymentStatusScreen(
                                savedCommitSha: _commit,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Published to GitHub → check deployment',
                          ),
                        ),
                      const Text(
                        'Payment Settings',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: !busy,
                        controller: upi,
                        onChanged: (_) => _changed(() {}),
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          helperText:
                              'Leave blank to retain the existing UPI account',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        enabled: !busy,
                        controller: receiver,
                        onChanged: (_) => _changed(() {}),
                        decoration: const InputDecoration(
                          labelText: 'UPI receiver name',
                          helperText:
                              'Use the recipient name customers see in their UPI app',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('Show receiver name'),
                        value: config!['payment']['showReceiverName'] == true,
                        onChanged: busy
                            ? null
                            : (value) => _changed(
                                () => config!['payment']['showReceiverName'] =
                                    value,
                              ),
                      ),
                      SwitchListTile(
                        title: const Text('Show Razorpay'),
                        subtitle: const Text(
                          'Off by default. The existing gateway is a placeholder; customers are directed to ask for a payment link.',
                        ),
                        value: config!['payment']['showRazorpay'] == true,
                        onChanged: busy
                            ? null
                            : (value) => _changed(
                                () =>
                                    config!['payment']['showRazorpay'] = value,
                              ),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Show coupon entry at checkout'),
                        subtitle: const Text(
                          'Hiding entry is separate from activating a coupon.',
                        ),
                        value: config!['showCoupons'] == true,
                        onChanged: busy
                            ? null
                            : (value) => _changed(
                                () => config!['showCoupons'] = value,
                              ),
                      ),
                      const Text(
                        'Coupons are verified by your team before payment. Codes in a public website are discoverable. Redemption limits are not enforced.',
                      ),
                      const SizedBox(height: 12),
                      for (final entry
                          in (config!['coupons'] as List).asMap().entries)
                        Card(
                          child: ListTile(
                            title: Text(
                              '${entry.value['code']} · ${entry.value['type'] == 'percent' ? '${entry.value['value']}%' : '₹${entry.value['value']}'} off',
                            ),
                            subtitle: Text(
                              '${entry.value['enabled'] == true ? 'Active' : 'Disabled'} · ${entry.value['expiresAt'] ?? 'No expiry'}',
                            ),
                            onTap: busy ? null : () => _coupon(entry.key),
                            trailing: Switch(
                              value: entry.value['enabled'] == true,
                              onChanged: busy
                                  ? null
                                  : (value) => _changed(
                                      () => entry.value['enabled'] = value,
                                    ),
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _coupon(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create coupon'),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Customer preview',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _preview({
                            ...config!,
                            'payment': {
                              ...(config!['payment'] as Map),
                              'upiId': upi.text.trim(),
                              'receiverName': receiver.text.trim(),
                            },
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : _save,
                        icon: const Icon(Icons.publish),
                        label: Text(busy ? 'Publishing…' : 'Preview & Publish'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    ),
  );
}

class CouponEditor extends StatefulWidget {
  const CouponEditor({super.key, this.coupon, required this.trips});
  final Map<String, dynamic>? coupon;
  final List<Map<String, dynamic>> trips;
  @override
  State<CouponEditor> createState() => _CouponEditorState();
}

class _CouponEditorState extends State<CouponEditor> {
  late final TextEditingController code;
  late final TextEditingController value;
  late final TextEditingController cap;
  late final TextEditingController starts;
  late final TextEditingController expires;
  late String type;
  late bool enabled;
  late Set<String> tripIds;
  String? error;
  String localDate(Object? raw) {
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    if (parsed == null) return '';
    return parsed
        .toUtc()
        .add(const Duration(hours: 5, minutes: 30))
        .toIso8601String()
        .substring(0, 16)
        .replaceFirst('T', ' ');
  }

  @override
  void initState() {
    super.initState();
    final c = widget.coupon ?? {};
    code = TextEditingController(text: c['code'] ?? '');
    value = TextEditingController(text: '${c['value'] ?? ''}');
    cap = TextEditingController(text: '${c['maxDiscount'] ?? ''}');
    starts = TextEditingController(text: localDate(c['startsAt']));
    expires = TextEditingController(text: localDate(c['expiresAt']));
    type = c['type'] ?? 'fixed';
    enabled = c['enabled'] != false;
    tripIds = Set<String>.from(c['tripIds'] ?? []);
  }

  @override
  void dispose() {
    for (final controller in [code, value, cap, starts, expires]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? dateValue(String text) {
    if (text.trim().isEmpty) return null;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$').hasMatch(text.trim()))
      throw const FormatException('Use YYYY-MM-DD HH:mm in India time.');
    final candidate = text.trim().replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse('${candidate}:00+05:30');
    if (parsed == null ||
        parsed
                .toUtc()
                .add(const Duration(hours: 5, minutes: 30))
                .toIso8601String()
                .substring(0, 16) !=
            candidate)
      throw const FormatException('Enter a valid date and time.');
    return '${candidate}:00+05:30';
  }

  void save() {
    try {
      if (cap.text.trim().isNotEmpty && num.tryParse(cap.text) == null)
        throw const FormatException('Enter a valid maximum savings amount.');
      final coupon = {
        'code': code.text.trim().toUpperCase(),
        'type': type,
        'value': num.tryParse(value.text),
        'maxDiscount': cap.text.trim().isEmpty ? null : num.tryParse(cap.text),
        'enabled': enabled,
        'startsAt': dateValue(starts.text),
        'expiresAt': dateValue(expires.text),
        'tripIds': tripIds.toList(),
      };
      final config = CommerceSettingsService.defaults();
      config['coupons'] = [coupon];
      CommerceSettingsService.validate(config);
      Navigator.pop(context, coupon);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.coupon == null ? 'Create coupon' : 'Edit coupon'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            TextField(
              controller: code,
              decoration: const InputDecoration(labelText: 'Coupon code'),
            ),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(
                  value: 'fixed',
                  child: Text('Fixed amount (₹)'),
                ),
                DropdownMenuItem(
                  value: 'percent',
                  child: Text('Percentage (%)'),
                ),
              ],
              onChanged: (v) => setState(() => type = v!),
              decoration: const InputDecoration(labelText: 'Discount type'),
            ),
            TextField(
              controller: value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Discount value'),
            ),
            TextField(
              controller: cap,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Maximum savings (₹, optional)',
              ),
            ),
            TextField(
              controller: starts,
              decoration: const InputDecoration(
                labelText: 'Starts at (India time, optional)',
                hintText: '2026-10-16 09:00',
              ),
            ),
            TextField(
              controller: expires,
              decoration: const InputDecoration(
                labelText: 'Expires at (India time, optional)',
                hintText: '2026-10-31 23:59',
              ),
            ),
            SwitchListTile(
              title: const Text('Active'),
              value: enabled,
              onChanged: (v) => setState(() => enabled = v),
            ),
            const Text('Eligible trips — leave all unchecked for every trip'),
            for (final trip in widget.trips)
              CheckboxListTile(
                title: Text('${trip['title'] ?? trip['name'] ?? trip['id']}'),
                value: tripIds.contains(trip['id']),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    tripIds.add(trip['id'].toString());
                  } else {
                    tripIds.remove(trip['id']);
                  }
                }),
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
      FilledButton(onPressed: save, child: const Text('Save coupon')),
    ],
  );
}
