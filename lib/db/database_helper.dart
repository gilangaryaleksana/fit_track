import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'health_tracker.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRoutePointsTable(db);
    }
  }

  Future<void> _createRoutePointsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activity_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calories_per_minute REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        activity_type_id INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        calories_burned REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (activity_type_id) REFERENCES activity_types (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_targets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        target_calories REAL NOT NULL,
        target_duration_minutes INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await _createRoutePointsTable(db);
    await _seedActivityTypes(db);
  }

  Future<void> _seedActivityTypes(Database db) async {
    final defaults = [
      {'name': 'Lari', 'calories_per_minute': 10.0},
      {'name': 'Jalan Kaki', 'calories_per_minute': 4.0},
      {'name': 'Bersepeda', 'calories_per_minute': 8.0},
      {'name': 'Renang', 'calories_per_minute': 9.0},
      {'name': 'Yoga', 'calories_per_minute': 3.0},
      {'name': 'Gym / Angkat Beban', 'calories_per_minute': 6.0},
    ];
    for (final type in defaults) {
      await db.insert('activity_types', type);
    }
  }

  // ---------- USERS ----------
  Future<int> insertUser(AppUser user) async {
    final db = await database;
    return db.insert('users', user.toMap()..remove('id'));
  }

  Future<AppUser?> getUser(int id) async {
    final db = await database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return AppUser.fromMap(result.first);
  }

  // ---------- ACTIVITY TYPES ----------
  Future<List<ActivityType>> getActivityTypes() async {
    final db = await database;
    final result = await db.query('activity_types', orderBy: 'name');
    return result.map((e) => ActivityType.fromMap(e)).toList();
  }

  // ---------- ACTIVITIES ----------
  Future<int> insertActivity(Activity activity) async {
    final db = await database;
    return db.insert('activities', activity.toMap()..remove('id'));
  }

  Future<int> updateActivity(Activity activity) async {
    final db = await database;
    return db.update(
      'activities',
      activity.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<int> deleteActivity(int id) async {
    final db = await database;
    return db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Activity>> getActivitiesByUser(int userId) async {
    final db = await database;
    final result = await db.query(
      'activities',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
    return result.map((e) => Activity.fromMap(e)).toList();
  }

  Future<List<Activity>> getActivitiesByDate(int userId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.query(
      'activities',
      where: 'user_id = ? AND date LIKE ?',
      whereArgs: [userId, '$dateStr%'],
      orderBy: 'date DESC',
    );
    return result.map((e) => Activity.fromMap(e)).toList();
  }

  Future<double> getTotalCaloriesByDate(int userId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT SUM(calories_burned) as total
      FROM activities
      WHERE user_id = ? AND date LIKE ?
    ''', [userId, '$dateStr%']);
    final total = result.first['total'];
    return total == null ? 0.0 : (total as num).toDouble();
  }

  // ---------- ROUTE POINTS ----------
  Future<void> insertRoutePoints(
      int activityId, List<RoutePoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final p in points) {
      batch.insert('route_points', {
        'activity_id': activityId,
        'latitude': p.latitude,
        'longitude': p.longitude,
        'recorded_at': p.recordedAt.toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  }

  Future<List<RoutePoint>> getRoutePoints(int activityId) async {
    final db = await database;
    final result = await db.query(
      'route_points',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'recorded_at ASC',
    );
    return result.map((e) => RoutePoint.fromMap(e)).toList();
  }

  // ---------- DAILY TARGETS ----------
  Future<int> insertOrUpdateTarget(DailyTarget target) async {
    final db = await database;
    final dateStr = target.date.toIso8601String().substring(0, 10);
    final existing = await db.query(
      'daily_targets',
      where: 'user_id = ? AND date LIKE ?',
      whereArgs: [target.userId, '$dateStr%'],
    );
    if (existing.isNotEmpty) {
      return db.update(
        'daily_targets',
        target.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
    return db.insert('daily_targets', target.toMap()..remove('id'));
  }

  Future<DailyTarget?> getTargetByDate(int userId, DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final result = await db.query(
      'daily_targets',
      where: 'user_id = ? AND date LIKE ?',
      whereArgs: [userId, '$dateStr%'],
    );
    if (result.isEmpty) return null;
    return DailyTarget.fromMap(result.first);
  }
}
