import 'package:flutter/material.dart';
import 'note_list_screen.dart';
import 'todo_streak_screen.dart';
import '../widgets/app_drawer.dart';

class HomeNavigationScreen extends StatefulWidget {
  const HomeNavigationScreen({super.key});

  @override
  State<HomeNavigationScreen> createState() => _HomeNavigationScreenState();
}

class _HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;
  Key _notesKey = UniqueKey();
  Key _streaksKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final screens = [
      NoteListScreen(key: _notesKey),
      TodoStreakScreen(key: _streaksKey),
    ];

    return Scaffold(
      drawer: AppDrawer(
        onRefresh: () {
          setState(() {
            _notesKey = UniqueKey();
            _streaksKey = UniqueKey();
          });
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes),
            label: 'Notes',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department, color: Colors.orange),
            label: 'Streaks',
          ),
        ],
      ),
    );
  }
}
