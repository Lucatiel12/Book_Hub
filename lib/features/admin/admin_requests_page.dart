import 'package:flutter/material.dart';
import 'package:book_hub/features/admin/requests_page.dart';

class AdminRequestsPage extends StatelessWidget {
  const AdminRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RequestsPage(
      fixedType: 'LOOKUP', // show only user book-lookups
      // fixedStatus: 'PENDING', // uncomment if you want only pending
    );
  }
}
