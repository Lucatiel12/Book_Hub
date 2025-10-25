// lib/pages/admin/admin_submit_book_page.dart
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import 'package:book_hub/backend/api_client.dart';
import 'package:book_hub/backend/models/dtos.dart' show CategoryDto;
import 'package:book_hub/features/admin/admin_guard.dart';
import 'package:book_hub/features/auth/auth_provider.dart';

// ✅ use the real admin upload pipeline
import 'package:book_hub/features/admin/admin_submit_controller.dart'; // controller
import 'package:book_hub/features/admin/admin_repository.dart'; // AdminCreateBookRequest

/// Fetch categories for the admin form
final adminSubmitCategoriesProvider = FutureProvider<List<CategoryDto>>((
  ref,
) async {
  final authNotifier = ref.read(authProvider.notifier);
  final api = ref.read(apiClientProvider);

  if (ref.read(authProvider).token == null) {
    await authNotifier.tryAutoLogin();
  }

  try {
    return await api.getCategories(page: 0, size: 200);
  } on DioException catch (e) {
    final code = e.response?.statusCode ?? 0;
    if (code == 401 || code == 403) {
      await authNotifier.tryAutoLogin();
      return await api.getCategories(page: 0, size: 200);
    }
    rethrow;
  }
});

class AdminSubmitBookPage extends ConsumerStatefulWidget {
  const AdminSubmitBookPage({super.key});
  @override
  ConsumerState<AdminSubmitBookPage> createState() =>
      _AdminSubmitBookPageState();
}

class _AdminSubmitBookPageState extends ConsumerState<AdminSubmitBookPage> {
  final _formKey = GlobalKey<FormState>();

  // text fields
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _isbn = TextEditingController();
  final _description = TextEditingController();

  // categories (multi)
  final Set<String> _selectedCategoryIds = {};

  // files
  PlatformFile? _coverImage; // optional
  final List<PlatformFile> _bookFiles = []; // required ≥ 1 (pdf/epub)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ref.read(authProvider).token == null) {
        await ref.read(authProvider.notifier).tryAutoLogin();
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _isbn.dispose();
    _description.dispose();
    super.dispose();
  }

  // -------- pickers ----------
  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _coverImage = res.files.single);
    }
  }

  Future<void> _pickBookFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'epub'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _bookFiles
          ..clear()
          ..addAll(res.files);
      });
    }
  }

  void _removeBookFile(int index) {
    setState(() => _bookFiles.removeAt(index));
  }

  Future<void> _chooseCategories(List<CategoryDto> all) async {
    final temp = Set<String>.from(_selectedCategoryIds);

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          // <-- local state for the sheet
          builder: (context, setSheetState) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Select categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: all.length,
                      itemBuilder: (_, i) {
                        final c = all[i];
                        final selected = temp.contains(c.id);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(c.name),
                          onChanged: (v) {
                            setSheetState(() {
                              if (v == true) {
                                temp.add(c.id);
                              } else {
                                temp.remove(c.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategoryIds
                                ..clear()
                                ..addAll(temp);
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------- submit ----------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_bookFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach at least one PDF/EPUB')),
      );
      return;
    }

    final req = AdminCreateBookRequest(
      title: _title.text.trim(),
      author: _author.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      isbn: _isbn.text.trim().isEmpty ? null : _isbn.text.trim(),
      categoryIds: _selectedCategoryIds.toList(growable: false),
      coverImage: _coverImage,
      bookFiles: _bookFiles,
    );

    await ref.read(adminSubmitControllerProvider.notifier).submit(req);
    final st = ref.read(adminSubmitControllerProvider);

    if (st.error != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: ${st.error}')));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Book created')));
    Navigator.pop(context);
  }

  // -------- PATCHED METHOD (FINAL) --------
  Future<void> _addCategory() async {
    final nameController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        bool creating = false;

        Future<void> doCreate(void Function(void Function()) setLocal) async {
          final name = nameController.text.trim();
          if (name.isEmpty) return;

          // (Optional) quick duplicate check against current list
          final existing = ref
              .read(adminSubmitCategoriesProvider)
              .maybeWhen(
                data:
                    (cats) => cats.any(
                      (c) => c.name.toLowerCase() == name.toLowerCase(),
                    ),
                orElse: () => false,
              );
          if (existing) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category already exists')),
            );
            return;
          }

          setLocal(() => creating = true);
          try {
            final api = ref.read(apiClientProvider);
            final cat = await api.createCategory(name);

            // Refresh and auto-select
            ref.invalidate(adminSubmitCategoriesProvider);
            if (mounted) {
              setState(() => _selectedCategoryIds.add(cat.id));
            }

            // Close the dialog (guard the *dialog* context)
            if (ctx.mounted && Navigator.of(ctx).canPop()) {
              Navigator.of(ctx).pop();
            }

            // Then use the page State's context (guard with State.mounted)
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Category "${cat.name}" created')),
              );
            }
          } on DioException catch (e) {
            final msg =
                e.response?.data is Map<String, dynamic>
                    ? ((e.response!.data['message'] ?? e.message).toString())
                    : e.message ?? 'Failed to create category';
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
            }
          } finally {
            if (ctx.mounted) setLocal(() => creating = false);
          }
        }

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final canCreate =
                !creating && nameController.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('New category'),
              content: TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setLocal(() {}), // update canCreate
                onSubmitted: (_) async {
                  if (canCreate) await doCreate(setLocal);
                },
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  border: OutlineInputBorder(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed:
                      canCreate ? () async => await doCreate(setLocal) : null,
                  icon: const Icon(Icons.add),
                  label: Text(creating ? 'Creating…' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(adminSubmitControllerProvider);
    final catsAsync = ref.watch(adminSubmitCategoriesProvider);

    return AdminGuard(
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Book')),
        body: catsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => _ErrorView(
                message: '$e',
                onRetry: () => ref.invalidate(adminSubmitCategoriesProvider),
              ),
          data:
              (cats) => _FormBody(
                formKey: _formKey,
                title: _title,
                author: _author,
                isbn: _isbn,
                description: _description,
                allCategories: cats,
                selectedCategoryIds: _selectedCategoryIds,
                onChooseCategories: () => _chooseCategories(cats),
                onAddCategory: _addCategory,
                coverImage: _coverImage,
                onPickCover: _pickCover,
                bookFiles: _bookFiles,
                onPickBookFiles: _pickBookFiles,
                onRemoveBookFile: _removeBookFile,
                uploading: submitState.loading,
                progress: submitState.uploadProgress,
                onSubmit: _submit,
              ),
        ),
      ),
    );
  }
}

