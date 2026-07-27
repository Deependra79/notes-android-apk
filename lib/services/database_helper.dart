import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/note_model.dart';
import '../models/todo_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Upgraded version to 3 to support task completion history
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE attachments (
        id TEXT PRIMARY KEY,
        note_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        display_name TEXT NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE todo_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        last_completed_date TEXT,
        streak_count INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        completion_history TEXT
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE todo_tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          last_completed_date TEXT,
          streak_count INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE todo_tasks ADD COLUMN completion_history TEXT');
      } catch (_) {}
    }
  }

  // WEB JSON STORAGE BACKEND LOGIC FOR NOTES
  Future<List<Note>> _getWebNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('web_notes');
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((noteMap) {
        final List<dynamic> attList = noteMap['attachments'] ?? [];
        final attachments = attList.map((a) => Attachment.fromMap(a as Map<String, dynamic>)).toList();
        return Note.fromMap(noteMap as Map<String, dynamic>, attachments: attachments);
      }).toList();
    } catch (e) {
      debugPrint('Error parsing web notes: $e');
      return [];
    }
  }

  Future<void> _saveWebNotes(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> maps = notes.map((note) {
      final noteMap = note.toMap();
      noteMap['attachments'] = note.attachments.map((a) => a.toMap()).toList();
      return noteMap;
    }).toList();
    await prefs.setString('web_notes', json.encode(maps));
  }

  // WEB JSON STORAGE BACKEND LOGIC FOR TODO TASKS
  Future<List<TodoTask>> _getWebTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('web_tasks');
    if (jsonStr == null) return [];
    
    try {
      final List<dynamic> decoded = json.decode(jsonStr);
      return decoded.map((taskMap) => TodoTask.fromMap(taskMap as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error parsing web tasks: $e');
      return [];
    }
  }

  Future<void> _saveWebTasks(List<TodoTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> maps = tasks.map((task) => task.toMap()).toList();
    await prefs.setString('web_tasks', json.encode(maps));
  }

  // CRUD for Notes
  Future<String> insertNote(Note note) async {
    if (kIsWeb) {
      final notes = await _getWebNotes();
      notes.add(note);
      await _saveWebNotes(notes);
      return note.id;
    }

    final db = await instance.database;
    await db.insert('notes', note.toMap());
    
    for (var attachment in note.attachments) {
      await db.insert('attachments', attachment.toMap());
    }
    
    return note.id;
  }

  Future<List<Note>> getAllNotes() async {
    if (kIsWeb) {
      final notes = await _getWebNotes();
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    }

    final db = await instance.database;
    final notesData = await db.query('notes', orderBy: 'updated_at DESC');
    
    List<Note> notes = [];
    for (var map in notesData) {
      final noteId = map['id'] as String;
      final attachmentsData = await db.query(
        'attachments',
        where: 'note_id = ?',
        whereArgs: [noteId],
      );
      final attachments = attachmentsData.map((a) => Attachment.fromMap(a)).toList();
      notes.add(Note.fromMap(map, attachments: attachments));
    }
    return notes;
  }

  Future<Note?> getNoteById(String id) async {
    if (kIsWeb) {
      final notes = await _getWebNotes();
      for (var note in notes) {
        if (note.id == id) return note;
      }
      return null;
    }

    final db = await instance.database;
    final notesData = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (notesData.isEmpty) return null;

    final attachmentsData = await db.query(
      'attachments',
      where: 'note_id = ?',
      whereArgs: [id],
    );
    final attachments = attachmentsData.map((a) => Attachment.fromMap(a)).toList();
    return Note.fromMap(notesData.first, attachments: attachments);
  }

  Future<int> updateNote(Note note) async {
    if (kIsWeb) {
      final notes = await _getWebNotes();
      final index = notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        notes[index] = note;
        await _saveWebNotes(notes);
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    
    // Update note details
    final res = await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );

    // Update attachments
    final currentAttachmentsData = await db.query(
      'attachments',
      where: 'note_id = ?',
      whereArgs: [note.id],
    );
    final currentAttachments = currentAttachmentsData.map((a) => Attachment.fromMap(a)).toList();

    for (var current in currentAttachments) {
      bool existsInUpdated = note.attachments.any((a) => a.id == current.id);
      if (!existsInUpdated) {
        await _deletePhysicalFile(current.filePath);
        await db.delete('attachments', where: 'id = ?', whereArgs: [current.id]);
      }
    }

    for (var attachment in note.attachments) {
      await db.insert(
        'attachments',
        attachment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return res;
  }

  Future<int> deleteNote(String id) async {
    if (kIsWeb) {
      final notes = await _getWebNotes();
      notes.removeWhere((n) => n.id == id);
      await _saveWebNotes(notes);
      return 1;
    }

    final db = await instance.database;
    
    final attachmentsData = await db.query(
      'attachments',
      where: 'note_id = ?',
      whereArgs: [id],
    );
    final attachments = attachmentsData.map((a) => Attachment.fromMap(a)).toList();
    for (var attachment in attachments) {
      await _deletePhysicalFile(attachment.filePath);
    }

    await db.delete('attachments', where: 'note_id = ?', whereArgs: [id]);
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _deletePhysicalFile(String filePath) async {
    if (kIsWeb) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting physical file at $filePath: $e');
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    if (kIsWeb) {
      final notes = await _getWebNotes();
      if (query.trim().isEmpty) {
        notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return notes;
      }
      final q = query.toLowerCase();
      final filtered = notes.where((n) =>
        n.title.toLowerCase().contains(q) ||
        n.content.toLowerCase().contains(q)
      ).toList();
      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return filtered;
    }

    if (query.trim().isEmpty) return getAllNotes();

    final db = await instance.database;
    final notesData = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );

    List<Note> notes = [];
    for (var map in notesData) {
      final noteId = map['id'] as String;
      final attachmentsData = await db.query(
        'attachments',
        where: 'note_id = ?',
        whereArgs: [noteId],
      );
      final attachments = attachmentsData.map((a) => Attachment.fromMap(a)).toList();
      notes.add(Note.fromMap(map, attachments: attachments));
    }
    return notes;
  }

  // ==========================================
  // CRUD FOR TODO TASKS
  // ==========================================

  Future<String> insertTask(TodoTask task) async {
    if (kIsWeb) {
      final tasks = await _getWebTasks();
      tasks.add(task);
      await _saveWebTasks(tasks);
      return task.id;
    }

    final db = await instance.database;
    await db.insert('todo_tasks', task.toMap());
    return task.id;
  }

  Future<List<TodoTask>> getAllTasks() async {
    if (kIsWeb) {
      final tasks = await _getWebTasks();
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    }

    final db = await instance.database;
    final tasksData = await db.query('todo_tasks', orderBy: 'created_at ASC');
    return tasksData.map((map) => TodoTask.fromMap(map)).toList();
  }

  Future<int> updateTask(TodoTask task) async {
    if (kIsWeb) {
      final tasks = await _getWebTasks();
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        tasks[index] = task;
        await _saveWebTasks(tasks);
        return 1;
      }
      return 0;
    }

    final db = await instance.database;
    return await db.update(
      'todo_tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(String id) async {
    if (kIsWeb) {
      final tasks = await _getWebTasks();
      tasks.removeWhere((t) => t.id == id);
      await _saveWebTasks(tasks);
      return 1;
    }

    final db = await instance.database;
    return await db.delete(
      'todo_tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    if (kIsWeb) return;
    final db = await instance.database;
    db.close();
  }
}
