<overview>
Mobile is a first-class platform for agent-native apps. It has unique constraints and opportunities. This guide covers why mobile matters, iOS storage architecture, checkpoint/resume patterns, and cost-aware design.
</overview>

<why_mobile>
## Why Mobile Matters

Mobile devices offer unique advantages for agent-native apps:

### A File System
Agents can work with files naturally, using the same primitives that work everywhere else. The filesystem is the universal interface.

### Rich Context
A walled garden you get access to. Health data, location, photos, calendars—context that doesn't exist on desktop or web. This enables deeply personalized agent experiences.

### Local Apps
Everyone has their own copy of the app. This opens opportunities that aren't fully realized yet: apps that modify themselves, fork themselves, evolve per-user. App Store policies constrain some of this today, but the foundation is there.

### Cross-Device Sync
If you use the file system with iCloud, all devices share the same file system. The agent's work on one device appears on all devices—without you having to build a server.

### The Challenge

**Agents are long-running. Mobile apps are not.**

An agent might need 30 seconds, 5 minutes, or an hour to complete a task. But iOS will background your app after seconds of inactivity, and may kill it entirely to reclaim memory. The user might switch apps, take a call, or lock their phone mid-task.

This means mobile agent apps need:
- **Checkpointing** -- Saving state so work isn't lost
- **Resuming** -- Picking up where you left off after interruption
- **Background execution** -- Using the limited time iOS gives you wisely
- **On-device vs. cloud decisions** -- What runs locally vs. what needs a server
</why_mobile>

<ios_storage>
## iOS Storage Architecture

For agent-native iOS apps, use iCloud Drive's Documents folder for your shared workspace. This gives you **free, automatic multi-device sync** without building a sync layer or running a server.

### Why iCloud Documents?

