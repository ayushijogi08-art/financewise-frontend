import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pinput/pinput.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  
  const OTPVerificationScreen({super.key, required this.email});

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _verifyAndReset() async {
    final otp = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();

    if (otp.length != 6) {
      _showError("OTP must be exactly 6 digits.");
      return;
    }
    if (newPassword.length < 6) {
      _showError("New password must be at least 6 characters.");
      return;
    }

    setState(() => _isLoading = true);

    // Platform detection for the correct backend URL
   const String baseUrl = 'https://financewise-api-xua8.onrender.com';

    try {
      // 1. Verify the OTP First
      final verifyRes = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-otp'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email, "otp": otp}),
      );

      if (verifyRes.statusCode != 200) {
        final error = jsonDecode(verifyRes.body);
        _showError(error['message'] ?? "Invalid or expired OTP.");
        setState(() => _isLoading = false);
        return;
      }

      // 2. If OTP is valid, Reset the Password
      final resetRes = await http.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": widget.email, "newPassword": newPassword}),
      );

      if (resetRes.statusCode == 200) {
        // Success Notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 10),
                Text("Password Reset Successful!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          ),
        );
        
        // Pop everything off the stack and return to the Login Screen
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        final error = jsonDecode(resetRes.body);
        _showError(error['message'] ?? "Failed to reset password.");
      }
    } catch (e) {
      _showError("Server error. Is your backend running and CORS enabled?");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    // Professional Golden Theme for the 6 boxes
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Verify OTP 🛡️", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Text("Sent to ${widget.email}", style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 40),
                
                // THE 6 GOLDEN BOXES (ONLY ONE WIDGET HERE)
                Pinput(
                  length: 6,
                  controller: _otpController,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: const Color(0xFFD4AF37), width: 2), // FinanceWise Gold
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),

                // NEW PASSWORD FIELD (YOU DELETED THIS, I ADDED IT BACK)
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "New Password",
                    labelStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD4AF37)),
                   suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFFD4AF37),
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);  // Toggle
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFF161616),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 30),

                // SUBMIT BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _verifyAndReset,
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black) 
                      : const Text("RESET PASSWORD", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}