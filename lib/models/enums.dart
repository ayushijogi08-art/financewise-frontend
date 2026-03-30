import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'enums.g.dart';

@HiveType(typeId: 1)
enum TransactionCategory {
  @HiveField(0) food,
  @HiveField(1) rent,
  @HiveField(2) salary,
  @HiveField(3) transport,
  @HiveField(4) health,
  @HiveField(5) entertainment,
  @HiveField(6) shopping,
  @HiveField(7) investment,
  @HiveField(8) education,
  @HiveField(9) other,
  @HiveField(10) grocery,
  @HiveField(11) adjustment,
}

// EXTENSION: The Logic to separate "Needs" vs "Wants"
extension CategoryLogic on TransactionCategory {
  bool get isFixedNeed {
    return this == TransactionCategory.rent ||
           this == TransactionCategory.education ||
           this == TransactionCategory.health ||
           this == TransactionCategory.grocery ||
           this == TransactionCategory.transport ||// Assuming commute is essential
           this == TransactionCategory.salary ||
           this == TransactionCategory.investment;
  }

  bool get isVariableWant {
    return this == TransactionCategory.food || // Eating out vs Groceries is hard to split, but usually variable
           this == TransactionCategory.entertainment ||
           this == TransactionCategory.shopping ||
           this == TransactionCategory.adjustment ||
           this == TransactionCategory.other;
  }
}

@HiveType(typeId: 2)
enum GoalStatus {
  @HiveField(0) active,
  @HiveField(1) achieved,
  @HiveField(2) abandoned
}