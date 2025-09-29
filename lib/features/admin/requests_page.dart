import 'package:flutter/material.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Wire to backend when endpoints are ready.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SizedBox(height: 16),
        Text(
          'Incoming Requests',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text('No endpoints yet. We’ll list and approve/deny requests here.'),
      ],
    );
  }
}
