import javax.sound.midi.MidiDevice;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Receiver;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.Transmitter;

public class MidiPilotHelper implements Receiver {
  public volatile boolean connected = false;
  public volatile String status = "MIDI: no keyboard";

  private MidiDevice device = null;
  private Transmitter transmitter = null;
  private final boolean[] heldNotes = new boolean[128];
  private int heldCount = 0;

  private boolean pending = false;
  private float pendingRootFreq = 55.0f;
  private int pendingRootNote = -1;
  private int pendingHeldCount = 0;
  private float pendingVelocity = 0.0f;
  private final float[][] pendingEvents = new float[64][4];
  private int pendingEventCount = 0;

  public void start() {
    try {
      MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
      MidiDevice.Info selected = null;
      System.out.println("Available MIDI input devices:");
      for (int i = 0; i < infos.length; i++) {
        MidiDevice.Info info = infos[i];
        MidiDevice candidate = MidiSystem.getMidiDevice(info);
        if (candidate.getMaxTransmitters() == 0) continue;
        String label = info.getName() + " / " + info.getDescription();
        System.out.println("  - " + label);
        String hay = label.toLowerCase();
        if (selected == null
            && (hay.indexOf("keystation") >= 0
                || hay.indexOf("m-audio") >= 0
                || hay.indexOf("m audio") >= 0
                || hay.indexOf("usb") >= 0)) {
          selected = info;
        }
      }

      if (selected == null) {
        status = "MIDI: input not found";
        System.out.println(status + " - plug in the keyboard before launching Processing.");
        return;
      }

      device = MidiSystem.getMidiDevice(selected);
      device.open();
      transmitter = device.getTransmitter();
      transmitter.setReceiver(this);
      connected = true;
      status = "MIDI: " + selected.getName();
      System.out.println("MIDI pilot connected: " + selected.getName());
    } catch (Exception e) {
      connected = false;
      status = "MIDI failed: " + e.getMessage();
      System.out.println(status);
    }
  }

  public synchronized float[] consumePendingValues() {
    if (!pending) return null;
    pending = false;
    return new float[] {
      pendingRootFreq,
      (float)pendingRootNote,
      (float)pendingHeldCount,
      pendingVelocity
    };
  }

  public synchronized float[][] consumeNoteEvents() {
    if (pendingEventCount <= 0) return null;
    float[][] out = new float[pendingEventCount][4];
    for (int i = 0; i < pendingEventCount; i++) {
      out[i][0] = pendingEvents[i][0];
      out[i][1] = pendingEvents[i][1];
      out[i][2] = pendingEvents[i][2];
      out[i][3] = pendingEvents[i][3];
    }
    pendingEventCount = 0;
    return out;
  }

  public void send(MidiMessage message, long timeStamp) {
    if (!(message instanceof ShortMessage)) return;
    ShortMessage sm = (ShortMessage)message;
    int cmd = sm.getCommand();
    int note = Math.max(0, Math.min(127, sm.getData1()));
    int velocity = Math.max(0, Math.min(127, sm.getData2()));

    synchronized (this) {
      if (cmd == ShortMessage.NOTE_ON && velocity > 0) {
        if (!heldNotes[note]) heldCount++;
        heldNotes[note] = true;
        queueNoteEvent(note, velocity, 1.0f);
        queueRootUpdate(velocity);
      } else if (cmd == ShortMessage.NOTE_OFF || (cmd == ShortMessage.NOTE_ON && velocity == 0)) {
        if (heldNotes[note]) heldCount = Math.max(0, heldCount - 1);
        heldNotes[note] = false;
        queueNoteEvent(note, velocity, 0.0f);
        if (heldCount > 0) queueRootUpdate(velocity);
      }
    }
  }

  public void close() {
    shutdown();
  }

  public void shutdown() {
    try {
      if (transmitter != null) transmitter.close();
      transmitter = null;
      if (device != null && device.isOpen()) device.close();
      device = null;
    } catch (Exception e) {
      System.out.println("MIDI shutdown skipped: " + e);
    }
    connected = false;
  }

  private void queueRootUpdate(int velocity) {
    int rootNote = selectedRootNote();
    if (rootNote < 0) return;
    pendingRootNote = rootNote;
    pendingRootFreq = clamp(noteToFrequency(rootNote), 20.0f, 880.0f);
    pendingHeldCount = heldCount;
    pendingVelocity = clamp(velocity / 127.0f, 0.0f, 1.0f);
    pending = true;
  }

  private void queueNoteEvent(int note, int velocity, float on) {
    if (pendingEventCount >= pendingEvents.length) {
      for (int i = 1; i < pendingEventCount; i++) {
        pendingEvents[i - 1][0] = pendingEvents[i][0];
        pendingEvents[i - 1][1] = pendingEvents[i][1];
        pendingEvents[i - 1][2] = pendingEvents[i][2];
        pendingEvents[i - 1][3] = pendingEvents[i][3];
      }
      pendingEventCount = pendingEvents.length - 1;
    }
    pendingEvents[pendingEventCount][0] = note;
    pendingEvents[pendingEventCount][1] = clamp(velocity / 127.0f, 0.0f, 1.0f);
    pendingEvents[pendingEventCount][2] = on;
    pendingEvents[pendingEventCount][3] = heldCount;
    pendingEventCount++;
  }

  private int selectedRootNote() {
    for (int i = 0; i < heldNotes.length; i++) {
      if (heldNotes[i]) return i;
    }
    return -1;
  }

  private float noteToFrequency(int note) {
    return 440.0f * (float)Math.pow(2.0, (note - 69) / 12.0);
  }

  private float clamp(float v, float lo, float hi) {
    return Math.max(lo, Math.min(hi, v));
  }
}
