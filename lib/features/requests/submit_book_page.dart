// lib/pages/admin/submit_book_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SubmitBookPage extends StatefulWidget {
  const SubmitBookPage({super.key});

  @override
  State<SubmitBookPage> createState() => _SubmitBookPageState();
}

class _SubmitBookPageState extends State<SubmitBookPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _isbnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  String? _selectedCategory;

  // Note: In a real app, these category names would be fetched
  // from a backend and would have associated translation keys.
  final List<String> categories = [
    "Literature",
    "Science",
    "History",
    "Fantasy",
    "Technology",
    "Biography",
    "Philosophy",
    "Adventure",
    "Romance",
    "Drama",
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _isbnController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  void _submitForm() {
    final l10n = AppLocalizations.of(context)!;
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.bookSubmittedSuccessfully(title))),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: Text(l10n.submitABook),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFormCard(l10n),
            const SizedBox(height: 16),
            _buildNoteBox(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(26),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FormHeader(
              icon: Icons.library_books_outlined,
              title: l10n.bookDetails,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: _titleController,
              icon: Icons.title,
              label: l10n.bookTitle,
              hint: l10n.enterBookTitleHint,
              validator:
                  (value) => value!.isEmpty ? l10n.pleaseEnterTitle : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _authorController,
              icon: Icons.person_outline,
              label: l10n.author,
              hint: l10n.enterAuthorNameHint,
              validator:
                  (value) => value!.isEmpty ? l10n.pleaseEnterAuthor : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _isbnController,
              icon: Icons.qr_code,
              label: l10n.isbn,
              hint: "978-0-123456-78-9",
              isOptional: true,
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(l10n),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              icon: Icons.description_outlined,
              label: l10n.description,
              hint: l10n.briefDescriptionHint,
              isOptional: true,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _linkController,
              icon: Icons.link,
              label: l10n.pdfEpubLink,
              hint: "https://example.com/book.pdf",
              validator:
                  (value) => value!.isEmpty ? l10n.pleaseEnterLink : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(l10n.createBook),
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
    required String hint,
    bool isOptional = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(icon: icon, label: label, isOptional: isOptional),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(icon: Icons.category_outlined, label: l10n.category),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items:
              categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          decoration: InputDecoration(
            hintText: l10n.selectCategoryHint,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          validator:
              (value) => value == null ? l10n.pleaseSelectCategory : null,
        ),
      ],
    );
  }

  Widget _buildNoteBox(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC8E6C9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF4CAF50), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.submissionGuidelinesNote,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _FormHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF4CAF50), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOptional;

  const _FormLabel({
    required this.icon,
    required this.label,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF4CAF50)),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            text: label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF4CAF50),
            ),
            children: [
              if (!isOptional)
                const TextSpan(text: " *", style: TextStyle(color: Colors.red)),
              if (isOptional)
                TextSpan(
                  text: l10n.optionalLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    color: Colors.black45,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
