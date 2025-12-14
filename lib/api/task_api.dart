// lib/api/task_api.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

class TaskApiService {
  static const String _baseUrl = 'https://bzjledwkoxfnzvtpybgt.supabase.co';
  static const String _apiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6amxlZHdrb3hmbnp2dHB5Ymd0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1NDIyMjQsImV4cCI6MjA4MTExODIyNH0.UPdHQxiRT9Szu6RIAdTg9QmuX78a25C-FoIqYmgZCdQ';

  String? _accessToken;
  String? _refreshTokenStr;
  DateTime? _tokenExpiresAt;
  
  final http.Client _client;

  TaskApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _getHeaders({
    bool includeAuth = true,
    bool returnRepresentation = false,
  }) {
    final headers = <String, String>{
      'apikey': _apiKey,
      'Content-Type': 'application/json',
    };

    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    if (returnRepresentation) {
      headers['Prefer'] = 'return=representation';
    }

    return headers;
  }

  // =========================================================
  // CORE REQUEST HANDLER (AUTO REFRESH & RETRY)
  // =========================================================

  Future<http.Response?> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool returnRepresentation = false,
  }) async {
    // 1. Cek token lokal sebelum request
    await _ensureValidToken();

    final url = Uri.parse('$_baseUrl$endpoint');
    var headers = _getHeaders(returnRepresentation: returnRepresentation);
    final bodyStr = body != null ? jsonEncode(body) : null;

    try {
      http.Response response;
      
      Future<http.Response> send() {
        if (method == 'GET') return _client.get(url, headers: headers);
        if (method == 'POST') return _client.post(url, headers: headers, body: bodyStr);
        if (method == 'PATCH') return _client.patch(url, headers: headers, body: bodyStr);
        if (method == 'DELETE') return _client.delete(url, headers: headers);
        throw Exception('Method not supported');
      }

      response = await send();

      // 2. Jika dapat 401 (JWT Expired) -> Coba Refresh Token & Retry
      if (response.statusCode == 401) {
        print("⚠️ Got 401 JWT Expired. Attempting to refresh token...");
        
        final refreshSuccess = await _refreshToken();
        
        if (refreshSuccess) {
          print("✅ Token refreshed. Retrying original request...");
          headers = _getHeaders(returnRepresentation: returnRepresentation);
          response = await send(); 
        } else {
          print("❌ Refresh failed after 401. Logging out.");
          await logout(); 
        }
      }

      return response;

    } catch (e) {
      print("⚠️ Network Error ($method $endpoint): $e");
      rethrow; 
    }
  }

  // =========================================================
  // TOKEN MANAGEMENT
  // =========================================================

  Future<void> _ensureValidToken() async {
    if (_accessToken == null || _refreshTokenStr == null || _tokenExpiresAt == null) return;

    // Jika expired atau akan expired dalam 2 menit
    if (DateTime.now().add(const Duration(minutes: 2)).isAfter(_tokenExpiresAt!)) {
      print("⏳ Token is expiring soon. Refreshing proactively...");
      await _refreshToken();
    }
  }

  Future<bool> _refreshToken() async {
    if (_refreshTokenStr == null) return false;

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {
          'apikey': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh_token': _refreshTokenStr,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        return true;
      } else {
        if (response.statusCode >= 400 && response.statusCode < 500) {
           print("❌ Refresh token invalid (${response.statusCode}).");
           return false;
        }
        return false;
      }
    } catch (e) {
      print("⚠️ Connection error during refresh: $e");
      return false; 
    }
  }

  // =========================================================
  // PUBLIC METHODS
  // =========================================================

  Future<List<Task>> getTasks() async {
    try {
      final response = await _makeRequest('GET', '/rest/v1/tasks?select=*&order=created_at.desc');

      if (response != null && response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((json) => Task.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return []; 
    }
  }

  Future<Task?> createTask(Task task) async {
    try {
      final response = await _makeRequest(
        'POST', 
        '/rest/v1/tasks',
        body: task.toJson(),
        returnRepresentation: true
      );

      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return Task.fromJson(data[0]);
        } else if (data is Map) {
          return Task.fromJson(Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateTask(Task task) async {
    if (task.serverId == null) return false;
    try {
      final response = await _makeRequest(
        'PATCH', 
        '/rest/v1/tasks?id=eq.${task.serverId}',
        body: task.toJson()
      );
      return response != null && (response.statusCode == 200 || response.statusCode == 204);
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTask(int serverId) async {
    try {
      final response = await _makeRequest(
        'DELETE', 
        '/rest/v1/tasks?id=eq.$serverId'
      );
      return response != null && (response.statusCode == 200 || response.statusCode == 204);
    } catch (e) {
      return false;
    }
  }

  // =========================================================
  // AUTH (LOGIN/REGISTER)
  // =========================================================

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/v1/token?grant_type=password'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> register(String email, String password) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/auth/v1/signup'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _saveSession(data);
        return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, String>?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');
      final expiry = prefs.getInt('expires_at');
      final userId = prefs.getString('user_id');
      final email = prefs.getString('user_email');

      if (token != null && userId != null) {
        // 1. Load data ke memori
        _accessToken = token;
        _refreshTokenStr = refreshToken;
        if (expiry != null) _tokenExpiresAt = DateTime.fromMillisecondsSinceEpoch(expiry);

        // 2. CEK KRITIS: Apakah token sudah mati saat aplikasi baru dibuka?
        // Jika iya, paksa refresh sekarang juga agar user tidak dianggap logout.
        if (_tokenExpiresAt != null && DateTime.now().isAfter(_tokenExpiresAt!)) {
           print("🚀 App Start: Token expired. Refreshing immediately...");
           final success = await _refreshToken();
           if (!success) {
             print("❌ App Start: Refresh failed. User must login.");
             return null; // Gagal refresh, paksa login ulang
           }
        }

        return {'token': _accessToken!, 'userId': userId, 'email': email ?? ''};
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _accessToken = null;
    _refreshTokenStr = null;
    _tokenExpiresAt = null;
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];
    final expiresIn = data['expires_in'] ?? 3600;
    final user = data['user'];

    _accessToken = accessToken;
    _refreshTokenStr = refreshToken;
    _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await prefs.setString('access_token', accessToken);
    if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);
    await prefs.setInt('expires_at', _tokenExpiresAt!.millisecondsSinceEpoch);

    if (user != null) {
      await prefs.setString('user_id', user['id'].toString());
      await prefs.setString('user_email', user['email']);
    }
  }
}
