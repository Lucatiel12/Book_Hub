import 'package:flutter/material.dart';
import '../models/category.dart';
import 'category_books_page.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  // ▼ Mock Data: Replace with backend data later
  final List<Category> _allCategories = const [
    Category(icon: Icons.book_outlined, name: 'Literature', bookCount: 2847),
    Category(icon: Icons.science_outlined, name: 'Science', bookCount: 1293),
    Category(icon: Icons.history_edu_outlined, name: 'History', bookCount: 956),
    Category(
      icon: Icons.auto_stories_outlined,
      name: 'Fantasy',
      bookCount: 2104,
    ),
    Category(icon: Icons.biotech_outlined, name: 'Technology', bookCount: 876),
    Category(icon: Icons.person_outline, name: 'Biography', bookCount: 451),
    Category(
      icon: Icons.psychology_outlined,
      name: 'Philosophy',
      bookCount: 322,
    ),
    Category(icon: Icons.explore_outlined, name: 'Adventure', bookCount: 1589),
    Category(icon: Icons.favorite_border, name: 'Romance', bookCount: 1845),
    Category(icon: Icons.movie_filter_outlined, name: 'Drama', bookCount: 673),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Categories'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
          childAspectRatio: 1.2,
        ),
        itemCount: _allCategories.length,
        itemBuilder: (context, index) {
          final category = _allCategories[index];
          return _CategoryCard(category: category);
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Category category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // ✅ Navigate to CategoryBooksPage with the category name
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CategoryBooksPage(categoryName: category.name),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, size: 36, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${category.bookCount} books',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
