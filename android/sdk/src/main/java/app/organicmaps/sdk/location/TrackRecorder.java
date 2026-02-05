package app.organicmaps.sdk.location;

public class TrackRecorder {
  /**
   * Enables or disables the GPS tracker.
   * Must be called before starting track recording.
   * When enabled, it connects to the GPS tracker and starts collecting location
   * updates.
   */
  public static native void nativeSetEnabled(boolean enable);

  /**
   * Returns whether the GPS tracker is enabled.
   */
  public static native boolean nativeIsEnabled();

  /**
   * Starts track recording. The GPS tracker should be enabled first.
   */
  public static native void nativeStartTrackRecording();

  /**
   * Stops track recording.
   */
  public static native void nativeStopTrackRecording();

  /**
   * Saves the recorded track with the given name.
   */
  public static native void nativeSaveTrackRecordingWithName(String name);

  /**
   * Returns whether the current track recording is empty.
   */
  public static native boolean nativeIsTrackRecordingEmpty();

  /**
   * Returns whether track recording is currently enabled/active.
   */
  public static native boolean nativeIsTrackRecordingEnabled();
}
