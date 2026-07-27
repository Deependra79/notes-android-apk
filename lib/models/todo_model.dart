import 'dart:convert';

class TodoTask {
  final String id;
  final String title;
  final DateTime? lastCompletedDate;
  final int streakCount;
  final DateTime createdAt;
  final List<DateTime> completionDates;

  TodoTask({
    required this.id,
    required this.title,
    this.lastCompletedDate,
    required this.streakCount,
    required this.createdAt,
    this.completionDates = const [],
  });

  // Determines if the task is checked off today
  bool get isCompleted {
    if (lastCompletedDate == null) return false;
    final now = DateTime.now();
    return lastCompletedDate!.year == now.year &&
        lastCompletedDate!.month == now.month &&
        lastCompletedDate!.day == now.day;
  }

  // Returns the current streak, showing 0 if the user missed yesterday
  int get currentStreak {
    if (lastCompletedDate == null) return 0;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastCompleted = DateTime(
      lastCompletedDate!.year,
      lastCompletedDate!.month,
      lastCompletedDate!.day,
    );
    
    final diffDays = today.difference(lastCompleted).inDays;
    
    // Streak is intact if it was completed today (diff 0) or yesterday (diff 1)
    if (diffDays <= 1) {
      return streakCount;
    }
    
    return 0; // Streak broken
  }

  // Toggles the completion state for today and calculates the new streak
  TodoTask toggleCompletion() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<DateTime> newHistory = List.from(completionDates);

    if (isCompleted) {
      // Currently completed today, user wants to UNCHECK.
      newHistory.removeWhere((d) => d.year == today.year && d.month == today.month && d.day == today.day);
      
      final newStreak = streakCount > 0 ? streakCount - 1 : 0;
      final yesterday = today.subtract(const Duration(days: 1));
      
      return copyWith(
        lastCompletedDate: newStreak > 0 ? yesterday : null,
        streakCount: newStreak,
        completionDates: newHistory,
        clearLastCompletedDate: newStreak == 0,
      );
    } else {
      // Currently unchecked today, user wants to CHECK.
      if (!newHistory.any((d) => d.year == today.year && d.month == today.month && d.day == today.day)) {
        newHistory.add(today);
      }

      final lastCompleted = lastCompletedDate != null
          ? DateTime(lastCompletedDate!.year, lastCompletedDate!.month, lastCompletedDate!.day)
          : null;

      int newStreak = 1;
      if (lastCompleted != null) {
        final diffDays = today.difference(lastCompleted).inDays;
        if (diffDays == 1) {
          // Completed yesterday, increment streak
          newStreak = streakCount + 1;
        } else if (diffDays == 0) {
          // Already completed today (precautionary)
          newStreak = streakCount;
        }
      }

      return copyWith(
        lastCompletedDate: now,
        streakCount: newStreak,
        completionDates: newHistory,
      );
    }
  }

  TodoTask copyWith({
    String? title,
    DateTime? lastCompletedDate,
    int? streakCount,
    List<DateTime>? completionDates,
    bool clearLastCompletedDate = false,
  }) {
    return TodoTask(
      id: id,
      title: title ?? this.title,
      lastCompletedDate: clearLastCompletedDate ? null : (lastCompletedDate ?? this.lastCompletedDate),
      streakCount: streakCount ?? this.streakCount,
      createdAt: createdAt,
      completionDates: completionDates ?? this.completionDates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
      'streak_count': streakCount,
      'created_at': createdAt.toIso8601String(),
      'completion_history': jsonEncode(completionDates.map((d) => d.toIso8601String()).toList()),
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map) {
    final historyStr = map['completion_history'] as String?;
    final List<DateTime> history = [];
    if (historyStr != null && historyStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(historyStr);
        history.addAll(decoded.map((s) => DateTime.parse(s as String)));
      } catch (_) {}
    }

    return TodoTask(
      id: map['id'] as String,
      title: map['title'] as String,
      lastCompletedDate: map['last_completed_date'] != null
          ? DateTime.parse(map['last_completed_date'] as String)
          : null,
      streakCount: map['streak_count'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      completionDates: history,
    );
  }
}
