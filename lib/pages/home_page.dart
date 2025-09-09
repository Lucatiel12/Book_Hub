import 'package:flutter/material.dart';
import '../features/profile/profile_page.dart';
import 'search_page.dart';
import 'saved_page.dart';
import 'library_page.dart';
import 'book_details_page.dart';
import 'categories_page.dart';
import '../widgets/offline_banner.dart';
import 'package:book_hub/features/downloads/downloads_button.dart';
import 'package:book_hub/features/downloads/download_controller.dart';

// Define your primary green color once for consistency
const Color _primaryGreen = Color(0xFF4CAF50);
const Color _lightGreenBackground = Color(0xFFF0FDF0); // A very light green

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isOffline = false;

  // Pages for each bottom nav item
  final List<Widget> _pages = [
    const _HomeContent(),
    const SearchPage(),
    const SavedPage(),
    const LibraryPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    // Allow Library (index 3) even when offline; block others
    if (_isOffline && index != 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are offline. Only Library is available.'),
        ),
      );
      return; // don't switch
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGreenBackground, // Light green background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Hi there!", style: TextStyle(color: Colors.black87)),
            Text(
              "What would you like to read today?",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: Colors.black87,
            ),
            onPressed: () {},
          ),
          const DownloadsButton(iconColor: Colors.white),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(
            onStatusChanged: (isOffline) {
              setState(() {
                _isOffline = isOffline;
                if (isOffline) _selectedIndex = 3; // force Library when offline
              });
            },
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _primaryGreen, // Green selected item
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: "Saved"),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: "Library",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryGreen, // Green FAB
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.upload_file,
                        color: _primaryGreen, // Green icon
                      ),
                      title: const Text("Submit a Book"),
                      onTap: () {
                        Navigator.pop(context); // close sheet
                        Navigator.pushNamed(
                          context,
                          "/submitBook",
                        ); // 👈 route to SubmitBookPage
                      },
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.edit,
                        color: _primaryGreen,
                      ), // Green icon
                      title: const Text("Request a Book"),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          "/requestBook",
                        ); // 👈 route to RequestBookPage
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ----------------------------
// 🔹 Home Content (without "Continue Reading")
// ----------------------------
class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔍 Search bar
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search,
                color: _primaryGreen,
              ), // Green search icon
              hintText: "Search books, authors...",
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 📊 Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _StatCard(label: "Saved", value: "24", icon: Icons.bookmark),
              _StatCard(label: "Reading", value: "3", icon: Icons.menu_book),
              _StatCard(
                label: "This Month",
                value: "12",
                icon: Icons.date_range,
              ),
              _StatCard(label: "Reviews", value: "8", icon: Icons.star),
            ],
          ),
          const SizedBox(height: 20),

          // ⭐ Featured Books
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Featured Books",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "View All",
                style: TextStyle(color: _primaryGreen),
              ), // Green "View All"
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _BookCard(
                  title: "The Great Gatsby",
                  author: "F. Scott Fitzgerald",
                  rating: 4.5,
                  tag: index == 0 ? "Popular" : null,
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // 📚 Categories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Browse Categories",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoriesPage(),
                    ),
                  );
                },
                child: const Text(
                  "View All",
                  style: TextStyle(color: _primaryGreen), // Green "View All"
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: const [
              _CategoryTile(
                title: "Literature",
                books: 2847,
                icon: Icons.menu_book,
              ),
              _CategoryTile(title: "Science", books: 1293, icon: Icons.science),
              _CategoryTile(title: "History", books: 956, icon: Icons.history),
            ],
          ),
        ],
      ),
    );
  }
}

// ----------------------------
// 🔹 Small reusable widgets
// ----------------------------
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _primaryGreen.withValues(
            alpha: 0.1,
          ), // Light green circle
          child: Icon(icon, color: _primaryGreen), // Green icon
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final String author;
  final double rating;
  final String? tag;

  const _BookCard({
    required this.title,
    required this.author,
    required this.rating,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => BookDetailsPage(
                  title: title,
                  author: author,
                  coverUrl:
                      "https://upload.wikimedia.org/wikipedia/en/f/f7/TheGreatGatsby_1925jacket.jpeg",
                  rating: rating,
                  category: "Classic Literature",
                ),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1), // Subtle shadow
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag != null)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryGreen, // Green tag
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag!,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color:
                      Colors
                          .grey[200], // Lighter grey for book cover placeholder
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.book, size: 50, color: Colors.grey),
                ), // Grey book icon
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              author,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Row(
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text(rating.toString(), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String title;
  final int books;
  final IconData icon;

  const _CategoryTile({
    required this.title,
    required this.books,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0, // Remove card elevation for a flatter look
      color: Colors.white, // Explicitly white background for the card
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _primaryGreen.withValues(
            alpha: 0.1,
          ), // Light green circle
          child: Icon(icon, color: _primaryGreen), // Green icon
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$books books"),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {},
      ),
    );
  }
}
