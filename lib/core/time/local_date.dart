/// A calendar date without a time zone or time of day.
///
/// Date-only task deadlines are stored as epoch days derived from the calendar
/// fields. They therefore keep the same selected calendar date regardless of
/// the device's current time zone.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate._(this.year, this.month, this.day);

  factory LocalDate(int year, int month, int day) {
    final utcDate = DateTime.utc(year, month, day);
    if (utcDate.year != year || utcDate.month != month || utcDate.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Not a valid calendar date',
      );
    }

    return LocalDate._(year, month, day);
  }

  factory LocalDate.fromDateTime(DateTime dateTime) {
    return LocalDate(dateTime.year, dateTime.month, dateTime.day);
  }

  factory LocalDate.fromEpochDay(int epochDay) {
    final utcDate = DateTime.utc(1970, 1, 1).add(Duration(days: epochDay));
    return LocalDate(utcDate.year, utcDate.month, utcDate.day);
  }

  factory LocalDate.today([DateTime? now]) {
    return LocalDate.fromDateTime(now ?? DateTime.now());
  }

  final int year;
  final int month;
  final int day;

  int get epochDay {
    final milliseconds = DateTime.utc(year, month, day).millisecondsSinceEpoch;
    return (milliseconds / Duration.millisecondsPerDay).floor();
  }

  DateTime toLocalDateTime({int hour = 0, int minute = 0}) {
    return DateTime(year, month, day, hour, minute);
  }

  LocalDate addDays(int days) {
    return LocalDate.fromEpochDay(epochDay + days);
  }

  bool isBefore(LocalDate other) => compareTo(other) < 0;

  bool isAfter(LocalDate other) => compareTo(other) > 0;

  String toIso8601String() {
    final monthText = month.toString().padLeft(2, '0');
    final dayText = day.toString().padLeft(2, '0');
    return '$year-$monthText-$dayText';
  }

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) {
      return year.compareTo(other.year);
    }
    if (month != other.month) {
      return month.compareTo(other.month);
    }
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) {
    return other is LocalDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso8601String();
}
