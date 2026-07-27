import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import '../models/todo_model.dart';
import '../services/database_helper.dart';
import '../screens/passcode_screen.dart';
import 'package:notes_app/main.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback? onRefresh;

  const AppDrawer({super.key, this.onRefresh});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  int _totalNotes = 0;
  int _totalTasks = 0;
  int _highestStreak = 0;
  bool _isPasscodeEnabled = false;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStatsAndSettings();
  }

  Future<void> _loadStatsAndSettings() async {
    try {
      final notes = await DatabaseHelper.instance.searchNotes('');
      final tasks = await DatabaseHelper.instance.getAllTasks();
      final prefs = await SharedPreferences.getInstance();
      
      final streakList = tasks.map((t) => t.currentStreak).toList();
      final maxStreak = streakList.isEmpty ? 0 : streakList.reduce((a, b) => a > b ? a : b);
      
      if (mounted) {
        setState(() {
          _totalNotes = notes.length;
          _totalTasks = tasks.length;
          _highestStreak = maxStreak;
          _isPasscodeEnabled = prefs.getString('app_passcode') != null;
          _loadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStats = false;
        });
      }
    }
  }

  Future<void> _exportBackup() async {
    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      final allNotes = await DatabaseHelper.instance.searchNotes('');
      final notesData = [];
      for (var note in allNotes) {
        final noteMap = note.toMap();
        noteMap['attachments'] = note.attachments.map((a) => a.toMap()).toList();
        notesData.add(noteMap);
      }
      final allTasks = await DatabaseHelper.instance.getAllTasks();
      
      final backupMap = {
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'notes': notesData,
        'tasks': allTasks.map((t) => t.toMap()).toList(),
      };
      
      final jsonString = jsonEncode(backupMap);
      
      await SharePlus.instance.share(
        ShareParams(
          text: jsonString,
          subject: 'notes_backup_${DateTime.now().millisecondsSinceEpoch}.json',
          sharePositionOrigin: rect,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export backup: $e')),
        );
      }
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content = '';
      if (kIsWeb) {
        content = utf8.decode(file.bytes!);
      } else {
        final fileIo = File(file.path!);
        content = await fileIo.readAsString();
      }

      final Map<String, dynamic> backupMap = jsonDecode(content);
      if (backupMap['notes'] == null && backupMap['tasks'] == null) {
        throw const FormatException('Invalid backup file format');
      }

      int importedNotes = 0;
      int importedTasks = 0;

      if (backupMap['notes'] != null) {
        final List<dynamic> notesList = backupMap['notes'];
        for (var noteMap in notesList) {
          final List<dynamic> attList = noteMap['attachments'] ?? [];
          final attachments = attList.map((a) => Attachment.fromMap(a as Map<String, dynamic>)).toList();
          final note = Note.fromMap(noteMap as Map<String, dynamic>, attachments: attachments);
          await DatabaseHelper.instance.insertNote(note);
          importedNotes++;
        }
      }

      if (backupMap['tasks'] != null) {
        final List<dynamic> tasksList = backupMap['tasks'];
        for (var taskMap in tasksList) {
          final task = TodoTask.fromMap(taskMap as Map<String, dynamic>);
          await DatabaseHelper.instance.insertTask(task);
          importedTasks++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $importedNotes notes and $importedTasks daily goals!')),
        );
        _loadStatsAndSettings();
        widget.onRefresh?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import backup: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(24.0),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Note That',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Offline & Secure',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // Statistics Panel Card
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1C1917) : theme.colorScheme.primary.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.15),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _loadingStats
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'YOUR STATS',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.secondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildStatItem('Notes', _totalNotes.toString(), Icons.notes),
                                _buildStatItem('Goals', _totalTasks.toString(), Icons.task_alt),
                                _buildStatItem('Streak', '$_highestStreak d', Icons.local_fire_department, color: Colors.orange),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                  ),

                  // Theme mode toggle
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: MyApp.themeNotifier,
                    builder: (context, currentMode, child) {
                      final isAppDark = currentMode == ThemeMode.dark ||
                          (currentMode == ThemeMode.system &&
                              MediaQuery.of(context).platformBrightness == Brightness.dark);
                      return ListTile(
                        leading: Icon(
                          isAppDark ? Icons.light_mode : Icons.dark_mode,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(isAppDark ? 'Day Mode' : 'Night Mode'),
                        onTap: () {
                          MyApp.themeNotifier.value = isAppDark ? ThemeMode.light : ThemeMode.dark;
                        },
                      );
                    },
                  ),

                  // Passcode lock setting
                  ListTile(
                    leading: Icon(
                      _isPasscodeEnabled ? Icons.lock : Icons.lock_open,
                      color: _isPasscodeEnabled ? theme.colorScheme.secondary : Colors.grey,
                    ),
                    title: Text(_isPasscodeEnabled ? 'Change / Disable Lock' : 'Enable Passcode Lock'),
                    onTap: () async {
                      if (_isPasscodeEnabled) {
                        final disabled = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PasscodeScreen(mode: PasscodeMode.disable),
                          ),
                        );
                        if (disabled == true) _loadStatsAndSettings();
                      } else {
                        final enabled = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PasscodeScreen(mode: PasscodeMode.setup),
                          ),
                        );
                        if (enabled == true) _loadStatsAndSettings();
                      }
                    },
                  ),

                  ListTile(
                    leading: Icon(
                      Icons.api_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('AI Assist API Key'),
                    subtitle: const Text('Configure Gemini API Key'),
                    onTap: _showApiKeyDialog,
                  ),

                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      'DATA MANAGEMENT',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1),
                    ),
                  ),

                  // Export backup
                  ListTile(
                    leading: const Icon(Icons.download, color: Colors.blue),
                    title: const Text('Export Backup'),
                    subtitle: const Text('Save all notes and habits to JSON'),
                    onTap: _exportBackup,
                  ),

                  // Import restore
                  ListTile(
                    leading: const Icon(Icons.upload, color: Colors.purple),
                    title: const Text('Import Restore'),
                    subtitle: const Text('Restore notes and habits from JSON'),
                    onTap: _importBackup,
                  ),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'v1.0.0 • Private Notes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: color ?? theme.colorScheme.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  void _showApiKeyDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('gemini_api_key') ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Gemini API key to enable the AI Assist note polishing helper.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'AIzaSy...',
                border: OutlineInputBorder(),
                labelText: 'API Key',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = controller.text.trim();
              final navigator = Navigator.of(context);
              if (newKey.isEmpty) {
                await prefs.remove('gemini_api_key');
              } else {
                await prefs.setString('gemini_api_key', newKey);
              }
              navigator.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
