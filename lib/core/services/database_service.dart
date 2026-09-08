import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../../features/daily_routine/domain/models/routine_task.dart';
import '../../features/daily_routine/domain/models/task_type.dart';
import '../../features/daily_routine/domain/models/time_log.dart';

/// Singleton service managing SQLite local database storage for Nooktime.
class DatabaseService {
  static const String _dbName = 'nooktime.db';
  static const int _dbVersion = 4;

  static const String tableRoutineTasks = 'routine_tasks';
  static const String tableTimeLogs = 'time_logs';

  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService.forTest();

  /// Access singleton instance of [DatabaseService].
  factory DatabaseService() {
    _instance ??= DatabaseService.forTest();
    return _instance!;
  }

  /// Returns active SQLite [Database] instance, initializing if necessary.
  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await openDatabase(
        _dbName,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL;');
          await db.rawQuery('PRAGMA synchronous = NORMAL;');
          await db.rawQuery('PRAGMA cache_size = -2000;');
          await db.rawQuery('PRAGMA temp_store = MEMORY;');
        } catch (_) {}
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create routine_tasks table with task_type & days_of_week columns
    await db.execute('''
      CREATE TABLE $tableRoutineTasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        start_time TEXT NOT NULL,
        duration_minutes INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        task_type TEXT NOT NULL DEFAULT 'routine',
        google_event_id TEXT,
        updated_at TEXT NOT NULL,
        last_completed_date TEXT,
        days_of_week TEXT DEFAULT '1,2,3,4,5,6,7'
      )
    ''');

    // Index on updated_at for fast sync conflict resolution and query filtering
    await db.execute('''
      CREATE INDEX idx_routine_tasks_updated_at 
      ON $tableRoutineTasks(updated_at)
    ''');

    // Index on task_type for filtering routines vs reminders
    await db.execute('''
      CREATE INDEX idx_routine_tasks_type 
      ON $tableRoutineTasks(task_type)
    ''');

    // Create time_logs table
    await db.execute('''
      CREATE TABLE $tableTimeLogs (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        duration_spent_minutes INTEGER NOT NULL,
        FOREIGN KEY (task_id) REFERENCES $tableRoutineTasks (id) ON DELETE CASCADE
      )
    ''');

    // Index on timestamp for fast date range filtering in analytics
    await db.execute('''
      CREATE INDEX idx_time_logs_timestamp 
      ON $tableTimeLogs(timestamp)
    ''');

    // Index on task_id for efficient queries by task
    await db.execute('''
      CREATE INDEX idx_time_logs_task_id 
      ON $tableTimeLogs(task_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE $tableRoutineTasks 
        ADD COLUMN task_type TEXT NOT NULL DEFAULT 'routine'
      ''');

