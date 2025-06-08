import 'package:uuid/uuid.dart';

class VaultItem {
  final String id;
  final String name;
  final String fileName;
  final String originalFileName;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final int fileSize;
  final String description;
  final List<String> tags;
  final VaultItemType type;
  final Map<String, dynamic> metadata;

  VaultItem({
    String? id,
    required this.name,
    required this.fileName,
    required this.originalFileName,
    DateTime? createdAt,
    DateTime? modifiedAt,
    required this.fileSize,
    this.description = '',
    this.tags = const [],
    this.type = VaultItemType.stegoAudio,
    this.metadata = const {},
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    modifiedAt = modifiedAt ?? DateTime.now();

  VaultItem copyWith({
    String? id,
    String? name,
    String? fileName,
    String? originalFileName,
    DateTime? createdAt,
    DateTime? modifiedAt,
    int? fileSize,
    String? description,
    List<String>? tags,
    VaultItemType? type,
    Map<String, dynamic>? metadata,
  }) {
    return VaultItem(
      id: id ?? this.id,
      name: name ?? this.name,
      fileName: fileName ?? this.fileName,
      originalFileName: originalFileName ?? this.originalFileName,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      fileSize: fileSize ?? this.fileSize,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fileName': fileName,
      'originalFileName': originalFileName,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'fileSize': fileSize,
      'description': description,
      'tags': tags,
      'type': type.name,
      'metadata': metadata,
    };
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'],
      name: json['name'],
      fileName: json['fileName'],
      originalFileName: json['originalFileName'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
      fileSize: json['fileSize'],
      description: json['description'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      type: VaultItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => VaultItemType.stegoAudio,
      ),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get formattedCreatedAt {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VaultItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VaultItem(id: $id, name: $name, fileName: $fileName)';
  }
}

enum VaultItemType {
  stegoAudio,
  originalAudio,
  recordedAudio,
}

extension VaultItemTypeExtension on VaultItemType {
  String get displayName {
    switch (this) {
      case VaultItemType.stegoAudio:
        return 'Stego Audio';
      case VaultItemType.originalAudio:
        return 'Original Audio';
      case VaultItemType.recordedAudio:
        return 'Recorded Audio';
    }
  }

  String get description {
    switch (this) {
      case VaultItemType.stegoAudio:
        return 'Audio file with hidden message';
      case VaultItemType.originalAudio:
        return 'Original audio file';
      case VaultItemType.recordedAudio:
        return 'Audio recorded in app';
    }
  }
}

