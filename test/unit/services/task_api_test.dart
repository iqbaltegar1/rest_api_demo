import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rest_api_demo/api/task_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TaskApiService apiService;

  setUp(() {
    // Reset SharedPreferences sebelum setiap test
    SharedPreferences.setMockInitialValues({});
  });

  group('TaskApiService Tests', () {
    test('login returns data on success', () async {
      // Setup Mock Client
      final mockClient = MockClient((request) async {
        // Cek URL dan Method
        if (request.url.path.contains('token') && request.method == 'POST') {
          return http.Response(
            '{"access_token": "token", "user": {"id": "1", "email": "test@test.com"}, "expires_in": 3600, "refresh_token": "refresh"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      // Inject Mock Client
      apiService = TaskApiService(client: mockClient);

      // Execute
      final result = await apiService.login('test@test.com', 'password');

      // Verify
      expect(result, isNotNull);
      expect(result!['access_token'], 'token');
      expect(result['user']['email'], 'test@test.com');
    });

    test('login returns null on failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "invalid_grant"}', 400);
      });

      apiService = TaskApiService(client: mockClient);
      
      final result = await apiService.login('test@test.com', 'password');

      expect(result, isNull);
    });
    
    test('getTasks returns list of tasks', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('tasks') && request.method == 'GET') {
          return http.Response(
            '[{"id": 1, "title": "Test Task", "user_id": "1", "created_at": "2023-01-01T00:00:00"}]',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });
      
      apiService = TaskApiService(client: mockClient);
      
      // Kita perlu set token manual agar request getTasks jalan (karena ada _ensureValidToken)
      // Cara termudah adalah mock SharedPreferences dengan data sesi
      SharedPreferences.setMockInitialValues({
        'access_token': 'fake_token',
        'refresh_token': 'fake_refresh',
        'expires_at': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'user_id': '1',
        'user_email': 'test@test.com',
      });
      
      // Load session agar variable internal _accessToken terisi
      await apiService.loadSession();

      final tasks = await apiService.getTasks();
      
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Test Task');
    });
  });
}
