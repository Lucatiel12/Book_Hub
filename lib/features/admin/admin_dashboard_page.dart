import 'package:flutter/material.dart';
import 'package:book_hub/features/admin/submit_book_page.dart';
import 'package:book_hub/features/admin/requests_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Submit'), Tab(text: 'Requests')],
          ),
        ),
        body: const TabBarView(
          children: [
            SubmitBookPage(),
            RequestsPage(), // scaffolded for later
          ],
        ),
      ),
    );
  }
}
