import 'package:geolocator/geolocator.dart' hide ActivityType;
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

  Future<int?> _serverActivityTypeId(String name) async {
    try {
      _serverActivityTypesCache ??= (await ApiClient.instance
          .get('activity-types?per_page=50'))['data'] as List<dynamic>;
      for (final t in _serverActivityTypesCache!) {
        if ((t['name'] as String).toLowerCase() == name.toLowerCase()) {
          return t['id'] as int;
        }
      }
    } catch (_) {
      // No connection / not logged in — caller's try/catch handles this.
    }
    return null;
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

  Future<void> syncActivity({
    required Activity activity,
    required String activityTypeName,
    List<RoutePoint> routePoints = const [],
  }) async {
    try {
      final loggedIn = await ApiClient.instance.isLoggedIn;
      if (!loggedIn) return;

      final typeId = await _serverActivityTypeId(activityTypeName);
      if (typeId == null) return;

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

        await ApiClient.instance.post('activity-streams/bulk', {
          'activity_id': serverActivityId,
          'points': points,
        });
      }
    } catch (_) {
      // Best-effort only — see class doc comment above.
    }
  }
}
