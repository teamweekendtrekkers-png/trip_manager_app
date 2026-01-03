import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../services/github_service.dart';
import '../services/website_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tokenController;
  late TextEditingController _ownerController;
  late TextEditingController _repoController;
  late TextEditingController _branchController;
  late TextEditingController _whatsappController;
  late TextEditingController _upiController;
  
  bool _isVerifying = false;
  bool? _tokenValid;
  String? _tokenMessage;
  
  bool _isSyncingToWebsite = false;
  bool _isLoadingWebsiteSettings = false;
  String? _websiteUpi;
  String? _websiteWhatsapp;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _tokenController = TextEditingController(text: settings.githubToken);
    _ownerController = TextEditingController(text: settings.repositoryOwner);
    _repoController = TextEditingController(text: settings.repositoryName);
    _branchController = TextEditingController(text: settings.branch);
    _whatsappController = TextEditingController(text: settings.whatsappNumber);
    _upiController = TextEditingController(text: settings.upiId);
    
    // Load current website settings
    _loadWebsiteSettings();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    _branchController.dispose();
    _whatsappController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  Future<void> _loadWebsiteSettings() async {
    final settings = context.read<SettingsProvider>().settings;
    if (settings.githubToken.isEmpty) return;
    
    setState(() => _isLoadingWebsiteSettings = true);
    
    try {
      final service = WebsiteSettingsService(settings: settings);
      final websiteSettings = await service.getCurrentWebsiteSettings();
      
      if (mounted) {
        setState(() {
          _websiteUpi = websiteSettings.upiId;
          _websiteWhatsapp = websiteSettings.whatsAppNumber;
          _isLoadingWebsiteSettings = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingWebsiteSettings = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // GitHub Configuration Card
                _buildCard(
                  title: 'GitHub Configuration',
                  icon: Icons.code,
                  children: [
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: 'GitHub Personal Access Token',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: _tokenValid == null
                            ? null
                            : Icon(
                                _tokenValid! ? Icons.check_circle : Icons.error,
                                color: _tokenValid! ? Colors.green : Colors.red,
                              ),
                        helperText: 'Required for push access',
                      ),
                      obscureText: true,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    if (_tokenMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _tokenValid == true ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _tokenMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: _tokenValid == true ? Colors.green[800] : Colors.orange[800],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _verifyToken,
                        icon: _isVerifying
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user),
                        label: const Text('Verify Token'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _ownerController,
                            decoration: const InputDecoration(
                              labelText: 'Repository Owner',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _repoController,
                            decoration: const InputDecoration(
                              labelText: 'Repository Name',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _branchController,
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.alt_route),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Contact Info Card with Sync Button
                _buildCard(
                  title: 'Website Contact & Payment',
                  icon: Icons.web,
                  children: [
                    // Current website settings info
                    if (_isLoadingWebsiteSettings)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (_websiteUpi != null || _websiteWhatsapp != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Website Settings:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_websiteWhatsapp != null)
                              Text(
                                'WhatsApp: $_websiteWhatsapp',
                                style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                              ),
                            if (_websiteUpi != null)
                              Text(
                                'UPI: $_websiteUpi',
                                style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                              ),
                          ],
                        ),
                      ),
                    
                    TextFormField(
                      controller: _whatsappController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message, color: Colors.green),
                        helperText: 'Format: 917019235581 (country code + number)',
                        hintText: '917019235581',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _upiController,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment, color: Colors.purple),
                        helperText: 'Format: 9538236581@ybl',
                        hintText: '9538236581@ybl',
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Sync to Website Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSyncingToWebsite ? null : _syncToWebsite,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(14),
                        ),
                        icon: _isSyncingToWebsite 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.sync),
                        label: Text(_isSyncingToWebsite 
                          ? 'Syncing to Website...' 
                          : 'Sync to Website'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will update security.js and all HTML files on your website',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // App Settings Card
                _buildCard(
                  title: 'App Settings',
                  icon: Icons.settings,
                  children: [
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Enable dark theme'),
                      value: provider.settings.darkMode,
                      onChanged: (v) => provider.toggleDarkMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Help Card
                _buildCard(
                  title: 'Help & Info',
                  icon: Icons.help,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.launch),
                      title: const Text('How to get GitHub Token'),
                      onTap: () => _launchUrl('https://github.com/settings/tokens/new'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.web),
                      title: const Text('View Website'),
                      onTap: () => _launchUrl(
                        'https://${provider.settings.repositoryOwner}.github.io/${provider.settings.repositoryName}/',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('View Repository'),
                      onTap: () => _launchUrl(
                        'https://github.com/${provider.settings.repositoryOwner}/${provider.settings.repositoryName}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Settings (Local)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),

                // Version info
                Center(
                  child: Text(
                    'Trip Manager v1.0.0',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _syncToWebsite() async {
    final settings = context.read<SettingsProvider>().settings;
    
    if (settings.githubToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure GitHub token first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final upi = _upiController.text.trim();
    final whatsapp = _whatsappController.text.trim();
    
    if (upi.isEmpty || whatsapp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill both UPI ID and WhatsApp number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Confirm before syncing
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync to Website'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will update the following on your live website:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.message, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('WhatsApp: $whatsapp')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.payment, size: 16, color: Colors.purple),
                      const SizedBox(width: 8),
                      Expanded(child: Text('UPI: $upi')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Files to be updated:\n• js/security.js (UPI)\n• index.html, trips.html, etc. (WhatsApp)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Sync Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _isSyncingToWebsite = true);
    
    try {
      final service = WebsiteSettingsService(settings: settings);
      final result = await service.updateBothSettings(upi, whatsapp);
      
      if (mounted) {
        // Show detailed result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(result.success ? 'Success!' : 'Sync Result'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.message != null)
                  Text(result.message!),
                if (result.details != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.details!,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        // Refresh website settings display
        _loadWebsiteSettings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncingToWebsite = false);
      }
    }
  }

  Future<void> _verifyToken() async {
    if (_tokenController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a token first')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _tokenValid = null;
      _tokenMessage = null;
    });

    final settings = context.read<SettingsProvider>().settings.copyWith(
      githubToken: _tokenController.text,
      repositoryOwner: _ownerController.text,
      repositoryName: _repoController.text,
    );
    final service = GitHubService(settings: settings);
    final result = await service.verifyToken();

    setState(() {
      _isVerifying = false;
      _tokenValid = result.isValid && result.canPush;
      _tokenMessage = result.message;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.isValid 
              ? (result.canPush ? 'Token is valid with write access!' : 'Token valid but limited access')
              : 'Invalid token'),
          backgroundColor: result.isValid && result.canPush ? Colors.green : (result.isValid ? Colors.orange : Colors.red),
        ),
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SettingsProvider>();
    await provider.saveSettings(provider.settings.copyWith(
      githubToken: _tokenController.text,
      repositoryOwner: _ownerController.text,
      repositoryName: _repoController.text,
      branch: _branchController.text,
      whatsappNumber: _whatsappController.text,
      upiId: _upiController.text,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved locally!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }
}
