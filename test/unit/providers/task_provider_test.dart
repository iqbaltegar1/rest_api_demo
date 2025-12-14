import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:rest_api_demo/api/task_api.dart';
import 'package:rest_api_demo/local/task_local_db.dart';
import 'package:rest_api_demo/providers/task_provider.dart';
import 'package:rest_api_demo/models/task.dart';

// Manual Mock untuk TaskApiService
class MockTaskApiService extends Mock implements TaskApiService {
  @override
  Future<Map<String, dynamic>?> login(String? email, String? password) async {
    if (email == 'test@test.com' && password == 'password') {
      return {
        'user': {'id': '1', 'email': email},
        'access_token': 'token'
      };
    }
    return null;
  }

  @override
  Future<List<Task>> getTasks() async => [];
  
  @override
  Future<void> logout() async {}

  // Implementasi dummy untuk method lain agar tidak error
  @override
  Future<Map<String, dynamic>?> register(String? email, String? password) async => null;
  
  @override
  Future<Map<String, String>?> loadSession() async => null;
  
  @override
  Future<Task?> createTask(Task? task) async => null;
  
  @override
  Future<bool> updateTask(Task? task) async => true;
  
  @override
  Future<bool> deleteTask(int? serverId) async => true;
}

// Manual Mock untuk TaskLocalDb
class MockTaskLocalDb extends Mock implements TaskLocalDb {
  @override
  Future<List<Task>> getAllTasks() async => [];
  
  @override
  Future<List<Task>> getUnsyncedTasks() async => [];
  
  @override
  Future<void> clearAll() async {}
  
  @override
  Future<void> replaceAllTasks(List<Task>? tasks) async {}

  // Implementasi dummy untuk method lain
  @override
  Future<int> insertTask(Task? task) async => 1;
  
  @override
  Future<int> updateTask(Task? task) async => 1;
  
  @override
  Future<int> deleteTask(int? localId) async => 1;
}

void main() {
  late TaskProvider provider;
  late MockTaskApiService mockApiService;
  late MockTaskLocalDb mockLocalDb;

  setUp(() {
    mockApiService = MockTaskApiService();
    mockLocalDb = MockTaskLocalDb();
    provider = TaskProvider(mockApiService, mockLocalDb);
  });

  group('TaskProvider Tests', () {
    test('Initial state is correct', () {
      expect(provider.isAuthenticated, false);
      expect(provider.isTaskLoading, false);
      expect(provider.tasks, isEmpty);
    });

    test('Login success updates state', () async {
      final success = await provider.login('test@test.com', 'password');

      expect(success, true);
      expect(provider.isAuthenticated, true);
      expect(provider.email, 'test@test.com');
      expect(provider.errorMessage, isNull);
    });

    test('Login failure sets error message', () async {
      final success = await provider.login('wrong', 'pass');

      expect(success, false);
      expect(provider.isAuthenticated, false);
      expect(provider.errorMessage, isNotNull);
    });
    
    test('Logout clears state', () async {
      // Login first
      await provider.login('test@test.com', 'password');
      expect(provider.isAuthenticated, true);
      
      // Then logout
      await provider.logout();
      
      expect(provider.isAuthenticated, false);
      expect(provider.email, isNull);
      expect(provider.userId, isNull);
      expect(provider.tasks, isEmpty);
    });
  });
}
