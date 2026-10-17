import 'package:flutter/material.dart';

class ManagerSetupChecklist extends StatelessWidget {
  const ManagerSetupChecklist({
    super.key, required this.configured, required this.hasTrips,
    required this.hasPublished, required this.onConnection,
    required this.onTrips, required this.onPayments, required this.onPublish,
  });
  final bool configured, hasTrips, hasPublished;
  final VoidCallback onConnection, onTrips, onPayments, onPublish;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      key: const Key('manager-setup-checklist'),
      initiallyExpanded: !configured,
      leading: const Icon(Icons.checklist_outlined),
      title: const Text('Getting started'),
      subtitle: const Text('Connect → edit → review → publish'),
      children: [
        _step(context, '1. Save connection details',
          configured ? 'Saved. Use Verify Token in Settings to check access.' : 'Enter your repository and GitHub token in Settings.',
          configured, onConnection),
        _step(context, '2. Load and edit trips',
          'Open Trips, refresh, then edit a trip. Changes stay in your workspace until published.',
          hasTrips, onTrips),
        _step(context, '3. Check UPI and coupons',
          'Choose the payment account and review your checkout settings.',
          null, onPayments),
        _step(context, '4. Review and publish',
          'Use Review & publish in Trips, then check Publishing status to confirm the website is live.',
          hasPublished, onPublish),
      ],
    ),
  );

  Widget _step(BuildContext context, String title, String description,
      bool? complete, VoidCallback action) => ListTile(
    leading: Icon(complete == true ? Icons.check_circle_outline : Icons.radio_button_unchecked,
      color: complete == true ? Theme.of(context).colorScheme.primary : null),
    title: Text(title), subtitle: Text(description),
    trailing: const Icon(Icons.chevron_right), onTap: action,
  );
}
