import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'otp_verification_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail}); 

  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null && widget.initialEmail!.isNotEmpty) {
      _emailController.text = widget.initialEmail!;
    }
  } 
  // Logic to call your Node.js backend
  Future<void> _sendOTP() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text("Please enter your email")),
      );
      return;
    }

    setState(() => _isLoading = true);
    const String baseUrl = 'https://financewise-api-xua8.onrender.com';
    try {
     
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": _emailController.text.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 300));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP sent successfully!")),
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationScreen(email: _emailController.text.trim()),
            ),
          );
        }
      
      } else {
        final error = jsonDecode(response.body);
        final String realError = error['details'] ?? error['message'] ?? "Unknown Server Error";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("🚨 Error: $realError"),
        ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🚨 Network Crash: $e"), backgroundColor: Colors.red),
        
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505), // Matches your AuthScreen background
      appBar: AppBar(
        title: const Text("Reset Password"), 
        elevation: 0,
        backgroundColor: Colors.transparent, // Blends into the dark theme
        foregroundColor: Colors.white, // Makes the back arrow white
      ),
    body: Align(
        alignment: const Alignment(0, -0.3), // Pushes the content slightly above center
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400), // Stops stretching
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Vertically centers the content
              children: [
                const Text(
                  "Forgot Password? 🔐",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Enter your registered email and we'll send you a 6-digit OTP to reset your password.",
                  style: TextStyle(color: Colors.white70, fontSize: 16,height: 1.5),
                ),
                const SizedBox(height: 40),
                
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Email Address",
                    labelStyle: const TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF161616), // Matches AuthScreen text fields
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37), // FinanceWise Gold
                      foregroundColor: Colors.black, // Makes text and icons black
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(
                          height: 24, 
                          width: 24, 
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)
                        ) 
                      : const Text(
                          "SEND OTP", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
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