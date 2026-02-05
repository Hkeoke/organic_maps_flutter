/// Resultado de una operación de grabación de track
class TrackRecordingResult {
  /// Si la operación fue exitosa
  final bool success;
  
  /// Si actualmente está grabando
  final bool isRecording;
  
  /// Si el track estaba vacío (solo para stopTrackRecording)
  final bool? wasEmpty;

  TrackRecordingResult({
    required this.success,
    required this.isRecording,
    this.wasEmpty,
  });

  @override
  String toString() => 
    'TrackRecordingResult(success: $success, isRecording: $isRecording, wasEmpty: $wasEmpty)';
}

/// Estado actual de la grabación de track
class TrackRecordingStatus {
  /// Si actualmente está grabando
  final bool isRecording;
  
  /// Si el track grabado está vacío (sin puntos GPS)
  final bool isEmpty;
  
  /// Si el GpsTracker está habilitado
  final bool isGpsTrackerEnabled;

  TrackRecordingStatus({
    required this.isRecording,
    required this.isEmpty,
    required this.isGpsTrackerEnabled,
  });

  /// Indica si hay datos válidos para guardar
  bool get hasDataToSave => isRecording && !isEmpty;

  @override
  String toString() => 
    'TrackRecordingStatus(isRecording: $isRecording, isEmpty: $isEmpty, isGpsTrackerEnabled: $isGpsTrackerEnabled)';
}
