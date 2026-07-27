import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/todo_model.dart';
import '../services/database_helper.dart';

class TodoStreakScreen extends StatefulWidget {
  const TodoStreakScreen({super.key});

  @override
  State<TodoStreakScreen> createState() => _TodoStreakScreenState();
}

class _TodoStreakScreenState extends State<TodoStreakScreen> {
  List<TodoTask> _tasks = [];
  bool _isLoading = true;

  // Calendar visualization states
  String _selectedFilter = 'all';
  String _calendarView = 'month';
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });
    final tasks = await DatabaseHelper.instance.getAllTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _addTask(String title) async {
    if (title.trim().isEmpty) return;

    final newTask = TodoTask(
      id: const Uuid().v4(),
      title: title.trim(),
      streakCount: 0,
      createdAt: DateTime.now(),
    );

    await DatabaseHelper.instance.insertTask(newTask);
    _loadTasks();
  }

  Future<void> _toggleTaskCompletion(TodoTask task) async {
    final updated = task.toggleCompletion();
    await DatabaseHelper.instance.updateTask(updated);
    _loadTasks();
  }

  Future<void> _editTaskTitle(TodoTask task, String newTitle) async {
    if (newTitle.trim().isEmpty) return;
    final updated = task.copyWith(title: newTitle.trim());
    await DatabaseHelper.instance.updateTask(updated);
    _loadTasks();
  }

  Future<void> _deleteTask(TodoTask task) async {
    await DatabaseHelper.instance.deleteTask(task.id);
    _loadTasks();
  }

  void _showAddDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Daily Goal / Habit'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Read 15 pages, Drink 3L water...',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _addTask(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(TodoTask task) {
    final controller = TextEditingController(text: task.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Daily Goal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _editTaskTitle(task, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- CALENDAR DATA HELPER METHODS ---

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  double _getCompletionValueForDay(DateTime date) {
    if (_tasks.isEmpty) return 0.0;
    final midnightDate = DateTime(date.year, date.month, date.day);

    if (_selectedFilter == 'all') {
      // Find tasks that were created on or before this date
      final activeTasks = _tasks.where((t) {
        final createdMidnight = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
        return createdMidnight.isBefore(midnightDate) || createdMidnight.isAtSameMomentAs(midnightDate);
      }).toList();

      if (activeTasks.isEmpty) return 0.0;

      final completedCount = activeTasks.where((t) {
        return t.completionDates.any((d) => _isSameDay(d, midnightDate));
      }).length;

      return completedCount / activeTasks.length;
    } else {
      final taskIndex = _tasks.indexWhere((t) => t.id == _selectedFilter);
      if (taskIndex == -1) return 0.0;
      final task = _tasks[taskIndex];
      final isCompletedOnDay = task.completionDates.any((d) => _isSameDay(d, midnightDate));
      return isCompletedOnDay ? 1.0 : 0.0;
    }
  }

  Color _getHeatmapColor(double val, ThemeData theme, bool isDark) {
    if (isDark) {
      if (val <= 0.35) return const Color(0xFF374151); // Dark Slate Grey
      if (val <= 0.75) return const Color(0xFF9CA3AF); // Medium Silver Grey
      return const Color(0xFFF3F4F6); // Bright Silver White
    } else {
      if (val <= 0.35) return const Color(0xFFA7F3D0); // Soft Light Green
      if (val <= 0.75) return const Color(0xFF34D399); // Medium Mint Green
      return const Color(0xFF047857); // Deep Emerald Green
    }
  }

  List<Map<String, dynamic>> _getGoalsStatusForDay(DateTime date) {
    final midnightDate = DateTime(date.year, date.month, date.day);
    // Find all tasks active on this day
    final activeTasks = _tasks.where((t) {
      final createdMidnight = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      return createdMidnight.isBefore(midnightDate) || createdMidnight.isAtSameMomentAs(midnightDate);
    }).toList();

    return activeTasks.map((t) {
      final isCompletedOnDay = t.completionDates.any((d) => _isSameDay(d, midnightDate));
      return {
        'task': t,
        'completed': isCompletedOnDay,
      };
    }).toList();
  }

  String _getTooltipText(DateTime date) {
    final statusList = _getGoalsStatusForDay(date);
    if (statusList.isEmpty) return 'No active goals';

    final completed = statusList
        .where((item) => item['completed'] as bool)
        .map((item) => '✓ ${(item['task'] as TodoTask).title}')
        .toList();
    final pending = statusList
        .where((item) => !(item['completed'] as bool))
        .map((item) => '✗ ${(item['task'] as TodoTask).title}')
        .toList();

    final buffer = StringBuffer();
    if (completed.isNotEmpty) {
      buffer.writeln('Completed:');
      buffer.writeln(completed.join('\n'));
    }
    if (pending.isNotEmpty) {
      if (completed.isNotEmpty) buffer.writeln();
      buffer.writeln('Pending:');
      buffer.writeln(pending.join('\n'));
    }
    return buffer.toString();
  }

  void _showDayStatusDialog(DateTime date, ThemeData theme) {
    final statusList = _getGoalsStatusForDay(date);
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);

    showDialog(
      context: context,
      builder: (context) {
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Goal Breakdown',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          content: statusList.isEmpty
              ? const Text('No active goals on this day.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: statusList.length,
                    itemBuilder: (context, idx) {
                      final item = statusList[idx];
                      final task = item['task'] as TodoTask;
                      final completed = item['completed'] as bool;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              completed ? Icons.check_circle : Icons.cancel,
                              color: completed
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.grey[700] : Colors.grey[300]),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                task.title,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  decoration: completed ? TextDecoration.lineThrough : null,
                                  color: completed ? Colors.grey : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // --- CALENDAR WIDGETS ---

  Widget _buildGoalSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedFilter = val;
              });
            }
          },
          items: [
            const DropdownMenuItem(
              value: 'all',
              child: Text('All Goals'),
            ),
            ..._tasks.map((t) => DropdownMenuItem(
                  value: t.id,
                  child: SizedBox(
                    width: 100,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSwitcher(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: ['week', 'month', 'year'].map((v) {
          final isSelected = _calendarView == v;
          return GestureDetector(
            onTap: () {
              setState(() {
                _calendarView = v;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.grey[800] : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected && !isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                v.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : theme.colorScheme.primary)
                      : Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekView(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekDays = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.map((date) {
        final isCurrentDay = _isSameDay(date, today);
        final dayName = DateFormat('E').format(date).substring(0, 1);
        final dayNum = date.day.toString();

        final completionValue = _getCompletionValueForDay(date);

        Color badgeColor = Colors.transparent;
        Color borderColors = Colors.grey.withValues(alpha: 0.4);
        Color textColor = theme.colorScheme.onSurface;

        if (completionValue > 0) {
          if (_selectedFilter == 'all') {
            badgeColor = _getHeatmapColor(completionValue, theme, isDark);
            borderColors = badgeColor;
            textColor = isDark ? Colors.black : Colors.white;
          } else {
            badgeColor = theme.colorScheme.primary;
            borderColors = badgeColor;
            textColor = isDark ? Colors.black : Colors.white;
          }
        }

        return Tooltip(
          message: _getTooltipText(date),
          child: GestureDetector(
            onTap: () => _showDayStatusDialog(date, theme),
            child: Column(
              children: [
                Text(
                  dayName,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badgeColor,
                    border: Border.all(
                      color: isCurrentDay && completionValue == 0
                          ? theme.colorScheme.primary
                          : borderColors,
                      width: isCurrentDay ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      dayNum,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isCurrentDay ? FontWeight.bold : FontWeight.normal,
                        color: completionValue > 0 ? textColor : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMonthView(ThemeData theme, bool isDark) {
    final firstDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    final startWeekday = firstDayOfMonth.weekday; // 1: Mon, 7: Sun
    final daysInMonth = lastDayOfMonth.day;

    final totalCells = (startWeekday - 1) + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                });
              },
            ),
            Text(
              monthName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () {
                setState(() {
                  _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    d,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )).toList(),
        ),
        const SizedBox(height: 8),

        Column(
          children: List.generate(rows, (r) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (c) {
                  final cellIndex = r * 7 + c;
                  final dayNumber = cellIndex - (startWeekday - 2);

                  if (dayNumber <= 0 || dayNumber > daysInMonth) {
                    return const SizedBox(width: 32, height: 32);
                  }

                  final cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, dayNumber);
                  final completionValue = _getCompletionValueForDay(cellDate);
                  final isToday = _isSameDay(cellDate, DateTime.now());

                  Color badgeColor = Colors.transparent;
                  Color borderColors = Colors.grey.withValues(alpha: 0.2);
                  Color textColor = theme.colorScheme.onSurface;

                  if (completionValue > 0) {
                    if (_selectedFilter == 'all') {
                      badgeColor = _getHeatmapColor(completionValue, theme, isDark);
                      borderColors = badgeColor;
                      textColor = isDark ? Colors.black : Colors.white;
                    } else {
                      badgeColor = theme.colorScheme.primary;
                      borderColors = badgeColor;
                      textColor = isDark ? Colors.black : Colors.white;
                    }
                  }

                  return Tooltip(
                    message: _getTooltipText(cellDate),
                    child: GestureDetector(
                      onTap: () => _showDayStatusDialog(cellDate, theme),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: badgeColor,
                          border: Border.all(
                            color: isToday && completionValue == 0
                                ? theme.colorScheme.primary
                                : borderColors,
                            width: isToday ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: completionValue > 0 ? textColor : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildYearView(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final startDate = today.subtract(const Duration(days: 364));
    final alignmentDays = startDate.weekday - 1;
    final startMonday = startDate.subtract(Duration(days: alignmentDays));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Yearly Contribution Grid',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(53, (w) {
              return Padding(
                padding: const EdgeInsets.only(right: 3.0),
                child: Column(
                  children: List.generate(7, (d) {
                    final cellDate = startMonday.add(Duration(days: w * 7 + d));

                    if (cellDate.isAfter(today)) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 3.0),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }

                    final completionValue = _getCompletionValueForDay(cellDate);
                    Color cellColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

                    if (completionValue > 0) {
                      if (_selectedFilter == 'all') {
                        cellColor = _getHeatmapColor(completionValue, theme, isDark);
                      } else {
                        cellColor = theme.colorScheme.primary;
                      }
                    }

                    return Tooltip(
                      message: '${DateFormat('MMM d, yyyy').format(cellDate)}\n\n${_getTooltipText(cellDate)}',
                      child: GestureDetector(
                        onTap: () => _showDayStatusDialog(cellDate, theme),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 3.0),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Less ', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ...[0.0, 0.3, 0.6, 1.0].map((val) {
              Color color = isDark ? Colors.grey[900]! : Colors.grey[200]!;
              if (val > 0) {
                color = _getHeatmapColor(val, theme, isDark);
              }
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            Text(' More', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildCalendarCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGoalSelector(theme),
                _buildViewSwitcher(theme, isDark),
              ],
            ),
            const SizedBox(height: 16),

            if (_calendarView == 'week')
              _buildWeekView(theme, isDark)
            else if (_calendarView == 'month')
              _buildMonthView(theme, isDark)
            else
              _buildYearView(theme, isDark),
          ],
        ),
      ),
    );
  }

  // --- MAIN SCREEN BUILDER ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final completedCount = _tasks.where((t) => t.isCompleted).length;
    final totalCount = _tasks.length;
    final streakList = _tasks.map((t) => t.currentStreak).toList();
    final highestStreak = streakList.isEmpty ? 0 : streakList.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Daily Goals & Streaks',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Streak stats Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF2E2A27),
                                  const Color(0xFF1C1917),
                                ]
                              : [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withValues(alpha: 0.7),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.3)
                                : theme.colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress Today',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  totalCount > 0 ? '$completedCount / $totalCount' : '0 / 0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalCount > 0 ? completedCount / totalCount : 0.0,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, color: Colors.amber, size: 28),
                              const SizedBox(width: 8),
                              Text(
                                'Highest Active Streak: ',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                              Text(
                                '$highestStreak Days',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Calendar tracker card
                  _buildCalendarCard(theme, isDark),
                  const SizedBox(height: 16),

                  // Checklist title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'My Daily Goals',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Checklist cards
                  if (_tasks.isEmpty)
                    _buildEmptyState(theme)
                  else
                    ..._tasks.map((task) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildTaskCard(task, theme),
                        )),

                  const SizedBox(height: 80),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add_task),
        label: const Text('New Goal'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No habits tracked yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add recurring daily tasks to measure your consistency. Complete them every day to build your streak! 🔥',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(TodoTask task, ThemeData theme) {
    final isCompleted = task.isCompleted;
    final currentStreak = task.currentStreak;
    final hasStreak = currentStreak > 0;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompleted
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.15),
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleTaskCompletion(task),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted ? theme.colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isCompleted ? theme.colorScheme.primary : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                      color: isCompleted ? Colors.grey : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: hasStreak ? Colors.orange : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasStreak ? '$currentStreak Day Streak' : 'No active streak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasStreak ? FontWeight.bold : FontWeight.normal,
                          color: hasStreak ? Colors.orange[800] : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') {
                  _showEditDialog(task);
                } else if (val == 'delete') {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Daily Goal'),
                      content: Text('Are you sure you want to delete "${task.title}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            _deleteTask(task);
                            Navigator.pop(context);
                          },
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit Name'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
