import '../db/database_helper.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Restores activity history from the backend into local SQLite — the
/// counterpart to [SyncService], which only ever pushes. Runs after
/// login/register so a reinstalled app (or a fresh device) gets its
/// history back, matched by activity type **name** since local and server
/// ids are independent, and deduplicated via the local `server_id` column.
class PullSyncService {
  PullSyncService._();
  static final PullSyncService instance = PullSyncService._();

  final _db = DatabaseHelper.instance;

  Future<void> pullActivities(int localUserId) async {
    try {
      final loggedIn = await ApiClient.instance.isLoggedIn;
      if (!loggedIn) return;

      final localTypes = await _db.getActivityTypes();
      final typeIdByName = {
        for (final t in localTypes) t.name.toLowerCase(): t.id!,
      };

      var page = 1;
      while (true) {
        final res = await ApiClient.instance.get('activities?per_page=50&page=$page');
        final items = (res['data'] as List).cast<Map<String, dynamic>>();

        for (final item in items) {
          await _importOne(item, localUserId, typeIdByName);
        }

        final currentPage = res['current_page'] as int? ?? 1;
        final lastPage = res['last_page'] as int? ?? 1;
        if (currentPage >= lastPage) break;
        page++;
      }
    } catch (_) {
      // Best-effort: offline, not logged in yet, or nothing to restore.
      // Local SQLite is unaffected either way.
    }
  }

  Future<void> _importOne(
    Map<String, dynamic> item,
    int localUserId,
    Map<String, int> typeIdByName,
  ) async {
    final serverId = item['id'] as int;

    final alreadySynced = await _db.getLocalIdByServerId(serverId);
    if (alreadySynced != null) return;

    final typeName =
        (item['activity_type']?['name'] as String?)?.toLowerCase();
    final localTypeId = typeName != null ? typeIdByName[typeName] : null;
    if (localTypeId == null) return;

    final movingSeconds = ((item['moving_time'] as num?)?.toInt() ??
            (item['elapsed_time'] as num?)?.toInt() ??
            60)
        .clamp(60, 1 << 30);

    final description = item['description'] as String?;

    final activity = Activity(
      userId: localUserId,
      activityTypeId: localTypeId,
      durationMinutes: (movingSeconds / 60).round().clamp(1, 999999),
      caloriesBurned: (item['calories'] as num?)?.toDouble() ?? 0,
      date: DateTime.parse(item['start_date'] as String),
      note: (description != null && description.isNotEmpty) ? description : null,
    );

    final localId = await _db.insertActivityFromServer(activity, serverId);

    await _importRoute(serverId, localId);
  }

  Future<void> _importRoute(int serverActivityId, int localActivityId) async {
    try {
      final points = await ApiClient.instance
          .get('activity-streams?activity_id=$serverActivityId') as List;
      if (points.isEmpty) return;

      final routePoints = points
          .cast<Map<String, dynamic>>()
          .map((p) => RoutePoint(
                activityId: localActivityId,
                latitude: (p['latitude'] as num).toDouble(),
                longitude: (p['longitude'] as num).toDouble(),
                recordedAt: DateTime.parse(p['recorded_at'] as String),
              ))
          .toList();

      await _db.insertRoutePoints(localActivityId, routePoints);
    } catch (_) {
      // Route is a nice-to-have; the activity itself already got imported.
    }
  }
}