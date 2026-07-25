
enum AttachmentType {
  image,
  video,
  audio,
  document,
  unknown,
}

class Attachment {
  final String id;
  final String noteId;
  final String filePath; // Absolute path or relative path on device
  final String mimeType;
  final int fileSize;
  final String displayName;

  Attachment({
    required this.id,
    required this.noteId,
    required this.filePath,
    required this.mimeType,
    required this.fileSize,
    required this.displayName,
  });

  AttachmentType get type {
    final mime = mimeType.toLowerCase();
    if (mime.startsWith('image/')) return AttachmentType.image;
    if (mime.startsWith('video/')) return AttachmentType.video;
    if (mime.startsWith('audio/')) return AttachmentType.audio;
    return AttachmentType.document;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'note_id': noteId,
      'file_path': filePath,
      'mime_type': mimeType,
      'file_size': fileSize,
      'display_name': displayName,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as String,
      noteId: map['note_id'] as String,
      filePath: map['file_path'] as String,
      mimeType: map['mime_type'] as String,
      fileSize: map['file_size'] as int,
      displayName: map['display_name'] as String,
    );
  }
}

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Attachment> attachments;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.attachments,
  });

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    List<Attachment>? attachments,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Note.fromMap(Map<String, dynamic> map, {List<Attachment> attachments = const []}) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      attachments: attachments,
    );
  }
}
