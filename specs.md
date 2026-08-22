# Build PulseBar — Native macOS System Monitor

Build a production-ready native macOS menu-bar system monitoring application inspired by GNOME Vitals.

The app should be lightweight, responsive, visually native to macOS, and optimized for low idle CPU and memory usage.

Do **not** build this using Electron, Tauri, MAUI, web technologies, or an embedded browser.

Use native macOS technologies.

## Primary Goal

Create a macOS menu-bar application that continuously monitors important system metrics and lets the user choose which metrics are displayed directly in the menu bar.

Example menu-bar output:

`CPU 12% · RAM 41% · 48°C · ↓3.4M ↑420K`

Clicking the menu-bar item should open a compact professional dashboard similar in purpose to:

* GNOME Vitals
* iStat Menus
* Activity Monitor

Do not copy their UI directly.

Design it as a modern native macOS utility.

---

# Technology

Use:

* Swift
* SwiftUI
* Foundation
* AppKit only where required
* Mach APIs for CPU/memory
* IOKit where appropriate
* Network/system APIs available on macOS
* Swift Charts for history graphs if suitable
* `MenuBarExtra`
* `@Observable` / modern Swift Observation where appropriate

Target:

* macOS 14+
* Apple Silicon as the primary target
* Intel Macs should work where practical

Avoid third-party dependencies unless there is a strong technical reason.

Prefer Apple frameworks.

---

# Application Type

This must be a menu-bar utility.

The application should:

* live primarily in the macOS menu bar
* not show a Dock icon by default
* support Launch at Login
* open a rich SwiftUI popover/window from the menu bar
* support Settings
* have minimal background CPU utilization

Use the appropriate macOS application configuration such as `LSUIElement` where required.

---

# Architecture

Keep the architecture simple.

Do not introduce unnecessary Clean Architecture layers, repositories, coordinators, dependency-injection frameworks, or abstractions.

Recommended structure:

```text
PulseBar/
├── App/
│   ├── PulseBarApp.swift
│   └── AppState.swift
│
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift
│   │   └── MenuBarLabel.swift
│   │
│   ├── Dashboard/
│   │   ├── DashboardView.swift
│   │   ├── MetricCard.swift
│   │   └── MiniChart.swift
│   │
│   └── Settings/
│       ├── SettingsView.swift
│       └── SensorSettingsView.swift
│
├── Monitoring/
│   ├── SystemMonitor.swift
│   ├── CPUReader.swift
│   ├── MemoryReader.swift
│   ├── NetworkReader.swift
│   ├── DiskReader.swift
│   ├── StorageReader.swift
│   ├── BatteryReader.swift
│   └── ThermalReader.swift
│
├── Models/
│   ├── SystemMetrics.swift
│   ├── CPUStats.swift
│   ├── MemoryStats.swift
│   └── NetworkStats.swift
│
├── Utilities/
│   ├── ByteFormatter.swift
│   ├── PercentageFormatter.swift
│   └── MetricHistory.swift
│
└── Resources/
```

Adapt the structure if the generated Xcode project already has an appropriate organization.

---

# Core Design Principle

There should be one central:

`SystemMonitor`

responsible for coordinating metric collection.

Individual readers should only know how to retrieve their own metric.

Example:

```text
SystemMonitor
    │
    ├── CPUReader
    ├── MemoryReader
    ├── NetworkReader
    ├── DiskReader
    ├── StorageReader
    ├── BatteryReader
    └── ThermalReader
```

The UI must not directly query operating-system APIs.

UI:

```text
System APIs
     ↓
Metric Readers
     ↓
SystemMonitor
     ↓
SystemMetrics
     ↓
SwiftUI
```

---

# SystemMetrics

Create a central observable snapshot model containing current values.

Conceptually:

