// lib/models/task.dart

/// Model Task versi offline-first:
/// - Mendukung penyimpanan di Supabase (REST API)
/// - Mendukung penyimpanan di SQLite (offline local DB)
class Task {
  // -------------------------------------------------------------------
  // 1. Field untuk SQLite (Local Database)
  // -------------------------------------------------------------------

  /// Primary key lokal (auto-increment SQLite). Tidak dikirim ke server.
  final int? localId;

  // -------------------------------------------------------------------
  // 2. Field untuk Server (Supabase REST API)
  // -------------------------------------------------------------------

  /// Primary key dari server Supabase ("id" di tabel Supabase).
  final int? serverId;

  // -------------------------------------------------------------------
  // 3. Field domain utama (dipakai oleh lokal & server)
  // -------------------------------------------------------------------

  final String title;
  final String description;
  final bool completed;
  final String userId; // user pemilik task
  final DateTime? createdAt;

  // -------------------------------------------------------------------
  // 4. Sinkronisasi offline-first
  // -------------------------------------------------------------------

  /// Menandai apakah task sudah tersinkron ke server.
  /// - false → masih lokal / perubahan belum terkirim
  /// - true → data sudah ada di server
  final bool isSynced;

  // -------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------

  Task({
    this.localId,
    this.serverId,
    required this.title,
    this.description = '',
    this.completed = false,
    required this.userId,
    this.createdAt,
    this.isSynced = false,
  });

  // ===================================================================
  // Bagian 1 — Convert ke JSON (untuk REST API Supabase)
  // ===================================================================

  /// Body JSON yang dikirim ke Supabase.
  Map<String, dynamic> toJson() {
    final json = {
      'title': title,
      'description': description,
      'completed': completed,
      'user_id': userId,
      'created_at': createdAt?.toIso8601String(),
    };

    // Jika update, kirimkan ID server
    if (serverId != null) {
      json['id'] = serverId;
    }

    return json;
  }

  /// Parsing JSON dari API Supabase.
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      serverId: json['id'] as int?,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      completed: (json['completed'] ?? false) as bool,
      userId: json['user_id'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      isSynced: true, // data dari server selalu dianggap sudah sync
    );
  }

  // ===================================================================
  // Bagian 2 — Convert untuk SQLite (Local Database)
  // ===================================================================

  /// Convert ke Map untuk SQLite.
  Map<String, dynamic> toMap() {
    return {
      'local_id': localId,
      'server_id': serverId,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'user_id': userId,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Buat Task dari hasil query SQLite.
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      localId: map['local_id'] as int?,
      serverId: map['server_id'] as int?,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      completed: (map['completed'] ?? 0) == 1,
      userId: map['user_id'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      isSynced: (map['is_synced'] ?? 0) == 1,
    );
  }

  // ===================================================================
  // Bagian 3 — copyWith (untuk update nilai tanpa membuat object baru)
  // ===================================================================

  Task copyWith({
    int? localId,
    int? serverId,
    String? title,
    String? description,
    bool? completed,
    String? userId,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return Task(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
