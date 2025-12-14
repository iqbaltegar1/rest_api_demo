// lib/screens/task_list_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import 'add_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoaded) {
        _hasLoaded = true;
        context.read<TaskProvider>().loadTasksOfflineFirst();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(taskProvider.showOnlyUnsynced 
              ? 'Unsynced Tasks (${taskProvider.tasks.length})'
              : 'All Tasks (${taskProvider.tasks.length})'),
            const SizedBox(height: 2),
            _buildSyncSubtitle(taskProvider),
          ],
        ),
        actions: [
          if (taskProvider.unsyncedCount > 0)
            IconButton(
              icon: const Icon(Icons.cloud_upload, color: Colors.orange),
              tooltip: 'Force Sync to Server',
              onPressed: () {
                taskProvider.forceSync();
              },
            ),

          IconButton(
            icon: Icon(taskProvider.showOnlyUnsynced
                ? Icons.filter_alt_off
                : Icons.filter_alt),
            tooltip: taskProvider.showOnlyUnsynced
                ? 'Show All Tasks'
                : 'Show Unsynced Only',
            onPressed: () {
              taskProvider.toggleFilterUnsynced();
            },
          ),
          
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [Icon(Icons.refresh), SizedBox(width: 8), Text('Refresh')],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [Icon(Icons.logout), SizedBox(width: 8), Text('Logout')],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                taskProvider.logout();
              } else if (value == 'refresh') {
                taskProvider.loadTasksOfflineFirst();
              }
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // Tampilkan pesan error jika ada
          if (taskProvider.errorMessage != null)
             Container(
              width: double.infinity,
              color: Colors.red[100],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                   const Icon(Icons.error, color: Colors.red, size: 20),
                   const SizedBox(width: 8),
                   Expanded(
                     child: Text(
                      taskProvider.errorMessage!,
                      style: const TextStyle(fontSize: 12, color: Colors.red),
                     ),
                   ),
                   IconButton(
                     icon: const Icon(Icons.close, size: 16),
                     onPressed: () => taskProvider.clearError(),
                   )
                ],
              ),
            ),
            
          if (taskProvider.lastSyncTime != null)
            Container(
              width: double.infinity,
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                'Terakhir sinkron: ${DateFormat('dd MMM HH:mm:ss').format(taskProvider.lastSyncTime!)}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            
          Expanded(child: _buildBody(taskProvider)),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTaskScreen()),
          );
          if (result == true) {
            // Updated automatically
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  // ===== UI Handling =====

  Widget _buildSyncSubtitle(TaskProvider provider) {
    if (provider.isTaskLoading && provider.tasks.isEmpty) {
      return const Text('Memuat data lokal...', style: TextStyle(fontSize: 12));
    }

    if (provider.isSyncing) {
      return const Text('Sinkronisasi dengan server...', style: TextStyle(fontSize: 12));
    }

    if (provider.unsyncedCount > 0) {
      return Text(
        '${provider.unsyncedCount} task belum tersinkron',
        style: const TextStyle(fontSize: 12),
      );
    }

    return const Text('Semua data tersinkron', style: TextStyle(fontSize: 12));
  }

  Widget _buildBody(TaskProvider provider) {
    if (provider.isTaskLoading && provider.tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error sudah ditampilkan di atas, jadi di sini kita hanya tampilkan empty state
    // jika benar-benar kosong dan error

    if (provider.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
                provider.showOnlyUnsynced 
                ? 'Tidak ada unsynced tasks' 
                : 'Belum ada tasks',
                style: const TextStyle(fontSize: 18)
            ),
            if (!provider.showOnlyUnsynced) ...[
              const SizedBox(height: 8),
              const Text('Tap + untuk menambah task pertama'),
            ]
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadTasksOfflineFirst(),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: provider.tasks.length,
        itemBuilder: (context, index) {
          return TaskCard(task: provider.tasks[index]);
        },
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;

  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final isUnsynced = !task.isSynced;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Checkbox(
              value: task.completed,
              onChanged: (value) async {
                final success = await context.read<TaskProvider>().toggleTask(task);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal update task'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            if (isUnsynced)
              const Positioned(
                right: 0,
                bottom: 0,
                child: Icon(Icons.offline_bolt, size: 14, color: Colors.orangeAccent),
              ),
          ],
        ),

        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.completed ? TextDecoration.lineThrough : null,
            color: task.completed ? Colors.grey : null,
          ),
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (isUnsynced)
              const Text(
                'Belum terkirim ke server',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
          ],
        ),

        trailing: task.completed
            ? const Icon(Icons.check_circle, color: Colors.green)
            : PopupMenuButton(
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Hapus'),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'delete') {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Hapus Task'),
                  content: const Text('Yakin ingin menghapus task ini?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                final success = await context.read<TaskProvider>().deleteTask(task);

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Task dihapus')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gagal menghapus task'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }
}