```swift
struct SystemMetrics {
    var cpu: CPUStats
    var memory: MemoryStats
    var network: NetworkStats
    var disk: DiskStats
    var storage: StorageStats
    var battery: BatteryStats?
    var thermal: ThermalStats
}
```

Do not force everything into primitive values when a small domain model makes the code clearer.

---

# Phase 1 — Core Monitoring

Implement these first.

## CPU

Display:

* total CPU utilization
* per-core utilization
* logical CPU count
* system load averages where available

Prefer Mach host APIs.

CPU utilization should be calculated from differences between CPU tick snapshots rather than displaying cumulative ticks.

Expected UI:

```text
CPU
12%

Performance
████░░░░░░

Core 1    15%
Core 2     8%
Core 3    22%
...
```

---

# Memory

Display:

* physical memory
* memory used
* memory available
* memory percentage
* wired memory
* compressed memory
* cached/file-backed memory when reliably available
* swap used
* swap total

Use appropriate Mach APIs such as host VM statistics.

Do not calculate memory usage using an inaccurate simplistic formula if macOS exposes better statistics.

Example:

```text
Memory

9.8 GB / 24 GB
41%

App Memory       5.1 GB
Wired            2.0 GB
Compressed       1.4 GB
Swap             0 MB
```

---

# Network

Monitor system network throughput.

Display:

* current download bytes/sec
* current upload bytes/sec
* total received
* total transmitted

Calculate rates using differences between previous and current samples.

Ignore interfaces that should not count toward normal traffic when appropriate.

Correctly handle:

* Wi-Fi
* Ethernet
* VPN
* Thunderbolt networking

Avoid double-counting interfaces whenever possible.

Use human-friendly formatting:

```text
421 B/s
18 KB/s
4.2 MB/s
1.1 GB/s
```

---

# Disk I/O

Display:

* current read rate
* current write rate
* cumulative read bytes
* cumulative written bytes where available

Example:

```text
Disk

Read     183 MB/s
Write     12 MB/s
```

Disk throughput must be based on deltas between samples.

---

# Storage

Display:

* total system disk capacity
* used space
* available space
* percentage used

Example:

```text
Storage

321 GB / 512 GB
63%
```

---

# Battery

When running on a MacBook, display:

* battery percentage
* charging state
* AC power status
* estimated remaining time when reliably available
* cycle count if obtainable through supported APIs
* battery health/capacity information where reliably available

Desktop Macs should simply hide the battery section.

Never show empty placeholder battery UI on machines without a battery.

---

# Thermal State

Use macOS-supported APIs to expose system thermal pressure/state.

Display:

```text
Thermal

Nominal
Fair
Serious
Critical
```

Use:

`ProcessInfo.processInfo.thermalState`

Treat actual CPU/GPU temperature sensors separately from macOS thermal state.

---

# Phase 2 — Menu Bar

The user must be able to choose exactly what appears in the menu bar.

Supported items:

* CPU %
* Memory %
* temperature when available
* fan RPM when available
* network download
* network upload
* disk read
* disk write
* battery %

Example:

```text
CPU 8% · RAM 42% · ↓3.2M ↑420K
```

Alternative compact display:

```text
8% · 42% · ↓3.2M
```

Settings must allow:

```text
Menu Bar

[x] CPU
[x] Memory
[ ] Temperature
[ ] Fan
[x] Download
[x] Upload
[ ] Disk Read
[ ] Disk Write
[ ] Battery
```

Allow reordering if it can be implemented cleanly without introducing unnecessary complexity.

If reordering significantly complicates V1, use a sensible fixed order.

---

# Menu Bar UX

Use `MenuBarExtra`.

Prefer the richer window presentation style instead of a basic NSMenu.

The menu-bar label should update efficiently.

Do not redraw unrelated parts of the UI unnecessarily.

Do not allow the menu-bar text to become excessively wide.

Provide:

* Standard mode
* Compact mode

---

# Dashboard UI

The dashboard should feel like a polished macOS utility.

Target approximately:

