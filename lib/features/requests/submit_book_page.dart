import 'package:flutter/material.dart';

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
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Book "$title" submitted successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        title: const Text("Submit a Book"),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFormCard(),
            const SizedBox(height: 16),
            _buildNoteBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
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
            const _FormHeader(
              icon: Icons.library_books_outlined,
              title: "Book Details",
            ),
            const SizedBox(height: 24),

            _buildTextField(
              controller: _titleController,
              icon: Icons.title,
              label: "Book Title",
              hint: "Enter the book title",
              validator:
                  (value) => value!.isEmpty ? "Please enter a title" : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _authorController,
              icon: Icons.person_outline,
              label: "Author",
              hint: "Enter the author's name",
              validator:
                  (value) => value!.isEmpty ? "Please enter an author" : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _isbnController,
              icon: Icons.qr_code,
              label: "ISBN",
              hint: "978-0-123456-78-9",
              isOptional: true,
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              icon: Icons.description_outlined,
              label: "Description",
              hint: "Brief description of the book...",
              isOptional: true,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _linkController,
              icon: Icons.link,
              label: "PDF/ePub Link",
              hint: "https://example.com/book.pdf",
              validator:
                  (value) => value!.isEmpty ? "Please enter a link" : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text("Submit Book"),
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

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FormLabel(icon: Icons.category_outlined, label: "Category"),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          items:
              categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          decoration: InputDecoration(
            hintText: "Select a category",
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
              (value) => value == null ? "Please select a category" : null,
        ),
      ],
    );
  }

  Widget _buildNoteBox() {
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
              "Note: Please ensure your book link is publicly accessible and the content complies with our submission guidelines.",
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
                const TextSpan(
                  text: " (Optional)",
                  style: TextStyle(
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
