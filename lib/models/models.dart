class AppUser {
  final int? id;
  final String name;
  final String email;
  final double heightCm;
  final double weightKg;

  AppUser({
    this.id,
    required this.name,
    required this.email,
    required this.heightCm,
    required this.weightKg,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'height_cm': heightCm,
        'weight_kg': weightKg,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as int?,
        name: map['name'] as String,
        email: map['email'] as String,
        heightCm: (map['height_cm'] as num).toDouble(),
        weightKg: (map['weight_kg'] as num).toDouble(),
      );
}

class ActivityType {
  final int? id;
  final String name;
  final double caloriesPerMinute;

  ActivityType({
    this.id,
    required this.name,
    required this.caloriesPerMinute,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'calories_per_minute': caloriesPerMinute,
      };

  factory ActivityType.fromMap(Map<String, dynamic> map) => ActivityType(
        id: map['id'] as int?,
        name: map['name'] as String,
        caloriesPerMinute: (map['calories_per_minute'] as num).toDouble(),
      );
}

class Activity {
  final int? id;
  final int userId;
  final int activityTypeId;
  final int durationMinutes;
  final double caloriesBurned;
  final DateTime date;
  final String? note;

  Activity({
    this.id,
    required this.userId,
    required this.activityTypeId,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'activity_type_id': activityTypeId,
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Activity.fromMap(Map<String, dynamic> map) => Activity(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        activityTypeId: map['activity_type_id'] as int,
        durationMinutes: map['duration_minutes'] as int,
        caloriesBurned: (map['calories_burned'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String?,
      );
}

class RoutePoint {
  final int? id;
  final int activityId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  RoutePoint({
    this.id,
    required this.activityId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'activity_id': activityId,
        'latitude': latitude,
        'longitude': longitude,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory RoutePoint.fromMap(Map<String, dynamic> map) => RoutePoint(
        id: map['id'] as int?,
        activityId: map['activity_id'] as int,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        recordedAt: DateTime.parse(map['recorded_at'] as String),
      );
}

class DailyTarget {
  final int? id;
  final int userId;
  final double targetCalories;
  final int targetDurationMinutes;
  final DateTime date;

  DailyTarget({
    this.id,
    required this.userId,
    required this.targetCalories,
    required this.targetDurationMinutes,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'target_calories': targetCalories,
        'target_duration_minutes': targetDurationMinutes,
        'date': date.toIso8601String(),
      };

  factory DailyTarget.fromMap(Map<String, dynamic> map) => DailyTarget(
        id: map['id'] as int?,
        userId: map['user_id'] as int,
        targetCalories: (map['target_calories'] as num).toDouble(),
        targetDurationMinutes: map['target_duration_minutes'] as int,
        date: DateTime.parse(map['date'] as String),
      );
}
