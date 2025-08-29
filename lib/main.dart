import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/auth_page.dart';
// ignore: unused_import
import 'pages/home_page.dart';
import 'pages/request_book_page.dart';
import 'pages/submit_book_page.dart';

void main() {
  // ProviderScope is required to use Riverpod
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BookHub',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const AuthPage(),

      routes: {
        "/home": (_) => const HomePage(),
        "/submitBook": (_) => const SubmitBookPage(),
        "/requestBook": (_) => const RequestBookPage(),
      },
    );
  }
}
