import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note_model.dart';
import '../services/database_helper.dart';
import '../widgets/video_player_widget.dart';
import 'fullscreen_image_view.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late String _tempNoteId;
  List<Attachment> _attachments = [];
  bool _isSaving = false;
  bool _hasSaved = false;
  final ImagePicker _picker = ImagePicker();
  String? _selectedCategory;
  final List<String> _presetCategories = ['Work', 'Personal', 'Ideas', 'Study', 'Important'];
  final List<String> _customCategories = [];

  @override
  void initState() {
    super.initState();
    if (widget.note != null) {
      _titleController.text = widget.note!.title;
      _contentController.text = widget.note!.content;
      _attachments = List.from(widget.note!.attachments);
      _tempNoteId = widget.note!.id;
      _selectedCategory = widget.note!.category;
      if (_selectedCategory != null && !_presetCategories.contains(_selectedCategory!)) {
        _customCategories.add(_selectedCategory!);
      }
    } else {
      _tempNoteId = const Uuid().v4();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (_hasSaved || _isSaving) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // If both are empty and we have no attachments, don't save (or delete if editing)
    if (title.isEmpty && content.isEmpty && _attachments.isEmpty) {
      if (widget.note != null) {
        // User cleared the note, delete it
        await DatabaseHelper.instance.deleteNote(widget.note!.id);
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final note = Note(
      id: _tempNoteId,
      title: title.isEmpty ? 'Untitled' : title,
      content: content,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      attachments: _attachments,
      category: _selectedCategory,
    );

    if (widget.note == null) {
      await DatabaseHelper.instance.insertNote(note);
    } else {
      await DatabaseHelper.instance.updateNote(note);
    }

    _hasSaved = true;

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _shareNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final subject = title.isEmpty ? 'Shared Note' : title;
    final text = "${title.isEmpty ? 'Untitled' : title}\n\n$content";

    final box = context.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    if (_attachments.isNotEmpty && !kIsWeb) {
      try {
        final xFiles = _attachments.map((a) => XFile(a.filePath)).toList();
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          final name = pickedFile.name;
          final ext = p.extension(name);
          final mime = _getMimeTypeByExtension(ext);
          final base64Str = 'data:$mime;base64,${base64.encode(bytes)}';
          _addWebAttachment(base64Str, name, mime, bytes.length);
        } else {
          final file = File(pickedFile.path);
          final displayName = p.basename(pickedFile.path);
          await _addAttachment(file, displayName);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          final name = pickedFile.name;
          final ext = p.extension(name);
          final mime = _getMimeTypeByExtension(ext);
          final base64Str = 'data:$mime;base64,${base64.encode(bytes)}';
          _addWebAttachment(base64Str, name, mime, bytes.length);
        } else {
          final file = File(pickedFile.path);
          final displayName = p.basename(pickedFile.path);
          await _addAttachment(file, displayName);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick video: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result != null) {
        if (kIsWeb) {
          final fileBytes = result.files.single.bytes;
          final fileName = result.files.single.name;
          if (fileBytes != null) {
            final ext = p.extension(fileName);
            final mime = _getMimeTypeByExtension(ext);
            final base64Str = 'data:$mime;base64,${base64.encode(fileBytes)}';
            _addWebAttachment(base64Str, fileName, mime, fileBytes.length);
          }
        } else if (result.files.single.path != null) {
          final file = File(result.files.single.path!);
          final displayName = result.files.single.name;
          await _addAttachment(file, displayName);
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick file: $e');
    }
  }

  void _addWebAttachment(String base64Str, String displayName, String mime, int fileSize) {
    final uniqueId = const Uuid().v4();
    final attachment = Attachment(
      id: uniqueId,
      noteId: _tempNoteId,
      filePath: base64Str,
      mimeType: mime,
      fileSize: fileSize,
      displayName: displayName,
    );
    setState(() {
      _attachments.add(attachment);
    });
  }

  Future<void> _addAttachment(File sourceFile, String displayName) async {
    // Show a loading indicator dialog for processing large files
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Saving attachment locally...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory('${appDir.path}/attachments');
      if (!await attachmentsDir.exists()) {
        await attachmentsDir.create(recursive: true);
      }

      final ext = p.extension(sourceFile.path);
      final uniqueId = const Uuid().v4();
      final newFileName = '$uniqueId$ext';
      final targetPath = '${attachmentsDir.path}/$newFileName';

      // Copy the file to local app storage
      final copiedFile = await sourceFile.copy(targetPath);
      final size = await copiedFile.length();
      final mime = _getMimeTypeByExtension(ext);

      final attachment = Attachment(
        id: uniqueId,
        noteId: _tempNoteId,
        filePath: targetPath,
        mimeType: mime,
        fileSize: size,
        displayName: displayName,
      );

      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);

      setState(() {
        _attachments.add(attachment);
      });
    } catch (e) {
      // Dismiss loading dialog
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Failed to save attachment: $e');
    }
  }

  String _getMimeTypeByExtension(String ext) {
    ext = ext.toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.m4a':
        return 'audio/mp4';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.doc':
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((a) => a.id == id);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Add Attachment',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purple),
                title: const Text('Choose Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam, color: Colors.red),
                title: const Text('Choose Video'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.teal),
                title: const Text('Choose Document / Audio'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter attachments by type
    final mediaAttachments = _attachments.where((a) => a.type == AttachmentType.image || a.type == AttachmentType.video).toList();
    final documentAttachments = _attachments.where((a) => a.type == AttachmentType.audio || a.type == AttachmentType.document).toList();

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _saveNote();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _saveNote();
              navigator.pop();
            },
          ),
          actions: [
            // Share Button
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share Note',
              onPressed: _shareNote,
            ),
            // Done / Explicit Save button
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              tooltip: 'Save & Exit',
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _saveNote();
                navigator.pop();
              },
            ),
            if (widget.note != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Note'),
                      content: const Text('Are you sure you want to delete this note and all its attachments?'),
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
                    await DatabaseHelper.instance.deleteNote(_tempNoteId);
                    navigator.pop();
                  }
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic date subtitle
                    Text(
                      DateFormat('MMMM dd, yyyy - hh:mm a').format(
                        widget.note?.updatedAt ?? DateTime.now(),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildCategorySelector(theme),
                    
                    // Title Field
                    TextField(
                      controller: _titleController,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Media Grid (if any image/video attachments exist)
                    if (mediaAttachments.isNotEmpty) ...[
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: mediaAttachments.length,
                        itemBuilder: (context, index) {
                          final attachment = mediaAttachments[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: attachment.type == AttachmentType.image
                                      ? GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => FullscreenImageView(
                                                  imagePath: attachment.filePath,
                                                  title: attachment.displayName,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Hero(
                                            tag: attachment.filePath,
                                            child: kIsWeb
                                                ? Image.network(
                                                    attachment.filePath,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Center(child: Icon(Icons.broken_image, size: 40)),
                                                  )
                                                : Image.file(
                                                    File(attachment.filePath),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Center(child: Icon(Icons.broken_image, size: 40)),
                                                  ),
                                          ),
                                        )
                                      : VideoPlayerWidget(
                                          videoPath: attachment.filePath,
                                          showControls: true,
                                        ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _removeAttachment(attachment.id),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Content Editor Body
                    TextField(
                      controller: _contentController,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.5,
                      ),
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Start writing...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Document/Audio Attachments (if any exist)
                    if (documentAttachments.isNotEmpty) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'Documents & Audio',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: documentAttachments.length,
                        itemBuilder: (context, index) {
                          final attachment = documentAttachments[index];
                          final sizeKb = (attachment.fileSize / 1024).toStringAsFixed(1);
                          final isAudio = attachment.type == AttachmentType.audio;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isAudio ? Icons.audiotrack : Icons.insert_drive_file,
                                color: isAudio ? Colors.blue : Colors.orange,
                              ),
                              title: Text(
                                attachment.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text('$sizeKb KB'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                onPressed: () => _removeAttachment(attachment.id),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Bottom Action bar for attaching files
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.4),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add media or files',
                    onPressed: _showAttachmentOptions,
                  ),
                  const Spacer(),
                  if (_isSaving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      'Saved locally',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final allCategories = [..._presetCategories, ..._customCategories];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 18,
              color: theme.colorScheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              'Category:',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const Spacer(),
            if (_selectedCategory != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[400],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...allCategories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[300] : theme.colorScheme.onSurface),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? cat : null;
                      });
                    },
                  ),
                );
              }),

              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Custom...'),
                labelStyle: const TextStyle(fontSize: 12),
                onPressed: _showCustomCategoryDialog,
              ),
            ],
          ),
        ),
        const Divider(height: 24),
      ],
    );
  }

  void _showCustomCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g., Finance, Fitness, Travel...',
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
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                setState(() {
                  if (!_presetCategories.contains(val) && !_customCategories.contains(val)) {
                    _customCategories.add(val);
                  }
                  _selectedCategory = val;
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
