import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/goal_provider.dart';

// The emulator magic IP. If you ever switch back to a physical phone, change this to your IPv4 address.
 const String _authUrl = 'https://financewise-api-xua8.onrender.com/api/auth';

// This provider holds the JWT Token (String). If it's null, the user is logged out.
class AuthNotifier extends StateNotifier<String?> {
  AuthNotifier() : super(null) {
    _loadToken(); // Check if they are already logged in when the app boots
  }

  // Look in the phone's storage for an existing VIP pass
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('auth_token');
  }

  // REGISTER
  Future<String?> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_authUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        // Success! Save the token to the phone and update the state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('user_name', data['user']['name']);
        await prefs.setString('user_email', data['user']['email']);
        state = data['token'];
        return null; // Null means no error
      } else {
        return data['message'] ?? data['error'] ?? 'Failed to register';// Return the error message
      }
    } catch (e) {
      print("🚨 RAW FLUTTER ERROR: $e"); 
      
      // THIS SHOWS THE RAW ERROR ON YOUR PHONE SCREEN
      return "Error: $e";
    }
  }

  // LOGIN
  Future<String?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_authUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        // Success! Save the token to the phone and update the state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        await prefs.setString('user_name', data['user']['name']);
        await prefs.setString('user_email', data['user']['email']);
        state = data['token'];
       
        return null; // Null means no error
      } else {
        return data['message'] ?? data['error'] ??'Invalid credentials'; // Return the error message
      }
    } catch (e) {
     print("🚨 RAW FLUTTER ERROR: $e"); 
      
      // THIS SHOWS THE RAW ERROR ON YOUR PHONE SCREEN
      return "Error: $e";
    }
  }

  // LOGOUT
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token'); // Destroy the VIP pass
    state = null; // Update state to kick them out of the app
    await prefs.clear();
  }
  // DELETE ACCOUNT
  Future<String?> deleteAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null) return "You are not logged in.";

      final response = await http.delete(
        Uri.parse('$_authUrl/delete-account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Proves WHO wants to delete the account
        },
      );

      if (response.statusCode == 200) {
        await logout(); // Kick them to the login screen and clear local data
        return null; // Success
      } else {
        final data = json.decode(response.body);
        return data['message'] ?? 'Failed to delete account';
      }
    } catch (e) {
      return "Network Error: Cannot reach server.";
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, String?>((ref) {
  return AuthNotifier();
});