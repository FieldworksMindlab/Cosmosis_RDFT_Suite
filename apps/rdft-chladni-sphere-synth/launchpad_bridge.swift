import CoreFoundation
import CoreMIDI
import Darwin
import Foundation

let host = "127.0.0.1"
let port: UInt16 = 12000
let paintLaunchpad = ProcessInfo.processInfo.environment["RDFT_LPX_PAINT"] == "1"

var socketFd: Int32 = -1
var target = sockaddr_in()
var outputPort = MIDIPortRef()
var selectedDestination = MIDIEndpointRef()
var recentLedEcho: [UInt8: (color: UInt8, time: CFAbsoluteTime)] = [:]
let ledEchoSuppressSeconds = 0.35
var lastFullPaint = CFAbsoluteTimeGetCurrent()
var activePage = 0

// Launchpad X programmer mode. In this mode LED note/CC messages own the
// physical surface instead of the user's saved Custom/DAW layouts.
let enterProgrammerMode: [UInt8] = [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0c, 0x0e, 0x01, 0xf7]
let liveMode: [UInt8] = [0xf0, 0x00, 0x20, 0x29, 0x02, 0x0c, 0x0e, 0x00, 0xf7]
let sidePageCCs: [UInt8] = [89, 79, 69, 59, 49, 39, 29, 19]
let pageSideColors: [UInt8] = [3, 37, 21, 53, 9, 13, 45, 5]

