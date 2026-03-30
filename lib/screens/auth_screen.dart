import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'forgot_password_screen.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // Only used for registration
  String? _emailError;
 String? _passwordError;
 String? _nameError;
  bool _isLogin = true; // Toggles between Login and Register modes
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

setState(() {
      _emailError = email.isEmpty ? 'Required' : null;
      _passwordError = password.isEmpty ? 'Required' : null;
      if (!_isLogin) _nameError = name.isEmpty ? 'Required' : null;
    });
    // Basic validation
    if ( _emailError != null || _passwordError != null || (!_isLogin && _nameError != null)) {
      return;
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError('Please enter a valid email address (e.g., name@email.com).');
      return;
    }

    // 3. Password length check (Optional but professional)
    if (password.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }

    setState(() => _isLoading = true);

    String? errorMessage;
    final auth = ref.read(authProvider.notifier);

    if (_isLogin) {
      errorMessage = await auth.login(email, password);
    } else {
      errorMessage = await auth.register(name, email, password);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (errorMessage != null) {
        _showError(errorMessage);
      }
      // If errorMessage is null, it was a success. 
      // main.dart will automatically detect the token and switch to the Dashboard.
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      backgroundColor: Colors.redAccent.shade700,
      behavior: SnackBarBehavior.floating, // THIS IS THE MAGIC LINE
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
      elevation: 6,
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFD4AF37);
    const obsidian = Color(0xFF050505);

    return Scaffold(
      backgroundColor: obsidian,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "FINANCEWISE",
                textAlign: TextAlign.center,
                style: GoogleFonts.oswald(
                  fontSize: 32,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? "Welcome back." : "Create your wealth engine.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // NAME FIELD (Only visible when Registering)
              if (!_isLogin) ...[
                _buildTextField(
                  controller: _nameController,
                  hint: "Full Name",
                  icon: Icons.person_outline,
                  errorText: _nameError,
                  onChanged: (value) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // EMAIL FIELD
              _buildTextField(
                controller: _emailController,
                hint: "Email Address",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                onChanged: (value) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: 16),

              // PASSWORD FIELD
              _buildTextField(
                controller: _passwordController,
                hint: "Password",
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                onChanged: (value) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                suffixIcon: IconButton(
                  icon: Icon(
    _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
    color: const Color(0xFFD4AF37), // 👈 CHANGED TO FINANCEWISE GOLD
  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                
              ),
              if (_isLogin)
  Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ForgotPasswordScreen(initialEmail: _emailController.text.trim(),),
          ),
        );
      },
      child: const Text(
        "Forgot Password?",
        style: TextStyle(
          color: Color(0xFFD4AF37), // Matches your 'gold' constant
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ),
              const SizedBox(height: 32),

              // SUBMIT BUTTON
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isLogin ? "LOGIN" : "REGISTER",
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // TOGGLE MODE BUTTON
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(
                  _isLogin
                      ? "Don't have an account? Register"
                      : "Already have an account? Login",
                  style: const TextStyle(color: gold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper method for clean text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: Colors.white54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF161616),
       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}