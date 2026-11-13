// Streams CPU, GPU, RAM, SSD, and network usage to SwiftBar as one menu bar item: an image of small
// framed, colored line charts (like Stats' line_chart and network_chart widgets), rendered once for
// a light menu bar and once for a dark one, plus a dropdown with exact values. Everything is read from Mach, IOKit, and SystemConfiguration directly, so no
// helper processes are spawned per sample. Built and launched by plugins/system-stats.sh.

import AppKit
import IOKit
import SystemConfiguration

let interval: TimeInterval = 1
let chartHeight: CGFloat = 18
let chartWidth: CGFloat = 32
let labelWidth: CGFloat = 6
let moduleGap: CGFloat = 5
// One sample per point of chart width.
let historyLength = Int(chartWidth) - 2
// Smallest full-scale value for the rate charts, so idle background traffic stays near the axis.
let diskScaleFloor = 1_000_000.0
let networkScaleFloor = 100_000.0

// MARK: - Sampling

let host = mach_host_self()

func sysctlValue<T: BitwiseCopyable>(_ name: String, _ initial: T) -> T? {
    var value = initial
    var size = MemoryLayout<T>.size
    return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
}

func ioServices(_ className: String, _ body: (io_object_t) -> Void) {
    var iterator = io_iterator_t()
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(className), &iterator) == KERN_SUCCESS else { return }
    defer { IOObjectRelease(iterator) }
    while case let service = IOIteratorNext(iterator), service != 0 {
        body(service)
        IOObjectRelease(service)
    }
}

func ioProperty(_ entry: io_registry_entry_t, _ key: String) -> [String: Any]? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any]
}

/// Cumulative (user, system, idle, nice) ticks across all cores. They're 32-bit and wrap.
func cpuTicks() -> [UInt32] {
    var info = host_cpu_load_info()
    var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
    }
    guard result == KERN_SUCCESS else { return [0, 0, 0, 0] }
    let ticks = info.cpu_ticks
    return [ticks.0, ticks.1, ticks.2, ticks.3]
}

/// Highest "Device Utilization %" across GPUs (Apple Silicon has one).
func gpuUtilization() -> Double? {
    var utilization: Int?
    ioServices("IOAccelerator") { service in
        if let value = ioProperty(service, "PerformanceStatistics")?["Device Utilization %"] as? Int {
            utilization = max(utilization ?? 0, value)
        }
    }
    return utilization.map { Double($0) / 100 }
}

struct Memory {
    var used: UInt64 = 0
    var total: UInt64 = 0
    var swapUsed: UInt64 = 0
    var pressure: Int32 = 0
}

/// "Memory Used" as Activity Monitor computes it: app memory + wired + compressed.
func memory() -> Memory {
    var memory = Memory()
    memory.total = sysctlValue("hw.memsize", UInt64(0)) ?? 0
    memory.swapUsed = sysctlValue("vm.swapusage", xsw_usage())?.xsu_used ?? 0
    memory.pressure = sysctlValue("kern.memorystatus_vm_pressure_level", Int32(0)) ?? 0

    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
    let result = withUnsafeMutablePointer(to: &stats) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
    }
    guard result == KERN_SUCCESS else { return memory }
    let app = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
    let pages = app + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
    memory.used = pages * UInt64(getpagesize())
    return memory
}

/// Cumulative bytes read and written by internal drives. Skips disk images and other virtual
/// disks, whose I/O already passes through the physical drive.
func diskBytes() -> (read: UInt64, write: UInt64) {
    var read: UInt64 = 0, write: UInt64 = 0
    ioServices("IOBlockStorageDriver") { driver in
        var device = io_registry_entry_t()
        guard IORegistryEntryGetParentEntry(driver, "IOService", &device) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(device) }
        guard ioProperty(device, "Protocol Characteristics")?["Physical Interconnect Location"] as? String == "Internal",
              let stats = ioProperty(driver, "Statistics") else { return }
        read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
        write += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
    }
    return (read, write)
}

func diskSpace() -> (free: Int64, total: Int64)? {
    let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
    guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
          let free = values.volumeAvailableCapacityForImportantUsage,
          let total = values.volumeTotalCapacity else { return nil }
    return (free, Int64(total))
}

let dynamicStore = SCDynamicStoreCreate(nil, "system-stats" as CFString, nil, nil)

