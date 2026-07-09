import javax.sound.midi.MidiDevice;
import javax.sound.midi.MidiMessage;
import javax.sound.midi.MidiSystem;
import javax.sound.midi.Receiver;
import javax.sound.midi.ShortMessage;
import javax.sound.midi.SysexMessage;
import javax.sound.midi.Transmitter;

public class MidiPilotHelper implements Receiver {
  public volatile boolean connected = false;
  public volatile boolean launchpadDetected = false;
  public volatile String status = "MIDI: no keyboard";

  private MidiDevice device = null;
  private Transmitter transmitter = null;
  private final boolean[] heldNotes = new boolean[128];
  private int heldCount = 0;

  // LED output (replaces the Swift bridge). This helper is now the SOLE LED writer.
  public volatile boolean ledReady = false;
  private MidiDevice ledDevice = null;
  private Receiver ledOut = null;

  private boolean pending = false;
  private float pendingRootFreq = 55.0f;
  private int pendingRootNote = -1;
  private int pendingHeldCount = 0;
  private float pendingVelocity = 0.0f;
  private final float[][] pendingEvents = new float[64][4];
  private int pendingEventCount = 0;
  private final float[][] pendingControls = new float[64][4];
  private int pendingControlCount = 0;

  public void start() {
    try {
      MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
      MidiDevice.Info selected = null;
      int selectedScore = -1;
      System.out.println("Available MIDI input devices:");
      for (int i = 0; i < infos.length; i++) {
        MidiDevice.Info info = infos[i];
        MidiDevice candidate = MidiSystem.getMidiDevice(info);
        if (candidate.getMaxTransmitters() == 0) continue;
        String label = info.getName() + " / " + info.getDescription();
        System.out.println("  - " + label);
        String hay = label.toLowerCase();
        int score = -1;
        if ((hay.indexOf("launchpad x") >= 0 || hay.indexOf("lpx") >= 0) && hay.indexOf("midi out") >= 0) score = 135;
        else if ((hay.indexOf("launchpad x") >= 0 || hay.indexOf("lpx") >= 0) && hay.indexOf("daw out") >= 0) score = 125;
        else if (hay.indexOf("launchpad x") >= 0 || hay.indexOf("lpx") >= 0) score = 120;
        else if (hay.indexOf("launchpad") >= 0) score = 110;
        else if (hay.indexOf("novation") >= 0) score = 100;
        else if (hay.indexOf("keystation") >= 0) score = 70;
        else if (hay.indexOf("m-audio") >= 0 || hay.indexOf("m audio") >= 0) score = 65;
        else if (hay.indexOf("usb") >= 0) score = 20;
        // Prefer CoreMIDI4J-backed endpoints when present: the stock macOS provider
        // cannot send SysEx, so we want the CoreMIDI4J version of the same device.
        if (score >= 0 && hay.indexOf("coremidi4j") >= 0) score += 200;
        if (score > selectedScore) {
          selected = info;
          selectedScore = score;
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
      String selectedLabel = selected.getName() + " / " + selected.getDescription();
      launchpadDetected = selectedLabel.toLowerCase().indexOf("launchpad") >= 0
                       || selectedLabel.toLowerCase().indexOf("lpx") >= 0
                       || selectedLabel.toLowerCase().indexOf("novation") >= 0;
      status = (launchpadDetected ? "MIDI Launchpad: " : "MIDI: ") + selected.getName();
      System.out.println("MIDI pilot connected: " + selected.getName());
    } catch (Exception e) {
      connected = false;
      status = "MIDI failed: " + e.getMessage();
      System.out.println(status);
    }
  }

  // ── Launchpad X LED output ────────────────────────────────────────────────
  // Opens the Launchpad's MIDI INPUT endpoint (the one the host writes to), puts the
  // pad into Programmer mode, and lights pads via RGB SysEx. With the Swift bridge
  // gone there is only one LED writer, so the old two-writer blackout cannot recur.
  public void startLedOutput() {
    try {
      MidiDevice.Info[] infos = MidiSystem.getMidiDeviceInfo();
      MidiDevice.Info selected = null;
      int selectedScore = -1;
      System.out.println("Available MIDI output devices:");
      for (int i = 0; i < infos.length; i++) {
        MidiDevice.Info info = infos[i];
        MidiDevice candidate = MidiSystem.getMidiDevice(info);
        if (candidate.getMaxReceivers() == 0) continue;     // must accept output
        String label = info.getName() + " / " + info.getDescription();
        System.out.println("  - " + label);
        String hay = label.toLowerCase();
        int score = -1;
        if ((hay.indexOf("launchpad x") >= 0 || hay.indexOf("lpx") >= 0) && hay.indexOf("midi in") >= 0) score = 135;
        else if ((hay.indexOf("launchpad x") >= 0 || hay.indexOf("lpx") >= 0) && hay.indexOf("daw") < 0) score = 120;
        else if (hay.indexOf("launchpad") >= 0 && hay.indexOf("daw") < 0) score = 110;
        else if (hay.indexOf("novation") >= 0 && hay.indexOf("daw") < 0) score = 90;
        // Prefer the CoreMIDI4J-backed endpoint so SysEx (mode switch + RGB) actually sends.
        if (score >= 0 && hay.indexOf("coremidi4j") >= 0) score += 200;
        if (score > selectedScore) {
          selected = info;
          selectedScore = score;
        }
      }

      if (selected == null) {
        System.out.println("Launchpad LED output not found - LEDs disabled.");
        return;
      }

      ledDevice = MidiSystem.getMidiDevice(selected);
      ledDevice.open();
      ledOut = ledDevice.getReceiver();
      enterProgrammerMode();
      ledReady = true;           // set before clearAll so the guarded setPad fires
      clearAll();
      System.out.println("Launchpad LED out: " + selected.getName());
    } catch (Exception e) {
      ledReady = false;
      System.out.println("Launchpad LED out failed: " + e);
    }
  }

  public void enterProgrammerMode() {
    sendSysex(new byte[] {
      (byte)0xF0, 0x00, 0x20, 0x29, 0x02, 0x0C, 0x0E, 0x01, (byte)0xF7
    });
  }

  public void exitToLiveMode() {
    sendSysex(new byte[] {
      (byte)0xF0, 0x00, 0x20, 0x29, 0x02, 0x0C, 0x0E, 0x00, (byte)0xF7
    });
  }

  // row 1 = top .. row 8 = bottom, col 1..8 = left..right (matches the Processing grid).
  // Lights a pad via Note-On (channel 1), velocity = Launchpad palette colour index.
  // Note-On is an ordinary short message and transmits fine on macOS Java (unlike SysEx).
  // Programmer-mode pad index is (y*10 + x) with y from the BOTTOM: top row 81..88, bottom 11..18.
  public synchronized void setPad(int rowTop, int col, int colorIndex) {
    if (!ledReady || ledOut == null) return;
    if (rowTop < 1 || rowTop > 8 || col < 1 || col > 8) return;
    int note = (9 - rowTop) * 10 + col;
    try {
      ShortMessage sm = new ShortMessage();
      sm.setMessage(ShortMessage.NOTE_ON, 0, clampInt(note, 0, 127), clampInt(colorIndex, 0, 127));
      ledOut.send(sm, -1);
    } catch (Exception e) {
      // A dropped LED message is non-fatal; never let it disturb audio/visual timing.
    }
  }

  public synchronized void setTopPad(int index, int colorIndex) {
    if (!ledReady || ledOut == null) return;
    if (index < 0 || index > 7) return;
    int note = 91 + index;
    try {
      ShortMessage sm = new ShortMessage();
      sm.setMessage(ShortMessage.NOTE_ON, 0, clampInt(note, 0, 127), clampInt(colorIndex, 0, 127));
      ledOut.send(sm, -1);
    } catch (Exception e) {
      // A dropped LED message is non-fatal; never let it disturb audio/visual timing.
    }
  }

  public synchronized void clearAll() {
    if (!ledReady || ledOut == null) return;
    for (int row = 1; row <= 8; row++) {
      for (int col = 1; col <= 8; col++) {
        setPad(row, col, 0);
      }
    }
  }

  private void sendSysex(byte[] data) {
    if (ledOut == null) return;
    try {
      SysexMessage msg = new SysexMessage();
      msg.setMessage(data, data.length);
      ledOut.send(msg, -1);
    } catch (Exception e) {
      // A dropped LED message is non-fatal; never let it disturb audio/visual timing.
    }
  }

  private int clampInt(int v, int lo, int hi) {
    return Math.max(lo, Math.min(hi, v));
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

  public synchronized float[][] consumeControlEvents() {
    if (pendingControlCount <= 0) return null;
    float[][] out = new float[pendingControlCount][4];
    for (int i = 0; i < pendingControlCount; i++) {
      out[i][0] = pendingControls[i][0];
      out[i][1] = pendingControls[i][1];
      out[i][2] = pendingControls[i][2];
      out[i][3] = pendingControls[i][3];
    }
    pendingControlCount = 0;
    return out;
  }

  public void send(MidiMessage message, long timeStamp) {
    if (!(message instanceof ShortMessage)) return;
    ShortMessage sm = (ShortMessage)message;
    int cmd = sm.getCommand();
    int channel = sm.getChannel();
    int note = Math.max(0, Math.min(127, sm.getData1()));
    int velocity = Math.max(0, Math.min(127, sm.getData2()));

    synchronized (this) {
      if (cmd == ShortMessage.NOTE_ON && velocity > 0) {
        if (!(launchpadDetected && note >= 89)) {
          if (!heldNotes[note]) heldCount++;
          heldNotes[note] = true;
        }
        queueNoteEvent(note, velocity, 1.0f);
        if (!(launchpadDetected && note >= 89)) queueRootUpdate(velocity);
      } else if (cmd == ShortMessage.NOTE_OFF || (cmd == ShortMessage.NOTE_ON && velocity == 0)) {
        if (!(launchpadDetected && note >= 89)) {
          if (heldNotes[note]) heldCount = Math.max(0, heldCount - 1);
          heldNotes[note] = false;
        }
        queueNoteEvent(note, velocity, 0.0f);
        if (heldCount > 0 && !(launchpadDetected && note >= 89)) queueRootUpdate(velocity);
      } else if (cmd == ShortMessage.CONTROL_CHANGE) {
        queueControlEvent(channel, note, velocity);
      }
    }
  }

  public void close() {
    shutdown();
  }

  public void shutdown() {
    try {
      if (ledReady) {
        clearAll();
        exitToLiveMode();
      }
      ledReady = false;
      if (ledOut != null) ledOut.close();
      ledOut = null;
      if (ledDevice != null && ledDevice.isOpen()) ledDevice.close();
      ledDevice = null;
    } catch (Exception e) {
      System.out.println("LED shutdown skipped: " + e);
    }
    try {
      if (transmitter != null) transmitter.close();
      transmitter = null;
      if (device != null && device.isOpen()) device.close();
      device = null;
    } catch (Exception e) {
      System.out.println("MIDI shutdown skipped: " + e);
    }
    connected = false;
    launchpadDetected = false;
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

  private void queueControlEvent(int channel, int number, int value) {
    if (pendingControlCount >= pendingControls.length) {
      for (int i = 1; i < pendingControlCount; i++) {
        pendingControls[i - 1][0] = pendingControls[i][0];
        pendingControls[i - 1][1] = pendingControls[i][1];
        pendingControls[i - 1][2] = pendingControls[i][2];
        pendingControls[i - 1][3] = pendingControls[i][3];
      }
      pendingControlCount = pendingControls.length - 1;
    }
    pendingControls[pendingControlCount][0] = channel;
    pendingControls[pendingControlCount][1] = number;
    pendingControls[pendingControlCount][2] = clamp(value / 127.0f, 0.0f, 1.0f);
    pendingControls[pendingControlCount][3] = value;
    pendingControlCount++;
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
