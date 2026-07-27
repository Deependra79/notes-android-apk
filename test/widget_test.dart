import 'package:flutter_test/flutter_test.dart';
import 'package:notes_app/models/note_model.dart';
import 'package:notes_app/models/todo_model.dart';

void main() {
  group('Note Model Tests', () {
    test('Note mapping serialization and deserialization', () {
      final now = DateTime.now();
      final note = Note(
        id: '123-uuid',
        title: 'Test Note',
        content: 'This is a test content',
        createdAt: now,
        updatedAt: now,
        attachments: [],
      );

      final map = note.toMap();
      expect(map['id'], '123-uuid');
      expect(map['title'], 'Test Note');
      expect(map['content'], 'This is a test content');
      expect(map['created_at'], now.toIso8601String());
      expect(map['updated_at'], now.toIso8601String());

      final fromMapNote = Note.fromMap(map);
      expect(fromMapNote.id, '123-uuid');
      expect(fromMapNote.title, 'Test Note');
      expect(fromMapNote.content, 'This is a test content');
      expect(fromMapNote.createdAt.day, now.day);
      expect(fromMapNote.updatedAt.day, now.day);
    });

    test('Attachment mapping serialization and deserialization', () {
      final attachment = Attachment(
        id: 'att-123',
        noteId: '123-uuid',
        filePath: '/data/user/0/com.hi.notes/app_flutter/attachments/1.jpg',
        mimeType: 'image/jpeg',
        fileSize: 1024,
        displayName: 'photo.jpg',
      );

      final map = attachment.toMap();
      expect(map['id'], 'att-123');
      expect(map['note_id'], '123-uuid');
      expect(map['file_path'], '/data/user/0/com.hi.notes/app_flutter/attachments/1.jpg');
      expect(map['mime_type'], 'image/jpeg');
      expect(map['file_size'], 1024);
      expect(map['display_name'], 'photo.jpg');

      final fromMapAttachment = Attachment.fromMap(map);
      expect(fromMapAttachment.id, 'att-123');
      expect(fromMapAttachment.noteId, '123-uuid');
      expect(fromMapAttachment.filePath, '/data/user/0/com.hi.notes/app_flutter/attachments/1.jpg');
      expect(fromMapAttachment.mimeType, 'image/jpeg');
      expect(fromMapAttachment.fileSize, 1024);
      expect(fromMapAttachment.displayName, 'photo.jpg');
      expect(fromMapAttachment.type, AttachmentType.image);
    });

    test('Attachment type resolver test', () {
      final img = Attachment(id: '1', noteId: '1', filePath: '', mimeType: 'image/png', fileSize: 0, displayName: '');
      final vid = Attachment(id: '2', noteId: '1', filePath: '', mimeType: 'video/mp4', fileSize: 0, displayName: '');
      final aud = Attachment(id: '3', noteId: '1', filePath: '', mimeType: 'audio/mpeg', fileSize: 0, displayName: '');
      final doc = Attachment(id: '4', noteId: '1', filePath: '', mimeType: 'application/pdf', fileSize: 0, displayName: '');

      expect(img.type, AttachmentType.image);
      expect(vid.type, AttachmentType.video);
      expect(aud.type, AttachmentType.audio);
      expect(doc.type, AttachmentType.document);
    });

    test('Note category mapping and copyWith', () {
      final now = DateTime.now();
      final note = Note(
        id: '123-uuid',
        title: 'Work stuff',
        content: 'Drafting doc',
        createdAt: now,
        updatedAt: now,
        attachments: [],
        category: 'Work',
      );

      final map = note.toMap();
      expect(map['category'], 'Work');

      final fromMapNote = Note.fromMap(map);
      expect(fromMapNote.category, 'Work');

      // Test copyWith category clearing
      final cleared = note.copyWith(clearCategory: true);
      expect(cleared.category, null);

      // Test copyWith category updating
      final updated = note.copyWith(category: 'Personal');
      expect(updated.category, 'Personal');
    });
  });

  group('TodoTask Streak Tests', () {
    test('New task initializes with 0 streak and unchecked', () {
      final task = TodoTask(
        id: '1',
        title: 'Exercise',
        streakCount: 0,
        createdAt: DateTime.now(),
      );

      expect(task.isCompleted, false);
      expect(task.currentStreak, 0);
    });

    test('Checking task today starting from 0 sets streak to 1', () {
      final task = TodoTask(
        id: '1',
        title: 'Exercise',
        streakCount: 0,
        createdAt: DateTime.now(),
      );

      final completedTask = task.toggleCompletion();
      expect(completedTask.isCompleted, true);
      expect(completedTask.currentStreak, 1);
    });

    test('Unchecking completed task rolls back streak', () {
      final task = TodoTask(
        id: '1',
        title: 'Exercise',
        streakCount: 0,
        createdAt: DateTime.now(),
      );

      // Check task (streak 1)
      final checked = task.toggleCompletion();
      expect(checked.isCompleted, true);
      expect(checked.currentStreak, 1);

      // Uncheck task (streak rolls back to 0)
      final unchecked = checked.toggleCompletion();
      expect(unchecked.isCompleted, false);
      expect(unchecked.currentStreak, 0);
      expect(unchecked.lastCompletedDate, null);
    });

    test('Checking task completed yesterday increments streak count', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = TodoTask(
        id: '1',
        title: 'Exercise',
        lastCompletedDate: yesterday,
        streakCount: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      // Since last completed yesterday, streak is currently active
      expect(task.currentStreak, 5);
      expect(task.isCompleted, false);

      // Complete it today
      final checkedToday = task.toggleCompletion();
      expect(checkedToday.isCompleted, true);
      expect(checkedToday.currentStreak, 6);
    });

    test('Unchecking task completed today rolls back last completed date to yesterday', () {
      final today = DateTime.now();
      final task = TodoTask(
        id: '1',
        title: 'Exercise',
        lastCompletedDate: today,
        streakCount: 6,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      expect(task.isCompleted, true);
      expect(task.currentStreak, 6);

      // Uncheck
      final unchecked = task.toggleCompletion();
      expect(unchecked.isCompleted, false);
      expect(unchecked.currentStreak, 5); // Rolls back by 1
      expect(unchecked.lastCompletedDate!.day, today.subtract(const Duration(days: 1)).day); // Date rolled back to yesterday
    });

    test('Task completed two days ago (missed yesterday) resets streak to 1 when completed today', () {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final task = TodoTask(
        id: '1',
        title: 'Exercise',
        lastCompletedDate: twoDaysAgo,
        streakCount: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      // Missed yesterday, so active streak is currently broken (returns 0)
      expect(task.currentStreak, 0);
      expect(task.isCompleted, false);

      // Complete today
      final completedToday = task.toggleCompletion();
      expect(completedToday.isCompleted, true);
      expect(completedToday.currentStreak, 1); // Reset and started at 1
    });

    test('Completion history tracking updates when toggling and maps correctly', () {
      final task = TodoTask(
        id: 'hist-1',
        title: 'Drink water',
        streakCount: 0,
        createdAt: DateTime.now(),
        completionDates: [],
      );

      // Check task today
      final checked = task.toggleCompletion();
      expect(checked.completionDates.length, 1);
      final todayMidnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      expect(checked.completionDates.first, todayMidnight);

      // Serialization verification
      final map = checked.toMap();
      final fromMap = TodoTask.fromMap(map);
      expect(fromMap.completionDates.length, 1);
      expect(fromMap.completionDates.first, todayMidnight);

      // Uncheck task today
      final unchecked = checked.toggleCompletion();
      expect(unchecked.completionDates.isEmpty, true);
    });
  });
}
