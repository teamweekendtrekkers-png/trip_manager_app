import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../services/github_service.dart';

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

                // Contact Info Card
                _buildCard(
                  title: 'Contact Information',
                  icon: Icons.contact_phone,
                  children: [
                    TextFormField(
                      controller: _whatsappController,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.message),
                        helperText: 'For customer inquiries',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _upiController,
                      decoration: const InputDecoration(
                        labelText: 'UPI ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                        helperText: 'For payment collection',
                      ),
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
                  label: const Text('Save Settings'),
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
          content: Text('Settings saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }
}
