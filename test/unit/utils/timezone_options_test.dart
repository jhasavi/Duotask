import 'package:flutter_test/flutter_test.dart';
import 'package:evenhalf/utils/timezone_options.dart';

void main() {
  // Fixed instants so DST-observing zones have a known offset.
  final january = DateTime.utc(2026, 1, 15, 12);
  final july = DateTime.utc(2026, 7, 15, 12);

  group('formatUtcOffset', () {
    test('formats whole-hour offsets with sign and zero padding', () {
      expect(formatUtcOffset(const Duration(hours: 5)), 'UTC+05:00');
      expect(formatUtcOffset(const Duration(hours: -4)), 'UTC-04:00');
      expect(formatUtcOffset(Duration.zero), 'UTC+00:00');
    });

    test('formats half- and quarter-hour offsets', () {
      expect(
        formatUtcOffset(const Duration(hours: 5, minutes: 30)),
        'UTC+05:30',
      );
      expect(
        formatUtcOffset(const Duration(hours: 5, minutes: 45)),
        'UTC+05:45',
      );
      expect(
        formatUtcOffset(const Duration(hours: -9, minutes: -30)),
        'UTC-09:30',
      );
    });
  });

  group('loadTimezoneOptions', () {
    test('computes offsets at the given instant, including DST', () {
      final winter = loadTimezoneOptions(at: january);
      final summer = loadTimezoneOptions(at: july);

      Duration offsetOf(List<TimezoneOption> o, String name) =>
          o.firstWhere((e) => e.name == name).offset;

      expect(offsetOf(winter, 'America/New_York'), const Duration(hours: -5));
      expect(offsetOf(summer, 'America/New_York'), const Duration(hours: -4));
      expect(
        offsetOf(winter, 'Asia/Kolkata'),
        const Duration(hours: 5, minutes: 30),
      );
    });

    test('includes UTC and real city zones', () {
      final names = loadTimezoneOptions(at: january).map((o) => o.name);
      expect(names, containsAll(['UTC', 'Europe/London', 'Asia/Tokyo']));
    });

    test('hides legacy country-prefixed aliases and bare names like GMT', () {
      final names = loadTimezoneOptions(at: january).map((o) => o.name);
      for (final name in names) {
        expect(name == 'UTC' || name.contains('/'), isTrue, reason: name);
        for (final prefix in ['US/', 'Canada/']) {
          expect(name.startsWith(prefix), isFalse, reason: name);
        }
      }
      expect(names, isNot(contains('GMT')));
    });

    test('is sorted by name', () {
      final names =
          loadTimezoneOptions(at: january).map((o) => o.name).toList();
      expect(names, [...names]..sort());
    });
  });

  group('filterTimezones', () {
    final options = loadTimezoneOptions(at: july);

    test('empty query returns everything', () {
      expect(filterTimezones(options, ''), options);
      expect(filterTimezones(options, '   '), options);
    });

    test('matches names case-insensitively, treating underscores as spaces',
        () {
      expect(
        filterTimezones(options, 'new york').map((o) => o.name),
        contains('America/New_York'),
      );
      expect(
        filterTimezones(options, 'KOLKATA').map((o) => o.name),
        contains('Asia/Kolkata'),
      );
    });

    test('matches offsets with or without zero padding', () {
      final padded = filterTimezones(options, 'utc+05:30').map((o) => o.name);
      final loose = filterTimezones(options, '+5:30').map((o) => o.name);
      expect(padded, contains('Asia/Kolkata'));
      expect(loose, contains('Asia/Kolkata'));
      expect(loose, isNot(contains('America/New_York')));
    });

    test('July offset search finds DST zones at their current offset', () {
      expect(
        filterTimezones(options, 'utc-04:00').map((o) => o.name),
        contains('America/New_York'),
      );
    });

    test('no match returns an empty list', () {
      expect(filterTimezones(options, 'zzzz-not-a-zone'), isEmpty);
    });
  });

  group('timezoneLabel', () {
    test('labels a known zone with its offset at the given instant', () {
      expect(
        timezoneLabel('America/New_York', at: july),
        'America/New_York (UTC-04:00)',
      );
      expect(
        timezoneLabel('America/New_York', at: january),
        'America/New_York (UTC-05:00)',
      );
    });

    test('decodes the Etc/GMT default with the POSIX-inverted sign', () {
      // The timezone package has no Etc/* zones, so these are decoded from
      // the name. Etc/GMT-5 is UTC+5 — the same inversion
      // EmailPreferencesService.deviceOffsetTimezone applies when it writes
      // them.
      expect(timezoneLabel('Etc/GMT-5'), 'Etc/GMT-5 (UTC+05:00)');
      expect(timezoneLabel('Etc/GMT+5'), 'Etc/GMT+5 (UTC-05:00)');
      expect(timezoneLabel('Etc/GMT-14'), 'Etc/GMT-14 (UTC+14:00)');
      expect(timezoneLabel('Etc/GMT+12'), 'Etc/GMT+12 (UTC-12:00)');
    });

    test('does not treat near-miss names as Etc/GMT', () {
      expect(timezoneLabel('Etc/GMT-5:30'), 'Etc/GMT-5:30');
      expect(timezoneLabel('Etc/GMT'), 'Etc/GMT');
    });

    test('returns just the name when the zone is unknown', () {
      expect(timezoneLabel('Mars/Olympus_Mons'), 'Mars/Olympus_Mons');
    });
  });
}
