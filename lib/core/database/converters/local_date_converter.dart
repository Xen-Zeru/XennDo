import 'package:drift/drift.dart';
import 'package:xenndo/core/time/local_date.dart';

class LocalDateConverter extends TypeConverter<LocalDate, int> {
  const LocalDateConverter();

  @override
  LocalDate fromSql(int fromDb) => LocalDate.fromEpochDay(fromDb);

  @override
  int toSql(LocalDate value) => value.epochDay;
}
