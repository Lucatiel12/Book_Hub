// lib/pages/categories_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:book_hub/features/books/providers/categories_provider.dart';
import 'package:book_hub/backend/models/dtos.dart'; // CategoryDto

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catsAsync = ref.watch(categoriesProvider);

    String _countLabel(int? raw) {
      final n = raw ?? 0;
      if (n == 0) return 'No books';
      if (n == 1) return '1 book';
      return '$n books';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.browseCategories),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(categoriesProvider),
        child: catsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (err, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Text(
                          l10n.errorGeneric(err.toString()),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(categoriesProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          data: (List<CategoryDto> cats) {
            if (cats.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Text(
                      l10n.noResultsTryAnotherKeyword,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: cats.length,
              separatorBuilder:
                  (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) {
                final c = cats[i];
                return ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(c.name),
                  subtitle: Text(
                    _countLabel(c.bookCount),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/categoryBooks',
                      arguments: c, // pass full CategoryDto
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
