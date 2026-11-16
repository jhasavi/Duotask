import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One selectable IANA timezone, with its UTC offset at a given instant.
class TimezoneOption {
  final String name;
  final Duration offset;

  const TimezoneOption(this.name, this.offset);

  String get offsetLabel => formatUtcOffset(offset);
  String get label => '$name ($offsetLabel)';
}

/// "UTC+05:30", "UTC-04:00", "UTC+00:00".
String formatUtcOffset(Duration offset) {
  final totalMinutes = offset.inMinutes;
  final sign = totalMinutes < 0 ? '-' : '+';
  final abs = totalMinutes.abs();
  final hh = (abs ~/ 60).toString().padLeft(2, '0');
  final mm = (abs % 60).toString().padLeft(2, '0');
  return 'UTC$sign$hh:$mm';
}

// The package's database carries a few legacy country-prefixed aliases
// (US/Eastern alongside America/New_York, Canada/Pacific alongside
// America/Vancouver) that duplicate real city zones and clutter the list.
// It has no Etc/* zones at all — see [timezoneLabel] for how those resolve.
const _hiddenPrefixes = ['US/', 'Canada/'];

bool _isSelectable(String name) {
  if (name == 'UTC') return true;
  if (!name.contains('/')) return false;
  return !_hiddenPrefixes.any(name.startsWith);
}

/// All selectable zones, sorted by name, with offsets computed at [at]
/// (defaults to now, so DST-observing zones show their current offset).
///
/// Names come from the `timezone` package's IANA database, and the server
/// validates writes against `pg_timezone_names` (see the
/// `email_preferences_timezone_check` trigger), so a zone the server doesn't
/// know is rejected there with a readable error rather than silently stored.
List<TimezoneOption> loadTimezoneOptions({DateTime? at}) {
  if (!tz.timeZoneDatabase.isInitialized) {
    tzdata.initializeTimeZones();
  }
  final instant = at ?? DateTime.now();
  final options = <TimezoneOption>[];
  for (final entry in tz.timeZoneDatabase.locations.entries) {
    if (!_isSelectable(entry.key)) continue;
    final offset = tz.TZDateTime.from(instant, entry.value).timeZoneOffset;
    options.add(TimezoneOption(entry.key, offset));
  }
  options.sort((a, b) => a.name.compareTo(b.name));
  return options;
}

/// Case-insensitive search over the zone name (underscores read as spaces, so
/// "new york" finds America/New_York) and its offset ("+5:30", "utc-04").
List<TimezoneOption> filterTimezones(
  List<TimezoneOption> options,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return options;
  return options.where((o) {
    final name = o.name.toLowerCase().replaceAll('_', ' ');
    if (name.contains(q)) return true;
    final offset = o.offsetLabel.toLowerCase();
    // "+5:30" should match "utc+05:30": compare with the zero-padding removed.
    final loose = offset.replaceAll('+0', '+').replaceAll('-0', '-');
    return offset.contains(q) || loose.contains(q);
  }).toList();
}

final _etcGmt = RegExp(r'^Etc/GMT([+-])(\d{1,2})$');

/// "America/New_York (UTC-04:00)" for any zone we can resolve, and just
/// [name] if we can't, rather than inventing an offset.
///
/// This includes the `Etc/GMT±N` default a new account is given
/// (`EmailPreferencesService.deviceOffsetTimezone`). The `timezone` package
/// doesn't carry Etc/* zones, so those are decoded from the name — with the
/// POSIX inversion, where `Etc/GMT-5` is UTC+5.
String timezoneLabel(String name, {DateTime? at}) {
  final etc = _etcGmt.firstMatch(name);
  if (etc != null) {
    final hours = int.parse(etc.group(2)!);
    final east = etc.group(1) == '-';
    return TimezoneOption(
      name,
      Duration(hours: east ? hours : -hours),
    ).label;
  }

  if (!tz.timeZoneDatabase.isInitialized) {
    tzdata.initializeTimeZones();
  }
  try {
    final location = tz.getLocation(name);
    final offset =
        tz.TZDateTime.from(at ?? DateTime.now(), location).timeZoneOffset;
    return TimezoneOption(name, offset).label;
  } catch (_) {
    return name;
  }
}
