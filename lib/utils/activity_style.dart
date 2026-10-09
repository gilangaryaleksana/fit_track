import 'package:flutter/material.dart';

class ActivityStyle {
  final IconData icon;
  final Color color;

  /// Outdoor activities track a GPS route on a map. Indoor ones (swimming,
  /// yoga, gym) skip GPS entirely and focus on time.
  final bool usesMap;

  const ActivityStyle(this.icon, this.color, {this.usesMap = true});
}

const Map<String, ActivityStyle> _activityStyles = {
  'Lari': ActivityStyle(Icons.directions_run, Colors.orange),
  'Jalan Kaki': ActivityStyle(Icons.directions_walk, Colors.green),
  'Bersepeda': ActivityStyle(Icons.directions_bike, Colors.blue),
  'Renang': ActivityStyle(Icons.pool, Colors.cyan, usesMap: false),
  'Yoga': ActivityStyle(Icons.self_improvement, Colors.purple, usesMap: false),
  'Gym / Angkat Beban':
      ActivityStyle(Icons.fitness_center, Colors.red, usesMap: false),
};

const ActivityStyle _defaultStyle = ActivityStyle(Icons.sports, Colors.teal);

ActivityStyle styleForActivity(String name) =>
    _activityStyles[name] ?? _defaultStyle;