```text
┌────────────────────────────────────┐
│ PulseBar                       ⚙︎  │
│ MacBook Pro · Apple Silicon        │
├────────────────────────────────────┤
│ CPU                         12%     │
│ █████░░░░░░░░░░░░                  │
│ ▁▂▃▅▇▆▃▂▃▅▇▄                     │
├────────────────────────────────────┤
│ MEMORY                 9.8 / 24 GB │
│ ████████░░░░░░░░                   │
├────────────────────────────────────┤
│ NETWORK                            │
│ ↓ 8.3 MB/s       ↑ 1.2 MB/s        │
│ ▁▂▅▇▆▃▂▅▇▅▃                       │
├────────────────────────────────────┤
│ DISK                               │
│ ↓ 183 MB/s       ↑ 12 MB/s         │
├────────────────────────────────────┤
│ BATTERY                            │
│ 87% · Charging                     │
├────────────────────────────────────┤
│ Thermal                     Nominal │
└────────────────────────────────────┘
```

Use native SwiftUI styling.

Avoid excessive:

* cards
* borders
* gradients
* shadows
* giant headers
* padding

Make it compact.

Use separators and hierarchy instead of wrapping everything in individual cards.

---

# Metric History

Maintain short in-memory histories for:

* CPU
* memory
* download
* upload
* disk read
* disk write

Store approximately the last:

`60–120 samples`

Do not introduce a database for this.

The history exists only for mini graphs.

Use a bounded structure.

Never allow arrays to grow indefinitely.

---

# Charts

Use compact sparklines.

Do not display:

* chart legends
* axis labels
* excessive grid lines
* interaction controls

These graphs exist to communicate recent activity quickly.

Prefer lightweight rendering.

---

# Polling

Do not use one refresh rate blindly for all metrics.

Initial defaults:

```text
CPU              1 second
Network          1 second
Memory           2 seconds
Disk             2 seconds
Thermal          3 seconds
Battery          5 seconds
Storage         30 seconds
```

However, avoid creating many independent timers.

Prefer one monitoring task or scheduler that coordinates metric refresh intervals.

---

# Concurrency

Use modern Swift concurrency.

Avoid blocking the main actor.

System metric collection should happen away from UI rendering when appropriate.

Publish UI changes safely.

Avoid:

* timer leaks
* detached task leaks
* retain cycles
* overlapping metric polling jobs

When one refresh hasn't completed, do not continuously start more copies of the same expensive operation.

---

# Performance Requirement

PulseBar is itself a monitoring utility, so its own resource consumption is important.

Targets under normal idle monitoring:

* negligible CPU usage
* low wake-up frequency
* low memory footprint
* no significant battery drain
* no unnecessary disk writes

Never continuously write history to disk.

---

# Settings

Create a native Settings window.

Sections:

## General

* Launch at Login
* Refresh speed
* Appearance

Appearance:

```text
System
Light
Dark
```

Prefer following system appearance by default.

---

## Menu Bar

Configure visible menu-bar metrics.

---

## Monitoring

Allow enable/disable of more expensive monitoring categories.

Example:

```text
[x] CPU
[x] Memory
[x] Network
[x] Disk
[x] Battery
[x] Thermal

Experimental

[ ] Hardware Sensors
```

---

# Refresh Speed

Provide simple presets.

Example:

```text
Low Power     3 seconds
Normal        1 second
Fast          0.5 second
```

Default:

`Normal`

Do not allow extremely aggressive polling that could cause the monitoring application itself to consume significant resources.

---

# Launch at Login

Use the modern Apple-supported API where possible.

Avoid legacy login-item hacks.

Show the actual system state correctly in Settings.

---

# Phase 3 — Hardware Sensors

Keep hardware sensor code isolated from the stable V1 monitoring system.

Create:

```text
HardwareSensorProvider
```

or similarly small abstraction.

Potential sensors:

