// lib/providers/task_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/task_api.dart';
import '../local/task_local_db.dart';
import '../models/task.dart';

class TaskProvider extends ChangeNotifier {
  final TaskApiService _apiService;
  final TaskLocalDb _localDb;

  TaskProvider(this._apiService, this._localDb);

  // ============================================================
  // AUTH STATE
  // ============================================================
  bool _isAuthenticated = false;
  bool _isAuthLoading = true;
  bool _isTaskLoading = false;
  bool _isSyncing = false;

  String? _email;
  String? _userId;
  String? _errorMessage;
  
  // State baru
  bool _showOnlyUnsynced = false;
  DateTime? _lastSyncTime;

  // ============================================================
  // TASK STATE
  // ============================================================
  List<Task> _tasks = [];

  // ============================================================
  // GETTERS
  // ============================================================
  bool get isAuthenticated => _isAuthenticated;
  bool get isAuthLoading => _isAuthLoading;
  bool get isTaskLoading => _isTaskLoading;
  bool get isSyncing => _isSyncing;
  
  String? get email => _email;
  String? get userId => _userId;
  String? get errorMessage => _errorMessage;
  
  bool get showOnlyUnsynced => _showOnlyUnsynced;
  DateTime? get lastSyncTime => _lastSyncTime;

  List<Task> get tasks {
    if (_showOnlyUnsynced) {
      return _tasks.where((t) => !t.isSynced).toList();
    }
    return _tasks;
  }

  int get unsyncedCount =>
      _tasks.where((task) => task.isSynced == false).length;

  // ============================================================
  // FILTERS & UI HELPERS
  // ============================================================
  
  void toggleFilterUnsynced() {
    _showOnlyUnsynced = !_showOnlyUnsynced;
    notifyListeners();
  }

