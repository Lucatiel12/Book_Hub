import 'package:flutter/material.dart';

class RequestBookPage extends StatefulWidget {
  const RequestBookPage({super.key});

  @override
  State<RequestBookPage> createState() => _RequestBookPageState();
}

class _RequestBookPageState extends State<RequestBookPage> {
  final _formKey = GlobalKey<FormState>();

  String title = "";
  String description = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          "Request a Book",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.2,
              color: const Color(0xFF4CAF50),
              width: double.infinity,
              child: const Column(
                children: [
                  Icon(Icons.menu_book, color: Colors.white, size: 60),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0.0, -50.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(15.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.menu_book,
                              color: const Color(0xFF4CAF50),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Can't find the book you're looking for? Let us know and we'll try to get it for you.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        _buildTextFieldWithIcon(
                          icon: Icons.menu_book,
                          label: "Book Title",
                          hintText: "Enter the book title",
                          validator:
                              (value) =>
                                  value == null || value.isEmpty
                                      ? "Enter a title"
                                      : null,
                          onSaved: (value) => title = value ?? "",
                        ),
                        const SizedBox(height: 20),
                        _buildTextFieldWithIcon(
                          icon: Icons.description,
                          label: "Description (optional)",
                          hintText:
                              "Any additional details about the book (author, genre, edition, etc.)",
                          maxLines: 4,
                          onSaved: (value) => description = value ?? "",
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Help us find the exact book by providing more details",
                          style: TextStyle(fontSize: 12, color: Colors.black45),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Request for \"$title\" submitted!",
                                  ),
                                ),
                              );
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: const Text(
                            "Submit Request",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "We typically respond to book requests within 24-48 hours",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithIcon({
    required IconData icon,
    required String label,
    required String hintText,
    String? Function(String?)? validator,
    void Function(String?)? onSaved,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF4CAF50), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          validator: validator,
          onSaved: onSaved,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.black87),
        ),
      ],
    );
  }
}
