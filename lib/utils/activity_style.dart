import 'package:flutter/material.dart';

class ActivityStyle {
  final IconData icon;
  final Color color;
  const ActivityStyle(this.icon, this.color);
}

const Map<String, ActivityStyle> _activityStyles = {
  'Lari': ActivityStyle(Icons.directions_run, Colors.orange),
  'Jalan Kaki': ActivityStyle(Icons.directions_walk, Colors.green),
  'Bersepeda': ActivityStyle(Icons.directions_bike, Colors.blue),
  'Renang': ActivityStyle(Icons.pool, Colors.cyan),
  'Yoga': ActivityStyle(Icons.self_improvement, Colors.purple),
  'Gym / Angkat Beban': ActivityStyle(Icons.fitness_center, Colors.red),
};

const ActivityStyle _defaultStyle = ActivityStyle(Icons.sports, Colors.teal);

ActivityStyle styleForActivity(String name) =>
    _activityStyles[name] ?? _defaultStyle;