/// The interface carrying the default route, so bridges, VMs, and VPN tunnels aren't double-counted.
func primaryInterface() -> String? {
    guard let dynamicStore else { return nil }
    for key in ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] {
        if let state = SCDynamicStoreCopyValue(dynamicStore, key as CFString) as? [String: Any],
           let name = state["PrimaryInterface"] as? String {
            return name
        }
    }
    return nil
}

/// Cumulative bytes in and out on an interface. These are 32-bit and wrap.
func interfaceBytes(_ name: String) -> (received: UInt32, sent: UInt32)? {
    var addresses: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addresses) == 0 else { return nil }
    defer { freeifaddrs(addresses) }
    var cursor = addresses
    while let address = cursor?.pointee {
        defer { cursor = address.ifa_next }
        guard address.ifa_addr?.pointee.sa_family == UInt8(AF_LINK), String(cString: address.ifa_name) == name,
              let data = address.ifa_data?.assumingMemoryBound(to: if_data.self).pointee else { continue }
        return (data.ifi_ibytes, data.ifi_obytes)
    }
    return nil
}

struct Sample {
    var cpuUser = 0.0, cpuSystem = 0.0
    var gpu: Double?
    var memory = Memory()
    var diskRead = 0.0, diskWrite = 0.0
    var interface: String?
    var networkIn = 0.0, networkOut = 0.0
    var cpu: Double { cpuUser + cpuSystem }
    var ram: Double { memory.total > 0 ? Double(memory.used) / Double(memory.total) : 0 }
}

/// Holds the previous cumulative counters, so each sample reports usage since the last one.
struct Sampler {
    var time = ProcessInfo.processInfo.systemUptime
    var ticks = cpuTicks()
    var disk = diskBytes()
    var interface = primaryInterface()
    var network: (received: UInt32, sent: UInt32)?

    init() { network = interface.flatMap(interfaceBytes) }

    mutating func sample() -> Sample {
        var sample = Sample()
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = max(now - time, 0.001)
        time = now

        let newTicks = cpuTicks()
        let delta = zip(newTicks, ticks).map { Double($0 &- $1) }
        ticks = newTicks
        let totalTicks = delta.reduce(0, +)
        if totalTicks > 0 {
            sample.cpuUser = (delta[0] + delta[3]) / totalTicks
            sample.cpuSystem = delta[1] / totalTicks
        }

        sample.gpu = gpuUtilization()
        sample.memory = memory()

        let newDisk = diskBytes()
        // Counters drop when a drive disappears; treat that interval as idle.
        sample.diskRead = Double(newDisk.read >= disk.read ? newDisk.read - disk.read : 0) / elapsed
        sample.diskWrite = Double(newDisk.write >= disk.write ? newDisk.write - disk.write : 0) / elapsed
        disk = newDisk

        let newInterface = primaryInterface()
        let newNetwork = newInterface.flatMap(interfaceBytes)
        // A different interface has unrelated counters; start a fresh baseline.
        if newInterface == interface, let old = network, let new = newNetwork {
            sample.networkIn = Double(new.received &- old.received) / elapsed
            sample.networkOut = Double(new.sent &- old.sent) / elapsed
        }
        interface = newInterface
        network = newNetwork
        sample.interface = newInterface
        return sample
    }
}

// MARK: - Rendering

struct History {
    var values: [Double] = []
    mutating func append(_ value: Double) {
        values.append(value)
        if values.count > historyLength { values.removeFirst(values.count - historyLength) }
    }
}

/// Points for values scaled to [0, 1], right-aligned so the newest sample is at the right edge.
func chartPoints(_ values: [Double], in rect: NSRect, baseline: CGFloat, height: CGFloat) -> [NSPoint] {
    let step = rect.width / CGFloat(historyLength - 1)
    let start = rect.maxX - step * CGFloat(values.count - 1)
    return values.enumerated().map { index, value in
        NSPoint(x: start + step * CGFloat(index), y: baseline + height * CGFloat(min(max(value, 0), 1)))
    }
}

/// Stats' "utilization" color scheme (usageColor in its Kit/extensions.swift).
func utilizationColor(_ fraction: Double) -> NSColor {
    switch fraction {
    case ...0.6: .systemBlue
    case ...0.8: .orange
    default: .red
    }
}

