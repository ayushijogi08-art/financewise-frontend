// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'enums.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionCategoryAdapter extends TypeAdapter<TransactionCategory> {
  @override
  final int typeId = 1;

  @override
  TransactionCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TransactionCategory.food;
      case 1:
        return TransactionCategory.rent;
      case 2:
        return TransactionCategory.salary;
      case 3:
        return TransactionCategory.transport;
      case 4:
        return TransactionCategory.health;
      case 5:
        return TransactionCategory.entertainment;
      case 6:
        return TransactionCategory.shopping;
      case 7:
        return TransactionCategory.investment;
      case 8:
        return TransactionCategory.education;
      case 9:
        return TransactionCategory.other;
      case 10:
        return TransactionCategory.grocery;
      case 11:
        return TransactionCategory.adjustment;
      default:
        return TransactionCategory.food;
    }
  }

  @override
  void write(BinaryWriter writer, TransactionCategory obj) {
    switch (obj) {
      case TransactionCategory.food:
        writer.writeByte(0);
        break;
      case TransactionCategory.rent:
        writer.writeByte(1);
        break;
      case TransactionCategory.salary:
        writer.writeByte(2);
        break;
      case TransactionCategory.transport:
        writer.writeByte(3);
        break;
      case TransactionCategory.health:
        writer.writeByte(4);
        break;
      case TransactionCategory.entertainment:
        writer.writeByte(5);
        break;
      case TransactionCategory.shopping:
        writer.writeByte(6);
        break;
      case TransactionCategory.investment:
        writer.writeByte(7);
        break;
      case TransactionCategory.education:
        writer.writeByte(8);
        break;
      case TransactionCategory.other:
        writer.writeByte(9);
        break;
      case TransactionCategory.grocery:
        writer.writeByte(10);
        break;
      case TransactionCategory.adjustment:
        writer.writeByte(11);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GoalStatusAdapter extends TypeAdapter<GoalStatus> {
  @override
  final int typeId = 2;

  @override
  GoalStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return GoalStatus.active;
      case 1:
        return GoalStatus.achieved;
      case 2:
        return GoalStatus.abandoned;
      default:
        return GoalStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, GoalStatus obj) {
    switch (obj) {
      case GoalStatus.active:
        writer.writeByte(0);
        break;
      case GoalStatus.achieved:
        writer.writeByte(1);
        break;
      case GoalStatus.abandoned:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoalStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
