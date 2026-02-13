/// Resultado de una operación de grabación de track.
class TrackRecordingResult {
  /// Si la operación fue exitosa.
  final bool success;

  /// Si actualmente está grabando.
  final bool isRecording;

  /// Si el track estaba vacío (solo relevante para stopTrackRecording).
  final bool? wasEmpty;

  const TrackRecordingResult({
    required this.success,
    required this.isRecording,
    this.wasEmpty,
  });

  @override
  String toString() =>
      'TrackRecordingResult(success: $success, isRecording: $isRecording, wasEmpty: $wasEmpty)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackRecordingResult &&
          runtimeType == other.runtimeType &&
          success == other.success &&
          isRecording == other.isRecording &&
          wasEmpty == other.wasEmpty;

  @override
  int get hashCode => Object.hash(success, isRecording, wasEmpty);
}

/// Estado actual de la grabación de track.
class TrackRecordingStatus {
  /// Si actualmente está grabando.
  final bool isRecording;

  /// Si el track grabado está vacío (sin puntos GPS).
  final bool isEmpty;

  /// Si el GpsTracker del motor está habilitado.
  final bool isGpsTrackerEnabled;

  const TrackRecordingStatus({
    required this.isRecording,
    required this.isEmpty,
    required this.isGpsTrackerEnabled,
  });

  /// Indica si hay datos válidos para guardar.
  bool get hasDataToSave => isRecording && !isEmpty;

  /// Estado inactivo por defecto.
  factory TrackRecordingStatus.inactive() => const TrackRecordingStatus(
        isRecording: false,
        isEmpty: true,
        isGpsTrackerEnabled: false,
      );

  TrackRecordingStatus copyWith({
    bool? isRecording,
    bool? isEmpty,
    bool? isGpsTrackerEnabled,
  }) {
    return TrackRecordingStatus(
      isRecording: isRecording ?? this.isRecording,
      isEmpty: isEmpty ?? this.isEmpty,
      isGpsTrackerEnabled:
          isGpsTrackerEnabled ?? this.isGpsTrackerEnabled,
    );
  }

  @override
  String toString() =>
      'TrackRecordingStatus(isRecording: $isRecording, isEmpty: $isEmpty, gpsEnabled: $isGpsTrackerEnabled)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackRecordingStatus &&
          runtimeType == other.runtimeType &&
          isRecording == other.isRecording &&
          isEmpty == other.isEmpty &&
          isGpsTrackerEnabled == other.isGpsTrackerEnabled;

  @override
  int get hashCode =>
      Object.hash(isRecording, isEmpty, isGpsTrackerEnabled);
}
