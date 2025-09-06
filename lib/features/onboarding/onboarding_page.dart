import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_page.dart';
import '../../theme/app_theme.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _page({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 96, color: AppColors.primary),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = index == 2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: controller,
                onPageChanged: (i) => setState(() => index = i),
                children: [
                  _page(
                    icon: Icons.offline_pin_outlined,
                    title: "Read Anywhere",
                    text:
                        "Download books and keep reading even with poor or no internet.",
                  ),
                  _page(
                    icon: Icons.speed,
                    title: "Fast & Light",
                    text: "Minimal UI focused on speed and accessibility.",
                  ),
                  _page(
                    icon: Icons.library_books_outlined,
                    title: "Your Library",
                    text:
                        "Keep saved and downloaded books organized for quick access.",
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Text(
                    "${index + 1}/3",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(isLast ? "Get Started" : "Next"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
