import 'package:flutter/material.dart';
import 'package:book_hub/features/admin/requests_page.dart';

class AdminSubmissionsPage extends StatelessWidget {
  const AdminSubmissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RequestsPage(
      fixedType: 'CONTRIBUTION', // show only user contributions (submit book)
      // fixedStatus: 'PENDING',
    );
  }
}
