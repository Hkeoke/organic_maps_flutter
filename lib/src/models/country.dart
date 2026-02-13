/// Representa un país o región descargable.
class Country {
  final String id;
  final String name;
  final String? parentId;
  final int sizeBytes;
  final int totalSizeBytes;
  final int downloadedBytes;
  final int bytesToDownload;
  final CountryStatus status;
  final int downloadProgress;
  final int childCount;
  final int totalChildCount;
  final String description;
  final bool present;

  const Country({
    required this.id,
    required this.name,
    this.parentId,
    required this.sizeBytes,
    required this.totalSizeBytes,
    this.downloadedBytes = 0,
    this.bytesToDownload = 0,
    required this.status,
    this.downloadProgress = 0,
    this.childCount = 0,
    this.totalChildCount = 0,
    this.description = '',
    this.present = false,
  });

  factory Country.fromMap(Map<String, dynamic> map) {
    return Country(
      id: map['id'] as String,
      name: map['name'] as String,
      parentId: map['parentId'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      totalSizeBytes: (map['totalSizeBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      bytesToDownload: (map['bytesToDownload'] as num?)?.toInt() ?? 0,
      status: CountryStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CountryStatus.notDownloaded,
      ),
      downloadProgress: (map['downloadProgress'] as num?)?.toInt() ?? 0,
      childCount: (map['childCount'] as num?)?.toInt() ?? 0,
      totalChildCount: (map['totalChildCount'] as num?)?.toInt() ?? 0,
      description: map['description'] as String? ?? '',
      present: map['present'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'parentId': parentId,
      'sizeBytes': sizeBytes,
      'totalSizeBytes': totalSizeBytes,
      'downloadedBytes': downloadedBytes,
      'bytesToDownload': bytesToDownload,
      'status': status.name,
      'downloadProgress': downloadProgress,
      'childCount': childCount,
      'totalChildCount': totalChildCount,
      'description': description,
      'present': present,
    };
  }

  /// Retorna el tamaño más relevante formateado en MB o GB.
  String get formattedSize {
    final bytes = sizeBytes > 0 ? sizeBytes : totalSizeBytes;
    if (bytes == 0) return '0 B';
    final sizeInMB = bytes / (1024 * 1024);
    if (sizeInMB < 1) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (sizeInMB < 1024) {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    }
    final sizeInGB = sizeInMB / 1024;
    return '${sizeInGB.toStringAsFixed(2)} GB';
  }

  /// Indica si el país tiene hijos (es un grupo/continente).
  bool get isExpandable => totalChildCount > 1;

  /// Indica si el país está completamente descargado.
  bool get isDownloaded => status == CountryStatus.downloaded;

  /// Indica si el país se está descargando.
  bool get isDownloading => status == CountryStatus.downloading;

  /// Indica si tiene actualización disponible.
  bool get hasUpdate => status == CountryStatus.updateAvailable;

  /// Progreso de descarga normalizado (0.0 a 1.0).
  double get normalizedProgress => downloadProgress / 100.0;

  Country copyWith({
    String? id,
    String? name,
    String? parentId,
    int? sizeBytes,
    int? totalSizeBytes,
    int? downloadedBytes,
    int? bytesToDownload,
    CountryStatus? status,
    int? downloadProgress,
    int? childCount,
    int? totalChildCount,
    String? description,
    bool? present,
  }) {
    return Country(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      bytesToDownload: bytesToDownload ?? this.bytesToDownload,
      status: status ?? this.status,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      childCount: childCount ?? this.childCount,
      totalChildCount: totalChildCount ?? this.totalChildCount,
      description: description ?? this.description,
      present: present ?? this.present,
    );
  }

  @override
  String toString() =>
      'Country(id: $id, name: $name, status: ${status.name}, size: $formattedSize)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Country &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Estado de descarga de un país/región.
enum CountryStatus {
  notDownloaded,
  downloading,
  downloaded,
  updateAvailable,
  error,
}
