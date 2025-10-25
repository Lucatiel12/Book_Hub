// lib/models/category.dart
class Category {
  final String id;
  final String name;
  final int bookCount;

  const Category({
    required this.id,
    required this.name,
    required this.bookCount,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown',
      bookCount:
          (json['bookCount'] is int)
              ? json['bookCount']
              : int.tryParse(json['bookCount']?.toString() ?? '0') ?? 0,
    );
  }
}