* CPU temperature
* GPU temperature
* SSD temperature
* fan RPM
* CPU power
* GPU power
* system power
* voltage
* current

Do not allow hardware sensor support to make CPU/memory/network monitoring dependent upon private APIs.

The app should operate normally when no low-level sensors are available.

Use optional values.

Example:

```swift
struct HardwareSensorSnapshot {
    var cpuTemperature: Double?
    var gpuTemperature: Double?
    var fanRPM: Double?
    var cpuPower: Double?
    var gpuPower: Double?
}
```

---

# Apple Silicon

Apple Silicon should be treated as the primary hardware platform.

Detect relevant machine information.

Display basic hardware metadata where useful:

```text
MacBook Pro
Apple M5
24 GB
```

Do not hardcode processor model names.

---

# Sensor Safety

Do not modify:

* SMC values
* fan speeds
* voltage
* power limits
* thermal controls

PulseBar is monitoring-only.

No hardware control.

---

# Unsupported Sensors

If a metric cannot be obtained reliably:

Do not:

```text
Temperature 0°C
Fan 0 RPM
```

Instead hide it or display:

```text
Unavailable
```

where appropriate.

The UI should degrade gracefully.

---

# Privileges

V1 should not require administrator/root privileges.

If future hardware telemetry requires elevated privileges, keep that feature optional and isolated.

Do not make the entire application require administrator access.

---

# Error Handling

Metric failures should never crash the application.

Each monitoring provider should safely handle unavailable system data.

Examples:

* missing battery
* unavailable sensor
* interface disappearing
* Wi-Fi changing to Ethernet
* sleep/wake
* VPN interface appearing
* disk unmount
* network reconnect

Recover on the next monitoring cycle where possible.

Do not create elaborate retry frameworks.

---

# Sleep / Wake

Handle macOS system sleep and wake cleanly.

After waking:

* reset delta-based CPU measurements if necessary
* reset network baselines
* reset disk baselines
* avoid huge false throughput spikes

For example:

If network bytes before sleep were:

`100 GB`

and after wake:

`101 GB`

do not interpret accumulated traffic during sleep as an instantaneous 1 GB/s spike.

---

# Formatting Utilities

Centralize formatting.

Examples:

```text
0 B/s
430 KB/s
8.2 MB/s

41%
9.8 GB
183 MB/s
48°C
2,100 RPM
```

Do not duplicate formatting logic throughout views.

---

# Number Precision

Keep numbers readable.

Examples:

```text
CPU     12%
RAM     41%
Temp    48°C

Network
3.4 MB/s

Disk
183 MB/s
```

Avoid:

```text
CPU 12.349473%
```

---

# Accessibility

Support:

* VoiceOver labels
* sufficient contrast
* macOS Dynamic Type where reasonable
* descriptive accessibility labels for icon-only controls

Do not rely only on color to communicate thermal severity.

---

# Keyboard / Native Behavior

Ensure Settings behaves as a normal macOS settings window.

Use:

`Cmd + ,`

where appropriate.

Provide:

`Quit PulseBar`

from the menu/popover.

---

# Testing

Add focused tests.

Do not attempt to unit-test operating-system APIs directly.

Instead test deterministic logic such as:

## CPU calculation

Given previous and current CPU ticks:

verify correct percentage calculation.

## Throughput

Example:

Previous:

`1,000,000 bytes`

Current:

`4,000,000 bytes`

Elapsed:

`1 second`

Expected:

`3 MB/s`

## Formatting

Test:

* bytes
* percentages
* transfer rates
* storage sizes

## Metric history

Verify:

* maximum sample count
* old samples are discarded

## Sleep/reset logic

Verify counters reset without generating invalid throughput spikes.

---

# Development Approach

Implement this incrementally.

Do not attempt every sensor immediately.

Order:

## Step 1

Create working menu-bar application.

Verify:

