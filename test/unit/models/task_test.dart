import 'package:flutter_test/flutter_test.dart';
import 'package:rest_api_demo/models/task.dart';

void main() {
  group('Task Model Tests', () {
    test('fromJson should create a valid Task object from API response', () {
      final json = {
        'id': 1,
        'title': 'Test Task',
        'description': 'Test Description',
        'completed': true,
        'user_id': 'user123',
        'created_at': '2023-01-01T00:00:00.000Z'
      };

      final task = Task.fromJson(json);

      expect(task.serverId, 1);
      expect(task.title, 'Test Task');
      expect(task.description, 'Test Description');
      expect(task.completed, true);
      expect(task.userId, 'user123');
      expect(task.isSynced, true);
    });

    test('toJson should convert Task object to valid JSON for API', () {
      final task = Task(
        serverId: 1,
        title: 'Test Task',
        description: 'Test Description',
        completed: true,
        userId: 'user123',
        createdAt: DateTime(2023, 1, 1),
      );

      final json = task.toJson();

      expect(json['id'], 1);
      expect(json['title'], 'Test Task');
      expect(json['description'], 'Test Description');
      expect(json['completed'], true);
      expect(json['user_id'], 'user123');
    });

    test('fromMap should create Task from SQLite map', () {
      final map = {
        'local_id': 1,
        'server_id': 2,
        'title': 'Local Task',
        'description': 'Local Desc',
        'completed': 0,
        'user_id': 'user456',
        'created_at': '2023-01-01T00:00:00.000Z',
        'is_synced': 1
      };

      final task = Task.fromMap(map);

      expect(task.localId, 1);
      expect(task.serverId, 2);
      expect(task.title, 'Local Task');
      expect(task.completed, false);
      expect(task.isSynced, true);
    });

    test('toMap should convert Task to SQLite map', () {
      final task = Task(
        localId: 1,
        title: 'Local Task',
        userId: 'user456',
        completed: true,
        isSynced: false,
      );

      final map = task.toMap();

      expect(map['local_id'], 1);
      expect(map['title'], 'Local Task');
      expect(map['completed'], 1);
      expect(map['is_synced'], 0);
    });

    test('fromJson should handle null fields gracefully', () {
      final json = {
        'title': 'Minimal Task',
        'user_id': 'user789',
      };

      final task = Task.fromJson(json);

      expect(task.title, 'Minimal Task');
      expect(task.description, '');
      expect(task.completed, false);
      expect(task.userId, 'user789');
    });
  });
}