  Future<void> _loadLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final epoch = prefs.getInt('last_sync_time');
    if (epoch != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(epoch);
    }
    notifyListeners();
  }

  Future<void> _updateLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_sync_time', _lastSyncTime!.millisecondsSinceEpoch);
    notifyListeners();
  }

  // ============================================================
  // AUTH FLOW
  // ============================================================

  Future<void> checkSession() async {
    _isAuthLoading = true;
    notifyListeners();

    final session = await _apiService.loadSession();
    if (session != null) {
      _isAuthenticated = true;
      _email = session['email'];
      _userId = session['userId'];

      await _loadLastSyncTime();
      await loadTasksOfflineFirst();
    }

    _isAuthLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    _isAuthLoading = true;
    notifyListeners();

    final result = await _apiService.login(email, password);

    _isAuthLoading = false;

    if (result != null) {
      _isAuthenticated = true;
      _email = result['user']['email'];
      _userId = result['user']['id'];

      await _loadLastSyncTime();
      await loadTasksOfflineFirst();
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Login gagal. Periksa email & password.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _errorMessage = null;
    _isAuthLoading = true;
    notifyListeners();

    final result = await _apiService.register(email, password);

    _isAuthLoading = false;

    if (result != null) {
      _isAuthenticated = true;
      _email = result['user']['email'];
      _userId = result['user']['id'].toString();

      await loadTasksOfflineFirst();
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Registrasi gagal. Coba email lain.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    await _localDb.clearAll();

    _isAuthenticated = false;
    _email = null;
    _userId = null;
    _tasks = [];
    _lastSyncTime = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_sync_time');
    
    notifyListeners();
  }

  // ============================================================
  // SYNC OPERATIONS
  // ============================================================

  Future<void> forceSync() async {
    if (_userId == null) return;
    
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final unsyncedTasks = await _localDb.getUnsyncedTasks();
      int failCount = 0;

      for (final task in unsyncedTasks) {
        if (task.serverId == null) {
          // Create
          final serverTask = await _apiService.createTask(task);
          if (serverTask != null) {
            await _localDb.updateTask(task.copyWith(
              serverId: serverTask.serverId,
              isSynced: true,
              createdAt: serverTask.createdAt 
            ));
          } else {
            failCount++;
          }
        } else {
          // Update
          final success = await _apiService.updateTask(task);
          if (success) {
            await _localDb.updateTask(task.copyWith(isSynced: true));
          } else {
            failCount++;
          }
        }
      }

      // Jika ada kegagalan, beri tahu user
      if (failCount > 0) {
        _errorMessage = 'Gagal menyinkronkan $failCount task. Cek koneksi atau RLS Supabase.';
      } else {
        // Jika sukses semua, update list & timestamp
        await loadTasksOfflineFirst(skipLoadingState: true);
        await _updateLastSyncTime();
      }
      
    } catch (e) {
      _errorMessage = 'Gagal melakukan Force Sync: $e';
    }

    _isSyncing = false;
    notifyListeners();
  }

  Future<void> loadTasksOfflineFirst({bool skipLoadingState = false}) async {
    if (_userId == null) return;

    if (!skipLoadingState) {
      _isTaskLoading = true;
      notifyListeners();
    }

    try {
      _tasks = await _localDb.getAllTasks();
      notifyListeners();

      try {
        final remoteTasks = await _apiService.getTasks();
        
        if (remoteTasks.isNotEmpty) {
           final normalizedRemote = remoteTasks.map((t) {
             return t.copyWith(
               userId: _userId!,
               isSynced: true,
             );
           }).toList();

           final unsyncedLocal = await _localDb.getUnsyncedTasks();
           
           if (unsyncedLocal.isEmpty) {
             await _localDb.replaceAllTasks(normalizedRemote);
             await _updateLastSyncTime();
             _tasks = await _localDb.getAllTasks();
           } else {
             // Opsional: beritahu user ada konflik
           }
        }
      } catch (e) {
        print("Offline load: $e");
      }
      
      if (_errorMessage == null) { // Jangan timpa error dari forceSync
        _errorMessage = null;
      }
    } catch (e) {
      _errorMessage = 'Gagal memuat data lokal.';
    }

    _isTaskLoading = false;
    notifyListeners();
  }

  // ============================================================
  // CRUD
  // ============================================================
  
  Future<bool> addTask(String title, String description) async {
    if (_userId == null) return false;

    _errorMessage = null;

    final localTask = Task(
      title: title,
      description: description,
      userId: _userId!,
      completed: false,
      isSynced: false,
      createdAt: DateTime.now(),
    );

    final localId = await _localDb.insertTask(localTask);
    final taskInserted = localTask.copyWith(localId: localId);

    _tasks.insert(0, taskInserted);
    notifyListeners();

    _apiService.createTask(taskInserted).then((remoteCreated) async {
      if (remoteCreated != null) {
        final synced = taskInserted.copyWith(
          serverId: remoteCreated.serverId,
          createdAt: remoteCreated.createdAt ?? taskInserted.createdAt,
          isSynced: true,
        );
        await _localDb.updateTask(synced);
        
        final idx = _tasks.indexWhere((t) => t.localId == taskInserted.localId);
        if (idx != -1) {
          _tasks[idx] = synced;
          notifyListeners();
        }
        _updateLastSyncTime();
      }
    }).catchError((e) {
      // Ignore
    });

    return true;
  }

  Future<bool> toggleTask(Task task) async {
    final updated = task.copyWith(
      completed: !task.completed,
      isSynced: false,
    );

    await _localDb.updateTask(updated);

    final index = _tasks.indexWhere((t) => t.localId == task.localId);
    if (index != -1) {
      _tasks[index] = updated;
      notifyListeners();
    }

    if (task.serverId == null) return true;

    _apiService.updateTask(updated.copyWith(serverId: task.serverId)).then((success) async {
      if (success) {
        final synced = updated.copyWith(isSynced: true);
        await _localDb.updateTask(synced);
        
        final i = _tasks.indexWhere((t) => t.localId == synced.localId);
        if (i != -1) {
          _tasks[i] = synced;
          notifyListeners();
        }
        _updateLastSyncTime();
      }
    }).catchError((e) {
       // Ignore
    });

    return true;
  }

  Future<bool> deleteTask(Task task) async {
    if (task.localId == null) return false;

    await _localDb.deleteTask(task.localId!);
    _tasks.removeWhere((t) => t.localId == task.localId);
    notifyListeners();

    if (task.serverId == null) return true;

    _apiService.deleteTask(task.serverId!).then((success) {
       if (success) _updateLastSyncTime();
    }).catchError((e) {
       // Ignore
    });

    return true;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
