import 'package:geolocator/geolocator.dart' hide ActivityType;
import '../db/database_helper.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Pushes a finished activity to the Laravel backend after it's already
/// saved locally. This is fire-and-forget: the app must keep working fully
/// offline, so any failure here is swallowed — local SQLite stays the
/// source of truth and the activity simply won't appear on the server yet.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  List<dynamic>? _serverActivityTypesCache;
  final Set<int> _syncingActivityIds = {};

  Future<int?> _serverActivityTypeId(String name) async {
    try {
      final types = _serverActivityTypesCache ??
          (await ApiClient.instance.get(
            'activity-types?per_page=50',
          ))['data'] as List<dynamic>;
      if (types.isNotEmpty) _serverActivityTypesCache = types;
      for (final t in types) {
        if ((t['name'] as String).toLowerCase() == name.toLowerCase()) {
          return t['id'] as int;
        }
      }
    } catch (_) {
      // No connection / not logged in — caller's try/catch handles this.
    }
    return null;
  }

  Future<bool> syncPendingActivities(int userId) async {
    if (!await ApiClient.instance.isLoggedIn) return false;

    final db = DatabaseHelper.instance;
    final types = await db.getActivityTypes();
    final typesById = {for (final type in types) type.id!: type};
    final pending = await db.getPendingActivitiesByUser(userId);
    var syncedAny = false;

    for (final activity in pending) {
      final type = typesById[activity.activityTypeId];
      if (type == null) continue;

      final routePoints = await db.getRoutePoints(activity.id!);
      syncedAny = await syncActivity(
            localActivityId: activity.id!,
            activity: activity,
            activityTypeName: type.name,
            routePoints: routePoints,
          ) ||
          syncedAny;
    }

    return syncedAny;
  }

  double _totalDistanceMeters(List<RoutePoint> points) {
    double total = 0;
    for (var i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  /// Removes an activity from the backend too. Without this, the next pull
  /// would bring a locally deleted activity right back. Best-effort: if
  /// we're offline it stays on the server until deleted again.
  Future<void> deleteRemote(int serverId) async {
    try {
      if (!await ApiClient.instance.isLoggedIn) return;
      await ApiClient.instance.delete('activities/$serverId');
    } catch (_) {
      // Offline or already gone — nothing else to do.
    }
  }

  Future<bool> syncActivity({
    required int localActivityId,
    required Activity activity,
    required String activityTypeName,
    List<RoutePoint> routePoints = const [],
  }) async {
    if (!_syncingActivityIds.add(localActivityId)) return false;

    try {
      final loggedIn = await ApiClient.instance.isLoggedIn;
      if (!loggedIn) return false;

      final typeId = await _serverActivityTypeId(activityTypeName);
      if (typeId == null) return false;

      final distanceMeters = _totalDistanceMeters(routePoints);
      final seconds = activity.durationMinutes * 60;
      final hasNote = activity.note != null && activity.note!.isNotEmpty;

      final body = <String, dynamic>{
        'activity_type_id': typeId,
        'title': hasNote ? activity.note : activityTypeName,
        'description': activity.note,
        'distance': distanceMeters,
        'moving_time': seconds,
        'elapsed_time': seconds,
        'start_date': activity.date.toIso8601String(),
        'calories': activity.caloriesBurned,
        'visibility': 'private',
      };

      if (routePoints.isNotEmpty) {
        body['start_lat'] = routePoints.first.latitude;
        body['start_lng'] = routePoints.first.longitude;
        body['end_lat'] = routePoints.last.latitude;
        body['end_lng'] = routePoints.last.longitude;
      }

      final created = await ApiClient.instance.post('activities', body);
      final serverActivityId = created['id'] as int;

      // Remember the link right away (before uploading the route), so this
      // activity is never pushed twice or re-imported as a duplicate later.
      await DatabaseHelper.instance
          .setActivityServerId(localActivityId, serverActivityId);

      if (routePoints.isNotEmpty) {
        final points = [
          for (var i = 0; i < routePoints.length; i++)
            {
              'sequence': i,
              'latitude': routePoints[i].latitude,
              'longitude': routePoints[i].longitude,
              'recorded_at': routePoints[i].recordedAt.toIso8601String(),
            },
        ];

        try {
          await ApiClient.instance.post('activity-streams/bulk', {
            'activity_id': serverActivityId,
            'points': points,
          });
        } catch (_) {
          // The activity itself remains synced if its route upload fails.
        }
      }
      return true;
    } catch (_) {
      // Best-effort only — see class doc comment above.
      return false;
    } finally {
      _syncingActivityIds.remove(localActivityId);
    }
  }
}