func drawSeries(_ points: [NSPoint], baseline: CGFloat, color: NSColor) {
    guard let first = points.first, let last = points.last else { return }
    let line = NSBezierPath()
    line.move(to: first)
    points.dropFirst().forEach { line.line(to: $0) }
    let fill = line.copy() as! NSBezierPath
    fill.line(to: NSPoint(x: last.x, y: baseline))
    fill.line(to: NSPoint(x: first.x, y: baseline))
    fill.close()
    color.withAlphaComponent(0.35).setFill()
    fill.fill()
    color.setStroke()
    line.lineWidth = 1
    line.lineJoinStyle = .round
    line.stroke()
}

/// Draws a vertical label and an empty frame at x, returning the frame's inner rect.
func drawModule(_ label: String, at x: CGFloat) -> NSRect {
    let font = NSFont.systemFont(ofSize: 6.5, weight: .bold)
    let letterHeight = chartHeight / CGFloat(label.count)
    for (index, letter) in label.enumerated() {
        let text = NSAttributedString(string: String(letter), attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        let size = text.size()
        let y = chartHeight - letterHeight * CGFloat(index + 1) + (letterHeight - size.height) / 2
        text.draw(at: NSPoint(x: x + (labelWidth - size.width) / 2, y: y))
    }
    let frame = NSRect(x: x + labelWidth + 1, y: 0, width: chartWidth, height: chartHeight).insetBy(dx: 0.5, dy: 0.5)
    let border = NSBezierPath(roundedRect: frame, xRadius: 2.5, yRadius: 2.5)
    border.lineWidth = 1
    NSColor.secondaryLabelColor.setStroke()
    border.stroke()
    return frame.insetBy(dx: 1.5, dy: 1.5)
}

/// Colored by the latest value, as Stats does.
func drawLineChart(_ label: String, _ history: History, at x: CGFloat) {
    let rect = drawModule(label, at: x)
    let color = utilizationColor(history.values.last ?? 0)
    drawSeries(chartPoints(history.values, in: rect, baseline: rect.minY, height: rect.height), baseline: rect.minY, color: color)
}

/// Incoming rate (blue) above the midline and outgoing (red) below it, on a shared autoscaled axis,
/// in Stats' default read/write colors.
func drawRateChart(_ label: String, up: History, down: History, floor: Double, at x: CGFloat) {
    let rect = drawModule(label, at: x)
    let scale = max(floor, up.values.max() ?? 0, down.values.max() ?? 0)
    let mid = rect.midY
    let half = rect.height / 2
    drawSeries(chartPoints(up.values.map { $0 / scale }, in: rect, baseline: mid, height: half), baseline: mid, color: .systemBlue)
    drawSeries(chartPoints(down.values.map { $0 / scale }, in: rect, baseline: mid, height: -half), baseline: mid, color: .systemRed)
    // A neutral axis on top, so idle stretches (both series flat at zero) don't read as red. It
    // replaces the pixels beneath rather than blending, since the color is translucent.
    let axis = NSBezierPath()
    axis.move(to: NSPoint(x: rect.minX, y: mid))
    axis.line(to: NSPoint(x: rect.maxX, y: mid))
    axis.lineWidth = 1
    NSColor.secondaryLabelColor.setStroke()
    NSGraphicsContext.current?.compositingOperation = .copy
    axis.stroke()
    NSGraphicsContext.current?.compositingOperation = .sourceOver
}

/// Renders at 2x with 144 DPI metadata, which SwiftBar's NSImage(data:) reads as a 1x point size.
/// Dynamic colors (label, system green, etc.) resolve for the given appearance.
func renderPNG(width: CGFloat, appearance: NSAppearance.Name, _ draw: () -> Void) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * 2), pixelsHigh: Int(chartHeight * 2),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    bitmap.size = NSSize(width: width, height: chartHeight)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSAppearance(named: appearance)?.performAsCurrentDrawingAppearance(draw)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

// MARK: - Output

func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

/// Decimal units by default, matching Finder; memory uses binary (base 1024), matching Activity Monitor.
func bytes(_ count: Double, base: Double = 1000) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = count
    var unit = 0
    while value >= base, unit < units.count - 1 {
        value /= base
        unit += 1
    }
    return unit == 0 || value >= 100 ? "\(Int(value.rounded())) \(units[unit])" : String(format: "%.1f %@", value, units[unit])
}

