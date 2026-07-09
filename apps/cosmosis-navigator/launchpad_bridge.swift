import CoreFoundation
import CoreMIDI
import Darwin
import Foundation

let host = "127.0.0.1"
let processingPort: UInt16 = 12000
let ledListenPort: UInt16 = 12001
let bridgeBuildLabel = "Cosmosis Launchpad bridge led-static-v1"

var inputSocketFd: Int32 = -1
var ledSocketFd: Int32 = -1
var processingTarget = sockaddr_in()
var midiClient = MIDIClientRef()
var inputPort = MIDIPortRef()
var outputPort = MIDIPortRef()
var selectedSource = MIDIEndpointRef()
var selectedSourceName = ""
var selectedDestination = MIDIEndpointRef()
var selectedDestinationName = ""

let enterProgrammerMode: [UInt8] = [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0c, 0x0e, 0x01, 0xf7]

func padOscString(_ s: String) -> [UInt8] {
  var out = Array(s.utf8)
  out.append(0)
  while out.count % 4 != 0 { out.append(0) }
  return out
}

func appendInt32(_ v: Int32, to data: inout [UInt8]) {
  let b = UInt32(bitPattern: v).bigEndian
  data.append(UInt8((b >> 24) & 0xff))
  data.append(UInt8((b >> 16) & 0xff))
  data.append(UInt8((b >> 8) & 0xff))
  data.append(UInt8(b & 0xff))
}