* launches
* has no Dock icon
* menu bar icon/text appears
* popover opens
* Settings works
* Quit works

## Step 2

Implement CPU monitoring.

## Step 3

Implement memory monitoring.

## Step 4

Implement network monitoring.

## Step 5

Implement disk and storage.

## Step 6

Implement battery and thermal state.

## Step 7

Build dashboard UI.

## Step 8

Add history graphs.

## Step 9

Add Settings and configurable menu-bar metrics.

## Step 10

Measure and optimize resource usage.

Only after V1 is stable:

## Step 11

Investigate Apple Silicon hardware sensors.

---

# Important Scope Control

Do not implement yet:

* cloud synchronization
* user accounts
* databases
* telemetry backend
* analytics service
* remote monitoring
* web dashboard
* notifications server
* Docker
* API backend
* automatic fan control
* process killing
* system optimization
* AI features

This is a local native system-monitoring utility.

---

# UX Standard

Aim for:

* compact
* modern
* native
* professional
* information-dense
* readable
* fast

Think:

`Activity Monitor + modern menu-bar utility`

rather than:

`web admin dashboard inside a popover`

Use Apple's spacing, typography, materials, controls, and interaction conventions.

---

# No Over-Engineering

Choose the simplest implementation that reliably satisfies the requirements.

Specifically:

* don't create protocol abstractions for every one-line service
* don't introduce dependency injection frameworks
* don't introduce Redux-style state management
* don't introduce networking layers when there is no backend
* don't introduce a database for temporary metrics
* don't create generic repositories
* don't prematurely build plugin systems
* don't build unsupported future functionality

Use abstractions only where they solve an actual problem.

The main exception is hardware sensor access, which should remain isolated because its availability differs substantially between hardware generations.

---

# Code Quality

Use:

* clear Swift naming
* small focused types
* straightforward state management
* proper Swift concurrency
* safe resource management
* appropriate value types
* minimal global state

Avoid:

* giant SwiftUI views
* giant `SystemMonitor.swift`
* duplicated formatting
* scattered timers
* force unwraps
* unexplained magic numbers

---

# First Development Milestone

The first milestone is successful when PulseBar can show:

```text
Menu Bar
CPU 12% · RAM 41% · ↓3.4M ↑420K
```

and clicking it shows:

```text
CPU
Memory
Network
Disk
Storage
Battery
Thermal
```

with live updates and short activity graphs.

Hardware temperature and fan telemetry are explicitly **not required to declare V1 complete**.

---

# Definition of Done — V1

V1 is complete when:

* menu-bar-only application works correctly
* CPU usage is accurate
* memory usage is accurate
* network rates update correctly
* disk activity updates correctly
* storage usage is displayed
* battery information works on MacBooks
* thermal state is displayed
* short metric histories work
* menu-bar metrics are configurable
* refresh interval is configurable
* Launch at Login works
* Settings window works
* sleep/wake does not create incorrect spikes
* monitoring failures don't crash the app
* the UI looks polished on light and dark mode
* the application has low resource utilization
* focused calculation/formatting tests pass

---

# Before Implementing

Inspect the project first.

If this is a new repository:

1. establish the minimal native macOS SwiftUI project
2. establish the folder structure
3. implement only the first milestone
4. compile and run tests
5. resolve warnings and runtime issues
6. continue incrementally

Do not generate placeholder architecture for future features.

When uncertain about a macOS system API, prefer documented/public Apple APIs for V1.

For low-level sensor support, clearly identify which parts use unsupported/private/undocumented interfaces before introducing them.

---

# Final Deliverable

Produce a working native macOS application named:

**PulseBar**

with a compact polished interface that gives users GNOME-Vitals-style system information directly from the macOS menu bar.

Prioritize:

1. correctness
2. low resource consumption
3. native macOS experience
4. reliability
5. maintainability
6. additional sensors

Do not sacrifice the first five priorities merely to obtain more sensor values.
