import 'package:flutter_test/flutter_test.dart';
import 'package:health_tracker/services/settings_service.dart';
import 'package:health_tracker/utils/unit_formatter.dart';

void main() {
  test('formats distance and pace using the selected units', () {
    final settings = SettingsService.instance;
    settings.distanceUnit = DistanceUnit.kilometer;
    expect(UnitFormatter.formatDistance(1500), '1.50 km');

    settings.distanceUnit = DistanceUnit.mile;
    expect(UnitFormatter.formatDistance(1609.344), '1.00 mil');

    settings.paceUnit = PaceUnit.minutePerMile;
    expect(
      UnitFormatter.formatPace(
        distanceMeters: 1609.344,
        elapsed: const Duration(minutes: 10),
      ),
      "10'00\"",
    );
    expect(UnitFormatter.paceUnitLabel, '/mil');

    settings.distanceUnit = DistanceUnit.kilometer;
    settings.paceUnit = PaceUnit.minutePerKilometer;
  });
}