func sendOsc(_ address: String, _ a: Int32, _ b: Int32, _ c: Int32? = nil) {
  if inputSocketFd < 0 { return }
  var packet = padOscString(address)
  packet += padOscString(c == nil ? ",ii" : ",iii")
  appendInt32(a, to: &packet)
  appendInt32(b, to: &packet)
  if let c = c { appendInt32(c, to: &packet) }

  var addr = processingTarget
  packet.withUnsafeBufferPointer { buffer in
    withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
        _ = Darwin.sendto(inputSocketFd, buffer.baseAddress, buffer.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
  }
}

func midiName(_ obj: MIDIObjectRef) -> String {
  var unmanaged: Unmanaged<CFString>?
  let err = MIDIObjectGetStringProperty(obj, kMIDIPropertyName, &unmanaged)
  if err != noErr { return "" }
  return (unmanaged?.takeRetainedValue() as String?) ?? ""
}

func sendMidi(_ bytes: [UInt8]) {
  if outputPort == 0 || selectedDestination == 0 || bytes.isEmpty { return }
  var packetList = MIDIPacketList()
  let packet = MIDIPacketListInit(&packetList)
  bytes.withUnsafeBufferPointer { buffer in
    if let base = buffer.baseAddress {
      _ = MIDIPacketListAdd(&packetList, 1024, packet, 0, bytes.count, base)
      MIDISend(outputPort, selectedDestination, &packetList)
    }
  }
}

func paletteIndex(red: Int32, green: Int32, blue: Int32) -> UInt8 {
  let r = max(0, min(255, red))
  let g = max(0, min(255, green))
  let b = max(0, min(255, blue))
  if r <= 0 && g <= 0 && b <= 0 { return 0 }
  if r >= g && r >= b { return 5 }   // red
  if g >= r && g >= b { return 21 }  // green
  return 45                          // dark blue / indigo
}

func setGridLed(row: Int32, col: Int32, red: Int32, green: Int32, blue: Int32) {
  if selectedDestination == 0 { return }
  if row < 1 || row > 8 || col < 1 || col > 8 { return }
  let note = UInt8(row * 10 + col)
  sendMidi([0x90, note, paletteIndex(red: red, green: green, blue: blue)])
}

func clearGridLeds() {
  for row in 1...8 {
    for col in 1...8 {
      sendMidi([0x90, UInt8(row * 10 + col), 0])
    }
  }
}

func readPaddedString(_ bytes: [UInt8], _ offset: inout Int) -> String? {
  if offset >= bytes.count { return nil }
  let start = offset
  while offset < bytes.count && bytes[offset] != 0 {
    offset += 1
  }
  if offset >= bytes.count { return nil }
  let s = String(bytes: bytes[start..<offset], encoding: .utf8)
  offset += 1
  while offset % 4 != 0 { offset += 1 }
  return s
}

func parseOscInt32(_ bytes: [UInt8], _ offset: Int) -> Int32 {
  if offset + 4 > bytes.count { return 0 }
  let b = (UInt32(bytes[offset]) << 24)
    | (UInt32(bytes[offset + 1]) << 16)
    | (UInt32(bytes[offset + 2]) << 8)
    | UInt32(bytes[offset + 3])
  return Int32(bitPattern: b)
}

func handleLedOsc(_ bytes: [UInt8]) {
  var offset = 0
  guard let address = readPaddedString(bytes, &offset) else { return }
  guard let tags = readPaddedString(bytes, &offset) else { return }

  if address == "/launchpad/led" && tags.hasPrefix(",iiiii") {
    let row = parseOscInt32(bytes, offset)
    let col = parseOscInt32(bytes, offset + 4)
    let red = parseOscInt32(bytes, offset + 8)
    let green = parseOscInt32(bytes, offset + 12)
    let blue = parseOscInt32(bytes, offset + 16)
    setGridLed(row: row, col: col, red: red, green: green, blue: blue)
  } else if address == "/launchpad/clear" {
    clearGridLeds()
  }
}

func pollLedOsc() {
  if ledSocketFd < 0 { return }
  var buffer = [UInt8](repeating: 0, count: 1024)
  while true {
    let n = buffer.withUnsafeMutableBufferPointer { ptr in
      Darwin.recv(ledSocketFd, ptr.baseAddress, ptr.count, 0)
    }
    if n <= 0 { break }
    handleLedOsc(Array(buffer.prefix(n)))
  }
}

func handleMidiBytes(_ bytes: [UInt8]) {
  var i = 0
  while i < bytes.count {
    let status = bytes[i]
    let kind = status & 0xf0

    if (kind == 0x90 || kind == 0x80) && i + 2 < bytes.count {
      let note = Int32(bytes[i + 1])
      let velocity = Int32(bytes[i + 2])
      let on = (kind == 0x90 && velocity > 0) ? Int32(1) : Int32(0)
      sendOsc("/launchpad/note", note, velocity, on)
      i += 3
    } else if kind == 0xb0 && i + 2 < bytes.count {
      let cc = Int32(bytes[i + 1])
      let value = Int32(bytes[i + 2])
      sendOsc("/launchpad/cc", cc, value)
      i += 3
    } else {
      i += 1
    }
  }
}

func midiReadProc(packetList: UnsafePointer<MIDIPacketList>, readProcRefCon: UnsafeMutableRawPointer?, srcConnRefCon: UnsafeMutableRawPointer?) {
  var packet = packetList.pointee.packet
  for _ in 0..<packetList.pointee.numPackets {
    let count = Int(packet.length)
    let bytes = withUnsafeBytes(of: packet.data) { rawBytes in
      Array(rawBytes.prefix(count))
    }
    handleMidiBytes(bytes)
    packet = MIDIPacketNext(&packet).pointee
  }
}

func scoreSource(_ name: String) -> Int {
  let hay = name.lowercased()
  if hay.contains("lpx midi out") { return 100 }
  if hay.contains("launchpad") && hay.contains("midi out") { return 95 }
  if hay.contains("lpx daw out") { return 80 }
  if hay.contains("launchpad") || hay.contains("novation") || hay.contains("lpx") { return 70 }
  return -1
}

func scoreDestination(_ name: String) -> Int {
  let hay = name.lowercased()
  if hay.contains("lpx midi in") { return 100 }
  if hay.contains("launchpad") && hay.contains("midi in") { return 95 }
  if hay.contains("lpx daw in") { return 80 }
  if hay.contains("launchpad") || hay.contains("novation") || hay.contains("lpx") { return 70 }
  return -1
}

inputSocketFd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
processingTarget.sin_family = sa_family_t(AF_INET)
processingTarget.sin_port = processingPort.bigEndian
inet_pton(AF_INET, host, &processingTarget.sin_addr)

ledSocketFd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
if ledSocketFd >= 0 {
  var yes: Int32 = 1
  setsockopt(ledSocketFd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
  var addr = sockaddr_in()
  addr.sin_family = sa_family_t(AF_INET)
  addr.sin_port = ledListenPort.bigEndian
  addr.sin_addr.s_addr = INADDR_ANY.bigEndian
  let bindResult = withUnsafePointer(to: &addr) { ptr in
    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
      Darwin.bind(ledSocketFd, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
    }
  }
  if bindResult == 0 {
    let flags = fcntl(ledSocketFd, F_GETFL, 0)
    _ = fcntl(ledSocketFd, F_SETFL, flags | O_NONBLOCK)
  } else {
    print("Cosmosis Launchpad bridge: failed to bind LED OSC port \(ledListenPort)")
    Darwin.close(ledSocketFd)
    ledSocketFd = -1
  }
}

MIDIClientCreate("Cosmosis Launchpad Bridge" as CFString, nil, nil, &midiClient)
MIDIInputPortCreate(midiClient, "Cosmosis Launchpad Input" as CFString, midiReadProc, nil, &inputPort)
MIDIOutputPortCreate(midiClient, "Cosmosis Launchpad LED Output" as CFString, &outputPort)

var bestSourceScore = -1
for i in 0..<MIDIGetNumberOfSources() {
  let source = MIDIGetSource(i)
  let name = midiName(source)
  let score = scoreSource(name)
  if score > bestSourceScore {
    bestSourceScore = score
    selectedSource = source
    selectedSourceName = name
  }
}

var bestDestinationScore = -1
for i in 0..<MIDIGetNumberOfDestinations() {
  let destination = MIDIGetDestination(i)
  let name = midiName(destination)
  let score = scoreDestination(name)
  if score > bestDestinationScore {
    bestDestinationScore = score
    selectedDestination = destination
    selectedDestinationName = name
  }
}

if selectedSource == 0 {
  print("Cosmosis Launchpad bridge: no Launchpad MIDI source found.")
  exit(2)
}

MIDIPortConnectSource(inputPort, selectedSource, nil)
if selectedDestination != 0 {
  sendMidi(enterProgrammerMode)
  clearGridLeds()
}

print("\(bridgeBuildLabel): \(selectedSourceName) -> \(host):\(processingPort); LED OSC \(ledSocketFd >= 0 ? "listening" : "disabled") on \(ledListenPort); LED out \(selectedDestinationName.isEmpty ? "not found" : selectedDestinationName)")
fflush(stdout)

while true {
  pollLedOsc()
  usleep(20_000)
}
