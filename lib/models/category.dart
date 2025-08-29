import 'package:flutter/material.dart';

class Category {
  final IconData icon;
  final String name;
  final int bookCount;

  const Category({
    required this.icon,
    required this.name,
    required this.bookCount,
  });
}
