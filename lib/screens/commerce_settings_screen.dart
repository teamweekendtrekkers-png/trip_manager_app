import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/image_upload_service.dart';
import '../widgets/payment_options_editor.dart';
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
  const CommerceSettingsScreen({super.key, this.service, this.qrUploader});
  final Future<String?> Function()? qrUploader;
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
  Map<String,dynamic>? get currentDocument {
    if(config==null)return null;
    final draft=copyDocument(config!);
    final p=draft['payment'] as Map;
    final account=(p['profiles'] as List)[editingProfile] as Map;
    account['upiId']=upi.text.trim();account['receiverName']=receiver.text.trim();account['qrImage']=qrImage.text.trim();
    p['instructions']=instructions.text;
    return CommerceSettingsService.normalize(draft);
  }
  @override
  void applyDocument(Map<String, dynamic> value) {
    config = CommerceSettingsService.normalize(copyDocument(value));
    _loadProfileFields();
    instructions.text = config!['payment']['instructions'];
    dirty = true;
  }

  int editingProfile=0;
  void _loadProfileFields(){
    final account=(config!['payment']['profiles'] as List)[editingProfile] as Map;
    upi.text=account['upiId']??'';receiver.text=account['receiverName']??'';qrImage.text=account['qrImage']??'';
  }
  void _selectProfile(int index){
    _changed((){config=currentDocument;editingProfile=index;_loadProfileFields();});
  }
  void _activateProfile(){
    final draft=currentDocument!,account=(draft['payment']['profiles'] as List)[editingProfile] as Map;
    if(!RegExp(r'^[\w.-]+@[\w.-]+$').hasMatch(account['upiId'].toString())||account['receiverName'].toString().trim().isEmpty||!CommerceSettingsService.validQrPath(account['qrImage'].toString())){
      setState(()=>error='Enter this account’s UPI ID, receiver name and QR image before activating it.');return;
    }
    _changed((){draft['payment']['activeProfileId']=account['id'];config=CommerceSettingsService.normalize(draft);error=null;});
  }
  Widget _profiles(){
    final profiles=config!['payment']['profiles'] as List;
    final selected=profiles[editingProfile] as Map;
    final active=config!['payment']['activeProfileId'];
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('Two saved payment accounts',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),
      const Text('One account is shown to customers. Edit either account, choose Use this account, then Preview & Publish.'),
      const SizedBox(height:12),
      DropdownButtonFormField<int>(key:ValueKey('payment-profile-$editingProfile'),initialValue:editingProfile,isExpanded:true,decoration:const InputDecoration(labelText:'Edit payment account'),items:[for(var i=0;i<profiles.length;i++)DropdownMenuItem(value:i,child:Text('${profiles[i]['label']}${profiles[i]['id']==active?' · Active':''}'))],onChanged:busy?null:(v){if(v!=null)_selectProfile(v);}),
      TextFormField(key:ValueKey('payment-profile-label-$editingProfile'),initialValue:selected['label'].toString(),enabled:!busy,decoration:const InputDecoration(labelText:'Account label'),onChanged:(v)=>_changed(()=>selected['label']=v)),
      if(selected['id']==active)const ListTile(leading:Icon(Icons.check_circle),title:Text('Active account'))
      else OutlinedButton.icon(key:const Key('payment-use-account'),onPressed:busy?null:_activateProfile,icon:const Icon(Icons.swap_horiz),label:const Text('Use this account')),
    ]);
  }
  late CommerceSettingsService service;
  Map<String, dynamic>? config;
  final upi = TextEditingController();
  final receiver = TextEditingController();
  final qrImage = TextEditingController();
  final instructions = TextEditingController();
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
    qrImage.dispose();
    instructions.dispose();
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
        editingProfile = (value['payment']['profiles'] as List).indexWhere((p) => p['id'] == value['payment']['activeProfileId']);
        _loadProfileFields();
        instructions.text = value['payment']['instructions'];
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
    final draft = currentDocument!;
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
    if (approved != true ||
        !mounted ||
        DraftStore.scope(context.read<SettingsProvider>().settings) != _scope)
      return;
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
          'Payment options and customer messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text('Active account: ${(payment['profiles'] as List).firstWhere((p) => p['id'] == payment['activeProfileId'])['label']}'),
        const Text('UPI payment is the default for every bookable trip.'),
        Text(
          '${(payment['requestTripIds'] as List? ?? []).length} trips also offer availability requests',
        ),
        Text('QR section: ${payment['showQr'] == true ? 'Visible' : 'Hidden'}'),
        if (payment['showQr'] == true &&
            payment['qrImage']?.toString().isNotEmpty == true)
          _qrPreview(payment['qrImage']),
        Text(payment['instructions']?.toString() ?? ''),
        const Text(
          'Request first → Booking request received; availability confirmation pending.',
        ),
        if (payment['mode'] != 'confirmation')
          const Text(
            'Direct payment → Payment details submitted; verification pending. No seat is confirmed automatically.',
          ),
        if (payment['showReceiverName'] == true &&
            payment['receiverName'].toString().isNotEmpty)
          Text('Receiver: ${payment['receiverName']}'),
        Text(
          'UPI ID: ${payment['upiId'].toString().isEmpty ? 'Existing UPI account' : payment['upiId']}',
        ),
        const SizedBox(height: 8),
        const Text('Scan QR · Download QR · Copy UPI ID · Chat on WhatsApp'),
        const SizedBox(height: 12),
        Text(
          'Coupon entry: ${value['showCoupons'] == true ? 'Visible' : 'Hidden'}',
        ),
        const SizedBox(height: 8),
        const Text(
          'Send your payment screenshot on WhatsApp after paying. Your place is confirmed after availability and payment are verified.',
        ),
      ],
    );
  }

  Widget _qrPreview(String path) {
    final settings = service.github.settings;
    return SizedBox(
      height: 220,
      child: Image.network(
        'https://raw.githubusercontent.com/${settings.repositoryOwner}/${settings.repositoryName}/${settings.branch}/$path',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Text('QR preview unavailable. Check the image path.'),
        ),
      ),
    );
  }

  Future<void> _uploadQr() async {
    if (busy ||
        DraftStore.scope(context.read<SettingsProvider>().settings) != _scope)
      return;
    setState(() => busy = true);
    try {
      String? path;
      if (widget.qrUploader != null) {
        path = await widget.qrUploader!();
      } else {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (image != null) {
          if (!mounted ||
              DraftStore.scope(context.read<SettingsProvider>().settings) !=
                  _scope)
            return;
          if (![
            'png',
            'jpg',
            'jpeg',
            'webp',
          ].contains(image.path.split('.').last.toLowerCase()))
            throw const FormatException(
              'Choose an original PNG, JPG or WebP QR image.',
            );
          final result =
              await ImageUploadService(
                settings: service.github.settings,
              ).uploadImage(
                imageFile: File(image.path),
                tripId: 'payment_qr',
                isMainImage: true,
              );
          if (!result.success)
            throw StateError(result.error ?? 'QR upload failed.');
          path = result.imagePath;
        }
      }
      if (path != null && mounted) {
        _changed(() {
          qrImage.text = path!;
          config!['payment']['qrImage'] = path;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
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

  Future<void> _deleteCoupon(int index) async {
    final coupon=Map<String,dynamic>.from((config!['coupons'] as List)[index] as Map);
    final code=coupon['code'].toString();
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('Delete coupon $code?'),
      content:const Text('This removes the coupon from your draft. Publish the payment settings to remove it from checkout. Existing bookings keep their recorded totals.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Keep coupon')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete coupon'))],
    ));
    if(confirmed!=true||!mounted||busy)return;
    _changed(()=>(config!['coupons'] as List).removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$code removed from this draft.'),action:SnackBarAction(label:'Undo',onPressed:(){if(!mounted||busy)return;final coupons=config!['coupons'] as List;if(coupons.any((c)=>c['code'].toString().toUpperCase()==code.toUpperCase()))return;_changed(()=>coupons.insert(index.clamp(0,coupons.length),coupon));})));
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
      bottomNavigationBar: config==null?null:SafeArea(child:Padding(padding:const EdgeInsets.all(12),child:Text(busy?'Publishing…':hasLocalEdits?'Unpublished changes · preview and publish when ready':_commit!=null?'Published to GitHub · check Publishing status for deployment':'No unpublished changes',textAlign:TextAlign.center))),
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
                      PaymentOptionsEditor(
                        payment: config!['payment'] as Map<String, dynamic>,
                        key: ValueKey(
                          'payment-options-${config!['payment']['mode']}',
                        ),
                        trips: context.watch<TripsProvider>().trips,
                        busy: busy,
                        onChanged: () => _changed(() {}),
                      ),
                      const SizedBox(height: 16),
                      _profiles(),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('payment-upi-id'),
                        enabled: !busy,
                        controller: upi,
                        onChanged: (_) => _changed(() {}),
                        decoration: const InputDecoration(
                          labelText: 'UPI ID',
                          helperText:
                              'UPI ID that matches this account’s QR image',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('payment-receiver-name'),
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
                      const Text('The receiver name is shown with the active payment account.'),
                      const Divider(),
                      const Text(
                        'UPI QR code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Upload the original QR image without cropping. Check that it pays the same UPI account. Uploading stores the original in GitHub; publish settings to display it.',
                      ),
                      SwitchListTile(
                        key: const Key('payment-show-qr'),
                        title: const Text('Show UPI QR section'),
                        value: config!['payment']['showQr'] == true,
                        onChanged: busy
                            ? null
                            : (value) => _changed(
                                () => config!['payment']['showQr'] = value,
                              ),
                      ),
                      TextField(
                        key: const Key('payment-qr-image'),
                        controller: qrImage,
                        enabled: !busy,
                        decoration: const InputDecoration(
                          labelText: 'QR image path',
                          hintText: 'images/trips/payment_qr.png',
                        ),
                        onChanged: (value) => _changed(
                          () => config!['payment']['qrImage'] = value,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            key: const Key('payment-upload-qr'),
                            onPressed: busy ? null : _uploadQr,
                            icon: const Icon(Icons.qr_code),
                            label: const Text('Upload / replace QR'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () => _changed(() {
                                    qrImage.clear();
                                    config!['payment']['qrImage'] = '';
                                    config!['payment']['showQr'] = false;
                                  }),
                            child: const Text('Remove QR image'),
                          ),
                        ],
                      ),
                      if (qrImage.text.isNotEmpty) _qrPreview(qrImage.text),
                      TextField(
                        key: const Key('payment-instructions'),
                        controller: instructions,
                        enabled: !busy,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: 'Payment instructions',
                        ),
                        onChanged: (value) => _changed(
                          () => config!['payment']['instructions'] = value,
                        ),
                      ),
                      const SizedBox(height: 16),
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
                            trailing: Row(mainAxisSize:MainAxisSize.min,children:[Switch(
                              value: entry.value['enabled'] == true,
                              onChanged: busy
                                  ? null
                                  : (value) => _changed(
                                      () => entry.value['enabled'] = value,
                                    ),
                            ),IconButton(key:ValueKey('delete-coupon-${entry.value['code']}'),tooltip:'Delete coupon ${entry.value['code']}',icon:const Icon(Icons.delete_outline),onPressed:busy?null:()=>_deleteCoupon(entry.key))]),
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
                          child: _preview(currentDocument!),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        key: const Key('payment-publish'),
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