let rdftRowColors: [UInt8] = [
  3,   // slot 1: foundation/action, white
  5,   // slot 2: drone, red
  9,   // slot 3: arp, orange
  13,  // slot 4: surface/solar/ocean, yellow
  21,  // slot 5: glass, green
  37,  // slot 6: choir, blue
  45,  // slot 7: keys/Hopf, indigo
  53   // slot 8: ECO/EG, violet
]

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
  if socketFd < 0 { return }
  var packet = padOscString(address)
  packet += padOscString(c == nil ? ",ii" : ",iii")
  appendInt32(a, to: &packet)
  appendInt32(b, to: &packet)
  if let c = c { appendInt32(c, to: &packet) }

  var addr = target
  packet.withUnsafeBufferPointer { buffer in
    withUnsafePointer(to: &addr) { ptr in
      ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
        _ = Darwin.sendto(socketFd, buffer.baseAddress, buffer.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
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

func gridRow(_ note: UInt8) -> Int? {
  let col = Int(note % 10)
  let row = Int(note / 10)
  if col >= 1 && col <= 8 && row >= 1 && row <= 8 { return row }
  return nil
}

func gridCell(_ note: UInt8) -> (row: Int, col: Int)? {
  let col = Int(note % 10)
  let row = Int(note / 10)
  if col >= 1 && col <= 8 && row >= 1 && row <= 8 { return (row, col) }
  return nil
}

func normalizedGridNote(_ note: UInt8) -> UInt8? {
  let col = Int(note % 10)
  let row = Int(note / 10)
  if col >= 1 && col <= 8 && row >= 1 && row <= 8 {
    return UInt8(36 + (row - 1) * 8 + (col - 1))
  }
  return nil
}

func sendMidi(_ bytes: [UInt8]) {
  if !paintLaunchpad { return }
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

func setPadColor(_ note: UInt8, _ color: UInt8) {
  if !paintLaunchpad { return }
  recentLedEcho[note] = (color, CFAbsoluteTimeGetCurrent())
  sendMidi([0x90, note, color])
}

func colorForPageCell(_ page: Int, _ row: Int, _ col: Int) -> UInt8 {
  switch page {
  case 0:
    return rdftRowColors[row - 1]
  case 1:
    let dx = Double(col) - 4.5
    let dy = Double(row) - 4.5
    let d = sqrt(dx * dx + dy * dy)
    if d < 1.25 { return 3 }       // white core
    if d < 2.8 { return 37 }       // cyan stream
    return (row + col) % 2 == 0 ? 0 : 1
  case 2:
    if row == col || row + col == 9 { return 45 }
    if row == 4 || row == 5 || col == 4 || col == 5 { return 37 }
    return 21
  case 3:
    if row <= 2 { return 21 }      // chirp canopy
    if row <= 4 { return 53 }      // calls
    if row <= 6 { return 9 }       // growth
    return col >= 6 ? 5 : 13       // fissure / EG
  case 4:
    if col <= 2 { return 5 }       // drone/arp heat
    if col <= 4 { return 9 }
    if col <= 6 { return 21 }
    return 37
  default:
    return pageSideColors[min(max(page, 0), pageSideColors.count - 1)]
  }
}

func restorePadColor(_ note: UInt8) {
  if let cell = gridCell(note) {
    setPadColor(note, colorForPageCell(activePage, cell.row, cell.col))
  }
}

func pageForCC(_ cc: UInt8) -> Int? {
  for i in 0..<sidePageCCs.count {
    if sidePageCCs[i] == cc { return i }
  }
  return nil
}

func paintRDFTPage(_ page: Int) {
  sendMidi(enterProgrammerMode)
  activePage = min(max(page, 0), 7)
  for row in 1...8 {
    for col in 1...8 {
      let note = UInt8(row * 10 + col)
      setPadColor(note, colorForPageCell(activePage, row, col))
    }
  }
  // Top action strip, matching the existing main preset action map.
  let actionColors: [UInt8] = [21, 5, 13, 37, 45, 9, 5, 53]
  for i in 0..<actionColors.count {
    sendMidi([0xb0, UInt8(91 + i), actionColors[i]])
  }
  for i in 0..<sidePageCCs.count {
    let cc = sidePageCCs[i]
    let color = i == activePage ? UInt8(3) : pageSideColors[i]
    sendMidi([0xb0, cc, color])
  }
  lastFullPaint = CFAbsoluteTimeGetCurrent()
}

func handleMidiBytes(_ bytes: [UInt8]) {
  var i = 0
  while i < bytes.count {
    let status = bytes[i]
    let kind = status & 0xf0
    if (kind == 0x90 || kind == 0x80) && i + 2 < bytes.count {
      let physicalNote = bytes[i + 1]
      let noteForProcessing = normalizedGridNote(physicalNote) ?? physicalNote
      let note = Int32(noteForProcessing)
      let velocity = Int32(bytes[i + 2])
      let on = (kind == 0x90 && velocity > 0) ? Int32(1) : Int32(0)
      if kind == 0x90,
         let echo = recentLedEcho[physicalNote],
         echo.color == bytes[i + 2],
         CFAbsoluteTimeGetCurrent() - echo.time < ledEchoSuppressSeconds {
        i += 3
        continue
      }
      sendOsc("/launchpad/note", note, velocity, on)
      if let _ = gridRow(physicalNote) {
        if on == 1 {
          setPadColor(physicalNote, 3)
        } else {
          restorePadColor(physicalNote)
        }
      }
      i += 3
    } else if kind == 0xb0 && i + 2 < bytes.count {
      let cc = bytes[i + 1]
      let value = bytes[i + 2]
      if value > 0, let page = pageForCC(cc) {
        paintRDFTPage(page)
        sendOsc("/launchpad/page", Int32(page), Int32(value))
      }
      sendOsc("/launchpad/cc", Int32(cc), Int32(value))
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

socketFd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
target.sin_family = sa_family_t(AF_INET)
target.sin_port = port.bigEndian
inet_pton(AF_INET, host, &target.sin_addr)

var client = MIDIClientRef()
var inputPort = MIDIPortRef()
MIDIClientCreate("RDFT Launchpad Bridge" as CFString, nil, nil, &client)
MIDIInputPortCreate(client, "RDFT Launchpad Input" as CFString, midiReadProc, nil, &inputPort)
MIDIOutputPortCreate(client, "RDFT Launchpad Output" as CFString, &outputPort)

let sourceCount = MIDIGetNumberOfSources()
var selected = MIDIEndpointRef()
var selectedName = ""
var selectedScore = -1

for i in 0..<sourceCount {
  let source = MIDIGetSource(i)
  let name = midiName(source)
  let hay = name.lowercased()
  var score = -1
  if hay.contains("lpx midi out") { score = 100 }
  else if hay.contains("launchpad") && hay.contains("midi out") { score = 95 }
  else if hay.contains("lpx daw out") { score = 80 }
  else if hay.contains("launchpad") || hay.contains("novation") || hay.contains("lpx") { score = 70 }
  if score > selectedScore {
    selectedScore = score
    selected = source
    selectedName = name
  }
}

let destinationCount = MIDIGetNumberOfDestinations()
var selectedDestinationName = ""
var selectedDestinationScore = -1
for i in 0..<destinationCount {
  let destination = MIDIGetDestination(i)
  let name = midiName(destination)
  let hay = name.lowercased()
  var score = -1
  if hay.contains("lpx midi in") { score = 100 }
  else if hay.contains("launchpad") && hay.contains("midi in") { score = 95 }
  else if hay.contains("lpx daw in") { score = 80 }
  else if hay.contains("launchpad") || hay.contains("novation") || hay.contains("lpx") { score = 70 }
  if score > selectedDestinationScore {
    selectedDestinationScore = score
    selectedDestination = destination
    selectedDestinationName = name
  }
}

if selected == 0 {
  print("RDFT Launchpad bridge: no Launchpad MIDI source found.")
  exit(2)
}

MIDIPortConnectSource(inputPort, selected, nil)
if paintLaunchpad { paintRDFTPage(activePage) }
if selectedDestination == 0 {
  print("RDFT Launchpad bridge connected: \(selectedName) -> \(host):\(port); no LPX MIDI input found for pad colors")
} else {
  print("RDFT Launchpad bridge connected: \(selectedName) -> \(host):\(port); colors \(paintLaunchpad ? "enabled" : "preserved") -> \(selectedDestinationName)")
}
fflush(stdout)
while true {
  RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.5))
  if paintLaunchpad && selectedDestination != 0 && CFAbsoluteTimeGetCurrent() - lastFullPaint > 8.0 {
    paintRDFTPage(activePage)
  }
}
