enum DocumentStatus { draft, completed }

class DocumentRecord {
  final String id;
  final String name;
  final String? sourcePath;
  final String? exportedPath;
  final int pageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DocumentStatus status;
  final Map<String, dynamic>? draftData;

  const DocumentRecord({
    required this.id,
    required this.name,
    required this.sourcePath,
    this.exportedPath,
    required this.pageCount,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    this.draftData,
  });

  DocumentRecord copyWith({
    String? name,
    String? sourcePath,
    String? exportedPath,
    int? pageCount,
    DateTime? updatedAt,
    DocumentStatus? status,
    Map<String, dynamic>? draftData,
  }) =>
      DocumentRecord(
        id: id,
        name: name ?? this.name,
        sourcePath: sourcePath ?? this.sourcePath,
        exportedPath: exportedPath ?? this.exportedPath,
        pageCount: pageCount ?? this.pageCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        draftData: draftData ?? this.draftData,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sourcePath': sourcePath,
        'exportedPath': exportedPath,
        'pageCount': pageCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.name,
        'draftData': draftData,
      };

  factory DocumentRecord.fromJson(Map<String, dynamic> json) => DocumentRecord(
        id: json['id'] as String,
        name: json['name'] as String,
        sourcePath: json['sourcePath'] as String?,
        exportedPath: json['exportedPath'] as String?,
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        status: DocumentStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => DocumentStatus.draft,
        ),
        draftData: (json['draftData'] as Map?)?.cast<String, dynamic>(),
      );
}
