// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MonthlyStatsAdapter extends TypeAdapter<MonthlyStats> {
  @override
  final int typeId = 3;

  @override
  MonthlyStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyStats(
      monthKey: fields[0] as String,
      totalIncome: fields[1] as double,
      totalExpense: fields[2] as double,
      rolloverAmount: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyStats obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.monthKey)
      ..writeByte(1)
      ..write(obj.totalIncome)
      ..writeByte(2)
      ..write(obj.totalExpense)
      ..writeByte(3)
      ..write(obj.rolloverAmount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
