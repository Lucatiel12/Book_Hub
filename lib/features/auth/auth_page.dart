import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:book_hub/features/auth/auth_provider.dart';
import '../../pages/home_page.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  bool isLogin = true;
  bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 🔹 Try restoring a session automatically
    Future.microtask(() => ref.read(authProvider.notifier).tryAutoLogin());
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final formKey = isLogin ? _loginFormKey : _registerFormKey;
    if (!formKey.currentState!.validate()) {
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    if (isLogin) {
      authNotifier.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      authNotifier.register(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    });

    final error = authState.errorMessage?.trim();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 57, 123, 199),
                  Color.fromARGB(255, 184, 115, 249),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book, size: 80, color: Colors.white),
                    const SizedBox(height: 15),
                    Text(
                      "BookHub",
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Offline Reader & Knowledge Delivery",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),

                    // ✅ ERROR MESSAGE DISPLAY - Only if text exists
                    if (error != null && error.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                error,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                ref.read(authProvider.notifier).clearError();
                              },
                            ),
                          ],
                        ),
                      ),

                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => setState(() => isLogin = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isLogin
                                                  ? Colors.blueAccent
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          "Login",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isLogin
                                                    ? Colors.white
                                                    : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap:
                                          () => setState(() => isLogin = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              !isLogin
                                                  ? Colors.blueAccent
                                                  : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                        child: Text(
                                          "Register",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color:
                                                !isLogin
                                                    ? Colors.white
                                                    : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child:
                                  isLogin
                                      ? _buildLoginForm()
                                      : _buildRegisterForm(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ✅ Loading Overlay
          if (authState.isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey("login"),
        children: [
          _buildTextField(
            icon: Icons.email_outlined,
            label: "Email",
            controller: _emailController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email';
              }
              if (!value.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            icon: Icons.lock_outline,
            label: "Password",
            controller: _passwordController,
            isPassword: true,
            visible: passwordVisible,
            onToggle: () => setState(() => passwordVisible = !passwordVisible),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildButton("Sign In", onPressed: _submit),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey("register"),
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  icon: Icons.person_outline,
                  label: "First Name",
                  controller: _firstNameController,
                  validator:
                      (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTextField(
                  icon: Icons.person_outline,
                  label: "Last Name",
                  controller: _lastNameController,
                  validator:
                      (value) =>
                          (value == null || value.isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildTextField(
            icon: Icons.email_outlined,
            label: "Email",
            controller: _emailController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email';
              }
              if (!value.contains('@')) return 'Please enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            icon: Icons.lock_outline,
            label: "Password",
            controller: _passwordController,
            isPassword: true,
            visible: passwordVisible,
            onToggle: () => setState(() => passwordVisible = !passwordVisible),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 15),
          _buildTextField(
            icon: Icons.lock_outline,
            label: "Confirm Password",
            controller: _confirmPasswordController,
            isPassword: true,
            visible: confirmPasswordVisible,
            onToggle:
                () => setState(
                  () => confirmPasswordVisible = !confirmPasswordVisible,
                ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _buildButton("Create Account", onPressed: _submit),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool isPassword = false,
    bool visible = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !visible,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon:
            isPassword
                ? IconButton(
                  icon: Icon(visible ? Icons.visibility : Icons.visibility_off),
                  onPressed: onToggle,
                )
                : null,
        labelText: label,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }

  Widget _buildButton(String text, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }
}
