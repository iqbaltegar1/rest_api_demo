// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/task_api.dart';
import 'local/task_local_db.dart';
import 'providers/task_provider.dart';
import 'screens/login_screen.dart';
import 'screens/task_list_screen.dart';

void main() {
  // Initialize services (API + Local DB)
  final apiService = TaskApiService();
  final localDb = TaskLocalDb();

  runApp(
    ChangeNotifierProvider(
      create: (context) {
        final taskProvider = TaskProvider(apiService, localDb);
        taskProvider.checkSession(); // Load saved session + offline local tasks
        return taskProvider;
      },
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline-First Tasks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // Auth selector
      home: Selector<TaskProvider, bool>(
        selector: (context, provider) => provider.isAuthLoading,
        builder: (context, isAuthLoading, child) {
          return Consumer<TaskProvider>(
            builder: (context, taskProvider, child) {
              // Loading Session Check
              if (isAuthLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              // Jika sudah login → masuk ke TaskList
              return taskProvider.isAuthenticated
                  ? const TaskListScreen()
                  : const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
