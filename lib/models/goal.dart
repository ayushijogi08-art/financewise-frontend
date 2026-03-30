import 'package:uuid/uuid.dart';
import 'enums.dart'; // Ensure this points to your GoalStatus enum

class Goal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime deadline;
  final DateTime createdAt;
  final GoalStatus status;

  Goal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0.0,
    required this.deadline,
    DateTime? createdAt,
    this.status = GoalStatus.active,
  }) : createdAt = createdAt ?? DateTime.now();

  // 1. Convert an existing Flutter Goal into a copy with new values
  Goal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? deadline,
    DateTime? createdAt,
    GoalStatus? status,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }

  // ==========================================
  // 2. THE FIX: JSON TRANSLATORS FOR MONGODB
  // ==========================================

  // Convert MongoDB JSON into a Flutter Object
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['_id'] ?? const Uuid().v4(), // MongoDB uses '_id'
      name: json['name'] ?? '',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0.0,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : DateTime.now(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      // Safely parse the enum, default to active if missing
      status: json['status'] != null 
          ? GoalStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => GoalStatus.active)
          : GoalStatus.active,
    );
  }

  // Convert a Flutter Object into MongoDB JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'deadline': deadline.toIso8601String(),
      'status': status.name,
      // Note: We don't send 'id' or 'createdAt' because MongoDB generates those automatically on the server!
    };
  }

// ==========================================
  // RESTORED: THE MONTHLY REQUIREMENT MATH
  // ==========================================
  double get requiredMonthly {
    final remainingAmount = targetAmount - savedAmount;
    if (remainingAmount <= 0) return 0.0; // Goal is already met
    
    final now = DateTime.now();
    int monthsLeft = ((deadline.year - now.year) * 12) + deadline.month - now.month + 1;
    
    // Prevent division by zero if the deadline is this month or in the past
    if (monthsLeft <= 0) monthsLeft = 1; 
    
    return remainingAmount / monthsLeft;
  }

}