| Approach | Cost | Complexity | Offline | Multi-Device |
|----------|------|------------|---------|--------------|
| Custom backend + sync | $$$ | High | Manual | Yes |
| CloudKit database | Free tier limits | Medium | Manual | Yes |
| **iCloud Documents** | Free (user's storage) | Low | Automatic | Automatic |

### Implementation: iCloud-First with Local Fallback

```swift
func iCloudDocumentsURL() -> URL? {
    FileManager.default.url(forUbiquityContainerIdentifier: nil)?
        .appendingPathComponent("Documents")
}

class SharedWorkspace {
    let rootURL: URL

    init() {
        if let iCloudURL = iCloudDocumentsURL() {
            self.rootURL = iCloudURL
        } else {
            self.rootURL = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
        }
    }
}
```

### Handling iCloud File States

```swift
func readFile(at url: URL) throws -> String {
    if url.pathExtension == "icloud" {
        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        throw FileNotYetAvailableError()
    }
    return try String(contentsOf: url, encoding: .utf8)
}

func writeFile(_ content: String, to url: URL) throws {
    let coordinator = NSFileCoordinator()
    var error: NSError?
    coordinator.coordinate(
        writingItemAt: url,
        options: .forReplacing,
        error: &error
    ) { newURL in
        try? content.write(to: newURL, atomically: true, encoding: .utf8)
    }
    if let error = error { throw error }
}
```

### When NOT to Use iCloud Documents

- **Sensitive data** - Use Keychain or encrypted local storage instead
- **High-frequency writes** - iCloud sync has latency; use local + periodic sync
- **Large media files** - Consider CloudKit Assets or on-demand resources
- **Shared between users** - iCloud Documents is single-user; use CloudKit for sharing
</ios_storage>

<background_execution>
## Background Execution & Resumption

Mobile apps can be suspended or terminated at any time. Agents must handle this gracefully.

### Checkpoint/Resume Pattern

```swift
class AgentOrchestrator: ObservableObject {
    @Published var activeSessions: [AgentSession] = []

    func handleAppWillBackground() {
        for session in activeSessions {
            saveCheckpoint(session)
            session.transition(to: .backgrounded)
        }
    }

    func handleAppDidForeground() {
        for session in activeSessions where session.state == .backgrounded {
            if let checkpoint = loadCheckpoint(session.id) {
                resumeFromCheckpoint(session, checkpoint)
            }
        }
    }
}
```

### State Machine for Agent Lifecycle

```swift
enum AgentState {
    case idle           // Not running
    case running        // Actively executing
    case waitingForUser // Paused, waiting for user input
    case backgrounded   // App backgrounded, state saved
    case completed      // Finished successfully
    case failed(Error)  // Finished with error
}
```

### Background Task Extension (iOS)

```swift
class AgentOrchestrator {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func handleAppWillBackground() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }

        Task {
            for session in activeSessions {
                await saveCheckpoint(session)
            }
            endBackgroundTask()
        }
    }
}
```
</background_execution>

<permissions>
## Permission Handling

### Common Permissions

| Resource | iOS Permission | Use Case |
|----------|---------------|----------|
| Photo Library | PHPhotoLibrary | Profile generation from photos |
| Files | Document picker | Reading user documents |
| Camera | AVCaptureDevice | Scanning book covers |
| Location | CLLocationManager | Location-aware recommendations |
| Network | (automatic) | Web search, API calls |

### Permission-Aware Tools

Check permissions before executing:

```swift
struct PhotoTools {
    static func readPhotos() -> AgentTool {
        tool(
            name: "read_photos",
            description: "Read photos from the user's photo library",
            execute: { params, context in
                let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
                switch status {
                case .authorized, .limited:
                    let photos = await fetchPhotos(params)
                    return ToolResult(text: "Found \(photos.count) photos", images: photos)
                case .denied, .restricted:
                    return ToolResult(
                        text: "Photo access needed. Please grant permission in Settings.",
                        isError: true
                    )
                @unknown default:
                    return ToolResult(text: "Unknown permission status", isError: true)
                }
            }
        )
    }
}
```

### Permission Request Timing

Don't request permissions until needed:

```swift
// BAD: Request all permissions at launch
func applicationDidFinishLaunching() {
    requestPhotoAccess()
    requestCameraAccess()
    requestLocationAccess()
}

// GOOD: Request when the feature is used
tool("analyze_book_cover", async ({ image }) => {
    let status = await AVCaptureDevice.requestAccess(for: .video)
    if status {
        return await scanCover(image)
    } else {
        return ToolResult(text: "Camera access needed for book scanning")
    }
})
```
</permissions>

<cost_awareness>
## Cost-Aware Design

### Model Tier Selection

Use the cheapest model that achieves the outcome:

```swift
enum ModelTier {
    case fast      // claude-3-haiku
    case balanced  // claude-sonnet
    case powerful  // claude-opus
}

let agentConfigs: [AgentType: ModelTier] = [
    .quickLookup: .fast,
    .chatAssistant: .balanced,
    .researchAgent: .balanced,
    .profileGenerator: .powerful,
]
```

### Token Budgets

```swift
struct AgentConfig {
    let modelTier: ModelTier
    let maxInputTokens: Int
    let maxOutputTokens: Int
    let maxTurns: Int

    static let research = AgentConfig(
        modelTier: .balanced,
        maxInputTokens: 50_000,
        maxOutputTokens: 4_000,
        maxTurns: 20
    )

    static let quickChat = AgentConfig(
        modelTier: .fast,
        maxInputTokens: 10_000,
        maxOutputTokens: 1_000,
        maxTurns: 5
    )
}
```

### Network-Aware Execution

Defer heavy operations to WiFi:

```swift
class AgentOrchestrator {
    @ObservedObject var network = NetworkMonitor()

    func startResearchAgent(for book: Book) async {
        if network.isExpensive {
            let proceed = await showAlert(
                "Research uses data",
                message: "This will use approximately 1-2 MB of cellular data. Continue?"
            )
            if !proceed { return }
        }
        await runAgent(ResearchAgent.create(book: book))
    }
}
```
</cost_awareness>

<offline_handling>
## Offline Graceful Degradation

```swift
class ConnectivityAwareAgent {
    @ObservedObject var network = NetworkMonitor()

    func executeToolCall(_ toolCall: ToolCall) async -> ToolResult {
        let requiresNetwork = ["web_search", "web_fetch", "call_api"]
            .contains(toolCall.name)

        if requiresNetwork && !network.isConnected {
            return ToolResult(
                text: """
                I can't access the internet right now. Here's what I can do offline:
                - Read your library and existing research
                - Answer questions from cached data
                - Write notes and drafts for later

                Would you like me to try something that works offline?
                """,
                isError: false
            )
        }
        return await executeOnline(toolCall)
    }
}
```

### Offline-First Tools

```swift
let offlineTools: Set<String> = [
    "read_file", "write_file", "list_files",
    "read_library", "search_local",
]

let onlineTools: Set<String> = [
    "web_search", "web_fetch", "publish_to_cloud",
]

let hybridTools: Set<String> = [
    "publish_to_feed",  // Works offline, syncs later
]
```
</offline_handling>

<on_device_vs_cloud>
## On-Device vs. Cloud

| Component | On-Device | Cloud |
|-----------|-----------|-------|
| Orchestration | Yes | |
| Tool execution | Yes (file ops, photo access, HealthKit) | |
| LLM calls | | Yes (Anthropic API) |
| Checkpoints | Yes (local files) | Optional via iCloud |
| Long-running agents | Limited by iOS | Possible with server |

### Implications

**Network required for reasoning:**
- The app needs network connectivity for LLM calls
- Design tools to degrade gracefully when network is unavailable

**Data stays local:**
- File operations happen on device
- Sensitive data never leaves the device unless explicitly synced
- Privacy is preserved by default

**Long-running agents:**
For truly long-running agents (hours), consider a server-side orchestrator that can run indefinitely, with the mobile app as a viewer and input mechanism.
</on_device_vs_cloud>

<checklist>
## Mobile Agent-Native Checklist

**iOS Storage:**
- [ ] iCloud Documents as primary storage (or conscious alternative)
- [ ] Local Documents fallback when iCloud unavailable
- [ ] Handle `.icloud` placeholder files (trigger download)
- [ ] Use NSFileCoordinator for conflict-safe writes

**Background Execution:**
- [ ] Checkpoint/resume implemented for all agent sessions
- [ ] State machine for agent lifecycle (idle, running, backgrounded, etc.)
- [ ] Background task extension for critical saves (30 second window)
- [ ] User-visible status for backgrounded agents

**Permissions:**
- [ ] Permissions requested only when needed, not at launch
- [ ] Graceful degradation when permissions denied
- [ ] Clear error messages with Settings deep links
- [ ] Alternative paths when permissions unavailable

**Cost Awareness:**
- [ ] Model tier matched to task complexity
- [ ] Token budgets per session
- [ ] Network-aware (defer heavy work to WiFi)
- [ ] Caching for expensive operations
- [ ] Cost visibility to users

**Offline Handling:**
- [ ] Offline-capable tools identified
- [ ] Graceful degradation for online-only features
- [ ] Action queue for sync when online
- [ ] Clear user communication about offline state
</checklist>
