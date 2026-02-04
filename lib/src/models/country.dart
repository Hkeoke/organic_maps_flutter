/// Representa un país o región descargable
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

  Country({
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

  /// Retorna el tamaño formateado en MB o GB
  String get formattedSize {
    // Usar totalSizeBytes si sizeBytes es 0 (para grupos y países sin descargar)
    final bytes = sizeBytes > 0 ? sizeBytes : totalSizeBytes;
    final sizeInMB = bytes / (1024 * 1024);
    if (sizeInMB < 1024) {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    } else {
      final sizeInGB = sizeInMB / 1024;
      return '${sizeInGB.toStringAsFixed(2)} GB';
    }
  }

  /// Indica si el país tiene hijos (es un grupo)
  bool get isExpandable => totalChildCount > 1;
}

enum CountryStatus {
  notDownloaded,
  downloading,
  downloaded,
  updateAvailable,
  error,
}