// ---------------- UI ----------------

class _FormBody extends StatelessWidget {
  final GlobalKey<FormState> formKey;

  final TextEditingController title;
  final TextEditingController author;
  final TextEditingController isbn;
  final TextEditingController description;

  final List<CategoryDto> allCategories;
  final Set<String> selectedCategoryIds;
  final VoidCallback onChooseCategories;
  final VoidCallback onAddCategory;

  final PlatformFile? coverImage;
  final VoidCallback onPickCover;

  final List<PlatformFile> bookFiles;
  final VoidCallback onPickBookFiles;
  final void Function(int index) onRemoveBookFile;

  final bool uploading;
  final double? progress;
  final VoidCallback onSubmit;

  const _FormBody({
    required this.formKey,
    required this.title,
    required this.author,
    required this.isbn,
    required this.description,
    required this.allCategories,
    required this.selectedCategoryIds,
    required this.onChooseCategories,
    required this.onAddCategory,
    required this.coverImage,
    required this.onPickCover,
    required this.bookFiles,
    required this.onPickBookFiles,
    required this.onRemoveBookFile,
    required this.uploading,
    required this.progress,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header('Book details'),
          const SizedBox(height: 8),
          _TextField(
            controller: title,
            label: 'Title *',
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Title is required'
                        : null,
          ),
          const SizedBox(height: 12),
          _TextField(
            controller: author,
            label: 'Author *',
            validator:
                (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Author is required'
                        : null,
          ),
          const SizedBox(height: 12),
          _TextField(controller: isbn, label: 'ISBN (optional)'),
          const SizedBox(height: 12),
          _TextField(
            controller: description,
            label: 'Description (optional)',
            maxLines: 4,
          ),

          const SizedBox(height: 16),
          _Header('Categories (multi)'),
          const SizedBox(height: 8),

          // Small top-right action
          Row(
            children: [
              const Spacer(),
              TextButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
            ],
          ),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...allCategories.map((c) {
                final selected = selectedCategoryIds.contains(c.id);
                return FilterChip(
                  label: Text(c.name),
                  selected: selected,
                  onSelected: (_) => onChooseCategories(),
                );
              }),
              ActionChip(
                label: const Text('Pick…'),
                onPressed: onChooseCategories,
              ),
            ],
          ),

          const SizedBox(height: 24),
          _Header('Cover image'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  coverImage == null
                      ? 'No file selected'
                      : p.basename(coverImage!.name),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: uploading ? null : onPickCover,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Choose'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _Header('Book files (PDF/EPUB) *'),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < bookFiles.length; i++)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: Text(
                    p.basename(bookFiles[i].name),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: uploading ? null : () => onRemoveBookFile(i),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bookFiles.isEmpty
                          ? 'No files selected'
                          : '${bookFiles.length} file(s) selected',
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: uploading ? null : onPickBookFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Add files'),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),
          if (uploading && progress != null) ...[
            LinearProgressIndicator(value: progress!.clamp(0, 1)),
            const SizedBox(height: 12),
            Text('Uploading ${(progress! * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: uploading ? null : onSubmit,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(uploading ? 'Creating…' : 'Create book'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final String? Function(String?)? validator;
  const _TextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
