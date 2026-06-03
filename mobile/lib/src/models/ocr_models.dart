class OcrFile {
  const OcrFile({
    required this.id,
    required this.originalName,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256,
    required this.createdAt,
  });

  final String id;
  final String originalName;
  final String? contentType;
  final int sizeBytes;
  final String sha256;
  final DateTime createdAt;

  factory OcrFile.fromJson(Map<String, dynamic> json) {
    return OcrFile(
      id: json['id'] as String,
      originalName: json['original_name'] as String,
      contentType: json['content_type'] as String?,
      sizeBytes: json['size_bytes'] as int,
      sha256: json['sha256'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OcrTask {
  const OcrTask({
    required this.id,
    required this.fileId,
    required this.mode,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    required this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    required this.startedAt,
    required this.completedAt,
  });

  final String id;
  final String fileId;
  final String mode;
  final String status;
  final int attempts;
  final int maxAttempts;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isTerminal => {'succeeded', 'failed', 'canceled'}.contains(status);

  factory OcrTask.fromJson(Map<String, dynamic> json) {
    return OcrTask(
      id: json['id'] as String,
      fileId: json['file_id'] as String,
      mode: json['mode'] as String,
      status: json['status'] as String,
      attempts: json['attempts'] as int,
      maxAttempts: json['max_attempts'] as int,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      startedAt: _parseDate(json['started_at']),
      completedAt: _parseDate(json['completed_at']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }
    return DateTime.parse(value as String);
  }
}

class OcrResult {
  const OcrResult({
    required this.id,
    required this.taskId,
    required this.text,
    required this.markdown,
    required this.createdAt,
  });

  final String id;
  final String taskId;
  final String text;
  final String markdown;
  final DateTime createdAt;

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    return OcrResult(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      text: json['text'] as String,
      markdown: json['markdown'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OcrJob {
  const OcrJob({
    required this.fileName,
    required this.fileId,
    required this.taskId,
    required this.status,
    required this.createdAt,
  });

  final String fileName;
  final String fileId;
  final String taskId;
  final String status;
  final DateTime createdAt;

  OcrJob copyWith({String? status}) {
    return OcrJob(
      fileName: fileName,
      fileId: fileId,
      taskId: taskId,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
