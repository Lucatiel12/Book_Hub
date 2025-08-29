import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryBooksPage extends StatelessWidget {
  final Category category;

  const CategoryBooksPage({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: Text(
          "Books for ${category.name} will appear here",
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ),
    );
  }
}
