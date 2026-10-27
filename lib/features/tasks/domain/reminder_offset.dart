enum ReminderOffset {
  atDueTime('At due time', 0),
  tenMinutesBefore('10 minutes before', 10),
  oneHourBefore('1 hour before', 60);

  const ReminderOffset(this.label, this.minutes);

  final String label;
  final int minutes;

  Duration get duration => Duration(minutes: minutes);

  static ReminderOffset? fromMinutes(int? minutes) {
    for (final offset in values) {
      if (offset.minutes == minutes) {
        return offset;
      }
    }
    return null;
  }
}
