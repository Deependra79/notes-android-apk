import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_model.dart';
import '../services/database_helper.dart';
import 'note_editor_screen.dart';
import 'passcode_screen.dart';
import 'package:notes_app/main.dart';

class NoteListScreen extends StatefulWidget {
  const NoteListScreen({super.key});

  @override
  State<NoteListScreen> createState() => _NoteListScreenState();
}

class _NoteListScreenState extends State<NoteListScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  bool _isPasscodeEnabled = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshNotes();
    _checkPasscodeStatus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshNotes() async {
    setState(() {
      _isLoading = true;
    });
    final notes = await DatabaseHelper.instance.searchNotes(_searchQuery);
    setState(() {
      _notes = notes;
      _isLoading = false;
    });
  }

  Future<void> _checkPasscodeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPasscodeEnabled = prefs.getString('app_passcode') != null;
    });
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    DatabaseHelper.instance.searchNotes(query).then((notes) {
      setState(() {
        _notes = notes;
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _shareNoteDirectly(Note note) async {
    final subject = note.title.isEmpty ? 'Shared Note' : note.title;
    final text = "${note.title.isEmpty ? 'Untitled' : note.title}\n\n${note.content}";
    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    if (note.attachments.isNotEmpty && !kIsWeb) {
      try {
        final xFiles = note.attachments.map((a) => XFile(a.filePath)).toList();
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: subject,
            files: xFiles,
            sharePositionOrigin: rect,
          ),
        );
      } catch (e) {
        await SharePlus.instance.share(
          ShareParams(
            text: text,
            subject: subject,
            sharePositionOrigin: rect,
          ),
        );
      }
    } else {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: subject,
          sharePositionOrigin: rect,
        ),
      );
    }
  }

  void _deleteNoteDirectly(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title.isEmpty ? 'Untitled' : note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteNote(note.id);
      _refreshNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Modern search bar and header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'My Notes',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      
                      // Lock protection toggle
                      IconButton(
                        icon: Icon(
                          _isPasscodeEnabled ? Icons.lock : Icons.lock_open_outlined,
                          color: _isPasscodeEnabled ? theme.colorScheme.secondary : theme.colorScheme.primary.withValues(alpha: 0.6),
                        ),
                        tooltip: _isPasscodeEnabled ? 'Change / Disable Passcode' : 'Enable Passcode',
                        onPressed: () async {
                          if (_isPasscodeEnabled) {
                            final disabled = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PasscodeScreen(mode: PasscodeMode.disable),
                              ),
                            );
                            if (disabled == true) {
                              _checkPasscodeStatus();
                            }
                          } else {
                            final enabled = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PasscodeScreen(mode: PasscodeMode.setup),
                              ),
                            );
                            if (enabled == true) {
                              _checkPasscodeStatus();
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),

                      // Global theme toggler (Day / Night Mode)
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: MyApp.themeNotifier,
                        builder: (context, currentMode, child) {
                          final isAppDark = currentMode == ThemeMode.dark ||
                              (currentMode == ThemeMode.system &&
                                  MediaQuery.of(context).platformBrightness == Brightness.dark);
                          return IconButton(
                            icon: Icon(
                              isAppDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            tooltip: isAppDark ? 'Switch to Day Mode' : 'Switch to Night Mode',
                            onPressed: () {
                              MyApp.themeNotifier.value = isAppDark ? ThemeMode.light : ThemeMode.dark;
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      
                      IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Open Settings & Stats',
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search notes...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Note List or Loading Indicator
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _notes.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildNoteList(theme),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoteEditorScreen()),
          );
          _refreshNotes();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Note'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final hasSearch = _searchQuery.isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.book_outlined,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch ? 'No notes found' : 'Capture your thoughts',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try changing your search terms or clear the search bar.'
                  : 'Start adding text notes, photos, videos, and documents. All your content is saved securely on your device.',
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

  Widget _buildNoteList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        return _buildNoteCard(note, theme);
      },
    );
  }

  Widget _buildNoteCard(Note note, ThemeData theme) {
    final imageAttachment = note.attachments.firstWhere(
      (a) => a.type == AttachmentType.image,
      orElse: () => Attachment(id: '', noteId: '', filePath: '', mimeType: '', fileSize: 0, displayName: ''),
    );

    final hasPreviewImage = imageAttachment.filePath.isNotEmpty;
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(note.updatedAt);

    // Group remaining attachments count by type
    final imageCount = note.attachments.where((a) => a.type == AttachmentType.image).length;
    final videoCount = note.attachments.where((a) => a.type == AttachmentType.video).length;
    final docCount = note.attachments.where((a) => a.type == AttachmentType.document || a.type == AttachmentType.audio).length;

    // Calculate total size of attachments
    final totalBytes = note.attachments.fold<int>(0, (sum, a) => sum + a.fileSize);
    String sizeText = '';
    if (totalBytes > 0) {
      if (totalBytes > 1024 * 1024) {
        sizeText = '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeText = '${(totalBytes / 1024).toStringAsFixed(0)} KB';
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(note: note),
            ),
          );
          _refreshNotes();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          note.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            height: 1.35,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Preview Image Thumbnail (if any)
                  if (hasPreviewImage) ...[
                    const SizedBox(width: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: kIsWeb
                            ? Image.network(
                                imageAttachment.filePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              )
                            : Image.file(
                                File(imageAttachment.filePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 6),
              
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Metadata: date and attachment details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedDate,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        if (note.attachments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (imageCount > 0)
                                Icon(Icons.image_outlined, size: 13, color: theme.colorScheme.primary),
                              if (videoCount > 0)
                                Icon(Icons.videocam_outlined, size: 13, color: theme.colorScheme.secondary),
                              if (docCount > 0)
                                const Icon(Icons.attach_file_outlined, size: 13, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                '${note.attachments.length} files ($sizeText)',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 20),
                        tooltip: 'Share Note',
                        onPressed: () => _shareNoteDirectly(note),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete Note',
                        onPressed: () => _deleteNoteDirectly(note),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
