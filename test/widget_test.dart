import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:rest_api_demo/main.dart';
import 'package:rest_api_demo/providers/task_provider.dart';
import 'package:rest_api_demo/api/task_api.dart';
import 'package:rest_api_demo/local/task_local_db.dart';

// Create mocks using Mockito
class MockTaskApiService extends Mock implements TaskApiService {
  @override
  Future<Map<String, String>?> loadSession() async => null;
}

class MockTaskLocalDb extends Mock implements TaskLocalDb {
   @override
   Future<List<dynamic>> getAllTasks() async => []; // Return empty list
}

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // 1. Setup Mocks
    final mockApiService = MockTaskApiService();
    final mockLocalDb = MockTaskLocalDb();
    
    // 2. Setup Provider with Mocks
    final taskProvider = TaskProvider(mockApiService, mockLocalDb);

    // 3. Build MyApp with the mocked Provider
    // Note: We cannot just pump MyApp() because it uses MultiProvider internally 
    // inside main(), but MyApp itself expects to find a Provider above it or handle it.
    // In your main.dart, MyApp is child of ChangeNotifierProvider. 
    // So in test, we must wrap MyApp in a ChangeNotifierProvider too.
    
    await tester.pumpWidget(
      ChangeNotifierProvider<TaskProvider>.value(
        value: taskProvider,
        child: const MyApp(),
      ),
    );

    // 4. Trigger initial frame
    await tester.pumpAndSettle();

    // 5. Verify basic UI (Expect Login Screen because session is null)
    // Adjust these finders based on your actual UI text/keys
    // Since we return null session, it should go to LoginScreen
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
