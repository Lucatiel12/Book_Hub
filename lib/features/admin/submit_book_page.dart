import 'dart:io';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/admin/submit_book_provider.dart';

class SubmitBookPage extends ConsumerStatefulWidget {
  const SubmitBookPage({super.key});

  @override
  ConsumerState<SubmitBookPage> createState() => _SubmitBookPageState();
}

class _SubmitBookPageState extends ConsumerState<SubmitBookPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _isbn = TextEditingController();
  final _published = TextEditingController();

  PlatformFile? _cover;
  PlatformFile? _ebook;
  List<String> _categoryIds = [];

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (res != null && res.files.isNotEmpty)
      setState(() => _cover = res.files.first);
  }

  Future<void> _pickEbook() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf'],
      withData: false,
    );
    if (res != null && res.files.isNotEmpty)
      setState(() => _ebook = res.files.first);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_ebook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach an EPUB or PDF file')),
      );
      return;
    }

    final notifier = ref.read(submitBookControllerProvider.notifier);
    final ok = await notifier.submit(
      title: _title.text.trim(),
      author: _author.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      isbn: _isbn.text.trim().isEmpty ? null : _isbn.text.trim(),
      publishedDate:
          _published.text.trim().isEmpty ? null : _published.text.trim(),
      categoryIds: _categoryIds,
      coverPath: _cover?.path,
      ebookPath: _ebook!.path!,
    );

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Book submitted')));
      _form.currentState!.reset();
      setState(() {
        _cover = null;
        _ebook = null;
        _categoryIds = [];
      });
    } else {
      final err = ref.read(submitBookControllerProvider).errorMessage;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err ?? 'Failed to submit')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitBookControllerProvider);

    return AbsorbPointer(
      absorbing: state.isSubmitting,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _author,
                decoration: const InputDecoration(labelText: 'Author'),
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _isbn,
                decoration: const InputDecoration(labelText: 'ISBN (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _published,
                decoration: const InputDecoration(
                  labelText: 'Published date (YYYY or YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 16),

              // Files
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image),
                      label: Text(
                        _cover == null ? 'Cover image' : _cover!.name,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickEbook,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_ebook == null ? 'EPUB / PDF' : _ebook!.name),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Categories simple comma input (replace with chips later)
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Category IDs (comma-separated)',
                ),
                onChanged: (v) {
                  _categoryIds =
                      v
                          .split(',')
                          .map((s) => s.trim())
                          .where((s) => s.isNotEmpty)
                          .toList();
                },
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon:
                      state.isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  label: const Text('Submit Book'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