func rate(_ perSecond: Double) -> String { "\(bytes(perSecond))/s" }

var interfaceDescriptions: [String: String] = [:]

/// "Wi-Fi (en0)". Cached, since enumerating interfaces costs more than the rest of a sample.
func interfaceDescription(_ name: String) -> String {
    if let cached = interfaceDescriptions[name] { return cached }
    let interfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []
    let match = interfaces.first { SCNetworkInterfaceGetBSDName($0) as String? == name }
    let description = match.flatMap { SCNetworkInterfaceGetLocalizedDisplayName($0) as String? }.map { "\($0) (\(name))" } ?? name
    interfaceDescriptions[name] = description
    return description
}

/// light and dark are base64 PNGs; SwiftBar picks one to match the menu bar's appearance.
func menu(_ sample: Sample, light: String, dark: String) -> String {
    let pressure = [1: "Normal", 2: "Warning", 4: "Critical"][Int(sample.memory.pressure)] ?? "Unknown"
    let gpu = sample.gpu.map(percent) ?? "n/a"
    let tooltip = "CPU \(percent(sample.cpu)), GPU \(gpu), RAM \(percent(sample.ram))"
    var lines = [
        "| image=\(light),\(dark) tooltip=\"\(tooltip)\"",
        "---",
        "CPU: \(percent(sample.cpu)) | sfimage=cpu",
        "User \(percent(sample.cpuUser)), System \(percent(sample.cpuSystem))",
        "---",
        "GPU: \(gpu) | sfimage=display",
        "---",
        "RAM: \(percent(sample.ram)) | sfimage=memorychip",
        "\(bytes(Double(sample.memory.used), base: 1024)) of \(bytes(Double(sample.memory.total), base: 1024)) used",
        "Swap \(bytes(Double(sample.memory.swapUsed), base: 1024)), Pressure \(pressure)",
        "---",
        "SSD: \u{2193} \(rate(sample.diskRead))  \u{2191} \(rate(sample.diskWrite)) | sfimage=internaldrive",
        "Read above the line, write below",
    ]
    if let space = diskSpace() {
        lines.append("\(bytes(Double(space.free))) free of \(bytes(Double(space.total)))")
    }
    lines += [
        "---",
        "Network: \u{2193} \(rate(sample.networkIn))  \u{2191} \(rate(sample.networkOut)) | sfimage=network",
        "Download above the line, upload below",
        sample.interface.map(interfaceDescription) ?? "Offline",
        "---",
        "Open Activity Monitor | bash=/usr/bin/open param1=-b param2=com.apple.ActivityMonitor terminal=false",
    ]
    return lines.joined(separator: "\n")
}

var sampler = Sampler()
var cpuHistory = History(), gpuHistory = History(), ramHistory = History()
var diskReadHistory = History(), diskWriteHistory = History()
var networkInHistory = History(), networkOutHistory = History()
let moduleWidth = labelWidth + 1 + chartWidth
let imageWidth = moduleWidth * 5 + moduleGap * 4

while true {
    Thread.sleep(forTimeInterval: interval)
    autoreleasepool {
        let sample = sampler.sample()
        cpuHistory.append(sample.cpu)
        gpuHistory.append(sample.gpu ?? 0)
        ramHistory.append(sample.ram)
        diskReadHistory.append(sample.diskRead)
        diskWriteHistory.append(sample.diskWrite)
        networkInHistory.append(sample.networkIn)
        networkOutHistory.append(sample.networkOut)

        let images = [NSAppearance.Name.aqua, .darkAqua].compactMap { appearance in
            renderPNG(width: imageWidth, appearance: appearance) {
                let x = { (index: Int) in CGFloat(index) * (moduleWidth + moduleGap) }
                drawLineChart("CPU", cpuHistory, at: x(0))
                drawLineChart("GPU", gpuHistory, at: x(1))
                drawLineChart("RAM", ramHistory, at: x(2))
                drawRateChart("SSD", up: diskReadHistory, down: diskWriteHistory, floor: diskScaleFloor, at: x(3))
                drawRateChart("NET", up: networkInHistory, down: networkOutHistory, floor: networkScaleFloor, at: x(4))
            }?.base64EncodedString()
        }
        guard images.count == 2 else { return }
        print("~~~\n" + menu(sample, light: images[0], dark: images[1]))
        fflush(stdout)
    }
}