      await db.execute('''
        CREATE INDEX idx_routine_tasks_type 
        ON $tableRoutineTasks(task_type)
      ''');
    }
    if (oldVersion < 3) {
      // Add last_completed_date for midnight auto-reset tracking.
      await db.execute('''
        ALTER TABLE $tableRoutineTasks 
        ADD COLUMN last_completed_date TEXT
      ''');
    }
    if (oldVersion < 4) {
      // Add days_of_week for day-specific routine scheduling.
      await db.execute('''
        ALTER TABLE $tableRoutineTasks 
        ADD COLUMN days_of_week TEXT DEFAULT '1,2,3,4,5,6,7'
      ''');
    }
  }

  // ---------------------------------------------------------------------------
  // ROUTINE TASKS & REMINDERS CRUD METHODS
  // ---------------------------------------------------------------------------

  /// Inserts a new [RoutineTask] into the database.
  Future<int> insertTask(RoutineTask task) async {
    final db = await database;
    return await db.insert(
      tableRoutineTasks,
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Upserts a [RoutineTask] into local SQLite database (alias for insertTask with ConflictAlgorithm.replace).
  Future<int> upsertTask(RoutineTask task) => insertTask(task);

  /// Updates an existing [RoutineTask].
  Future<int> updateTask(RoutineTask task) async {
    final db = await database;
    return await db.update(
      tableRoutineTasks,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Deletes a task by its [id].
  Future<int> deleteTask(String id) async {
    final db = await database;
    return await db.delete(
      tableRoutineTasks,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Retrieves all tasks from the database ordered by startTime.
  Future<List<RoutineTask>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableRoutineTasks,
      orderBy: 'start_time ASC',
    );
    return maps.map((map) => RoutineTask.fromMap(map)).toList();
  }

  /// Retrieves tasks filtered by [TaskType].
  Future<List<RoutineTask>> getTasksByType(TaskType type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableRoutineTasks,
      where: 'task_type = ?',
      whereArgs: [type.toSqlValue()],
      orderBy: 'start_time ASC',
    );
    return maps.map((map) => RoutineTask.fromMap(map)).toList();
  }

  /// Retrieves routine tasks active for a specific weekday (1 = Monday, ..., 7 = Sunday).
  Future<List<RoutineTask>> getTasksForDay(int weekday) async {
    final routines = await getTasksByType(TaskType.routine);
    return routines.where((task) => task.isScheduledForDay(weekday)).toList();
  }

  /// Retrieves local-only daily routine tasks for today's weekday.
  Future<List<RoutineTask>> getTodayRoutines() async {
    final todayWeekday = DateTime.now().weekday;
    return await getTasksForDay(todayWeekday);
  }

  /// Retrieves reminders.
  Future<List<RoutineTask>> getReminders() async {
    return await getTasksByType(TaskType.reminder);
  }

  /// Retrieves a single [RoutineTask] by its [id].
  Future<RoutineTask?> getTaskById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableRoutineTasks,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return RoutineTask.fromMap(maps.first);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // TIME LOGS CRUD METHODS
  // ---------------------------------------------------------------------------

  /// Inserts a new [TimeLog].
  Future<int> insertTimeLog(TimeLog log) async {
    final db = await database;
    return await db.insert(
      tableTimeLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all [TimeLog] entries within a date range [start] to [end].
  Future<List<TimeLog>> getTimeLogsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final startIso = start.toUtc().toIso8601String();
    final endIso = end.toUtc().toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      tableTimeLogs,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startIso, endIso],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => TimeLog.fromMap(map)).toList();
  }

  /// Deletes a time log entry by [id].
  Future<int> deleteTimeLog(String id) async {
    final db = await database;
    return await db.delete(
      tableTimeLogs,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // BATCH TRANSACTIONS & BULK SYNCHRONIZATION HELPERS
  // ---------------------------------------------------------------------------

  /// Executes bulk task insertions/updates inside an atomic batch transaction.
  Future<void> batchSyncTasks(List<RoutineTask> tasks) async {
    final db = await database;
    final batch = db.batch();

    for (final task in tasks) {
      batch.insert(
        tableRoutineTasks,
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Atomically deletes multiple tasks by their IDs in a single SQLite batch transaction.
  /// Far faster than N individual deleteTask() calls for bulk deletion.
  Future<void> batchDeleteTasks(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in ids) {
      batch.delete(tableRoutineTasks, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  /// Atomically inserts multiple tasks in a single SQLite batch transaction.
  /// Used for batch undo/restore.
  Future<void> batchInsertTasks(List<RoutineTask> tasks) async {
    if (tasks.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final task in tasks) {
      batch.insert(
        tableRoutineTasks,
        task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Atomically updates multiple tasks in a single SQLite batch transaction.
  Future<void> batchUpdateTasks(List<RoutineTask> tasks) async {
    if (tasks.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final task in tasks) {
      batch.update(
        tableRoutineTasks,
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Executes bulk insertion of [TimeLog] items inside an atomic batch transaction.
  Future<void> batchInsertTimeLogs(List<TimeLog> logs) async {
    final db = await database;
    final batch = db.batch();

    for (final log in logs) {
      batch.insert(
        tableTimeLogs,
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Clears all tables in the database (useful for resetting data or testing).
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(tableTimeLogs);
      await txn.delete(tableRoutineTasks);
    });
  }

  /// Closes the database connection.
  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
